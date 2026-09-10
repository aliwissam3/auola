const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const DATA_DIR = process.env.AUOLA_DATA_DIR || path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'auola-data.json');

const DEFAULT_DATA = () => ({
    auth: { username: 'admin', password: '1234' },
    products: [],
    employees: [],
    salesLog: [],
    dailySalesData: [],
    dailyArchiveData: [],
    financeData: [],
    debts: [],
    nextContractNo: 1001
});

function loadData() {
    if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });
    if (!fs.existsSync(DATA_FILE)) {
        const initial = DEFAULT_DATA();
        fs.writeFileSync(DATA_FILE, JSON.stringify(initial, null, 2));
        return initial;
    }
    try {
        const raw = fs.readFileSync(DATA_FILE, 'utf8');
        const parsed = JSON.parse(raw);
        return Object.assign(DEFAULT_DATA(), parsed);
    } catch (e) {
        console.error('تعذرت قراءة ملف البيانات، سيتم إنشاء ملف جديد:', e.message);
        return DEFAULT_DATA();
    }
}

let data = loadData();
let saveTimer = null;
function persist() {
    if (saveTimer) clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
        fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2));
    }, 150);
}

function todayLocaleDate() {
    return new Date().toLocaleDateString('en-US');
}
function nowTime() {
    return new Date().toLocaleTimeString('en-US');
}
function newId() {
    return Date.now() + Math.floor(Math.random() * 1000);
}

// =========================== الجلسات (تسجيل الدخول) ===========================
const sessions = new Map(); // token -> username

function login(username, password) {
    if (username === data.auth.username && password === data.auth.password) {
        const token = crypto.randomBytes(24).toString('hex');
        sessions.set(token, username);
        return { token, username };
    }
    return null;
}
function logout(token) { sessions.delete(token); }
function verifyToken(token) { return sessions.has(token) ? sessions.get(token) : null; }
function changeCredentials(username, password) {
    data.auth = { username, password };
    persist();
}

// =========================== المنتجات (مخزون موحّد) ===========================
function productMergeKey(p) {
    const barcode = (p.barcode || '').trim();
    if (barcode) return 'bc:' + barcode;
    return 'nm:' + (p.name || '').trim().toLowerCase() + '|' + (p.category || '').trim().toLowerCase();
}
function addProduct(payload) {
    const name = (payload.name || '').trim();
    if (!name) throw new Error('يرجى إدخال اسم المنتج.');
    const cost = Number(payload.cost) || 0;
    const price = Number(payload.price) || 0;
    const qty = Number(payload.qty) || 0;
    const category = (payload.category || 'أخرى').trim();
    const candidate = {
        name, category,
        barcode: (payload.barcode || '').trim(),
        specs: (payload.specs || '').trim(),
        note: payload.note || ''
    };
    const key = productMergeKey(candidate);
    const existing = data.products.find(p => productMergeKey(p) === key);
    if (existing) {
        const newQty = existing.qty + qty;
        if (newQty > 0) existing.cost = ((existing.cost * existing.qty) + (cost * qty)) / newQty;
        existing.qty = newQty;
        existing.price = price || existing.price;
        if (payload.note) existing.note = payload.note;
        if (payload.image) existing.image = payload.image;
        if (payload.barcodeImage) existing.barcodeImage = payload.barcodeImage;
        if (candidate.specs) existing.specs = candidate.specs;
        persist();
        return existing;
    }
    const record = {
        id: newId(),
        name, category,
        barcode: candidate.barcode,
        specs: candidate.specs,
        image: payload.image || '',
        barcodeImage: payload.barcodeImage || '',
        cost, price, qty,
        note: candidate.note,
        createdAt: Date.now()
    };
    data.products.unshift(record);
    persist();
    return record;
}
function updateProduct(id, payload) {
    const p = data.products.find(x => x.id === id);
    if (!p) throw new Error('المنتج غير موجود.');
    if (payload.name !== undefined) p.name = String(payload.name).trim() || p.name;
    if (payload.category !== undefined) p.category = String(payload.category).trim() || p.category;
    if (payload.barcode !== undefined) p.barcode = String(payload.barcode).trim();
    if (payload.specs !== undefined) p.specs = String(payload.specs).trim();
    if (payload.note !== undefined) p.note = payload.note;
    if (payload.image) p.image = payload.image;
    if (payload.barcodeImage) p.barcodeImage = payload.barcodeImage;
    if (payload.cost !== undefined && payload.cost !== '') p.cost = Number(payload.cost) || 0;
    if (payload.price !== undefined && payload.price !== '') p.price = Number(payload.price) || 0;
    if (payload.qty !== undefined && payload.qty !== '') p.qty = Number(payload.qty) || 0;
    persist();
    return p;
}
function deleteProduct(id) {
    data.products = data.products.filter(p => p.id !== id);
    persist();
}

// =========================== الموظفين ===========================
function addEmployee(name) {
    name = (name || '').trim();
    if (!name) throw new Error('يرجى إدخال اسم الموظف.');
    const record = { id: newId(), name };
    data.employees.push(record);
    persist();
    return record;
}
function deleteEmployee(id) {
    data.employees = data.employees.filter(e => e.id !== id);
    persist();
}

// =========================== البيع ===========================
function sellProducts(payload) {
    const items = Array.isArray(payload.items) ? payload.items : [];
    if (items.length === 0) throw new Error('السلة فاضية، أضف منتجات أولاً.');
    const employee = payload.employeeId ? data.employees.find(e => e.id === Number(payload.employeeId)) : null;
    const resolvedItems = [];
    // تحقق أولاً من توفر الكمية لكل المواد قبل تنفيذ أي تعديل
    for (const it of items) {
        const product = data.products.find(p => p.id === Number(it.productId));
        if (!product) throw new Error('أحد المنتجات في السلة غير موجود بالمخزون.');
        const qty = Number(it.qty) || 1;
        if (qty > product.qty) throw new Error(`الكمية المطلوبة من "${product.name}" أكبر من المتوفر بالمخزون (${product.qty}).`);
        const price = it.price !== undefined && it.price !== '' && !isNaN(Number(it.price)) ? Number(it.price) : product.price;
        resolvedItems.push({ product, qty, price });
    }
    let total = 0, profit = 0;
    const lineItems = resolvedItems.map(({ product, qty, price }) => {
        product.qty -= qty;
        const lineProfit = (price - product.cost) * qty;
        total += price * qty;
        profit += lineProfit;
        return { productId: product.id, name: product.name, qty, price, cost: product.cost, profit: lineProfit };
    });

    const contractNo = data.nextContractNo || 1001;
    data.nextContractNo = contractNo + 1;

    const sale = {
        id: newId(),
        contractNo,
        date: todayLocaleDate(),
        time: nowTime(),
        items: lineItems,
        total, profit,
        employeeId: employee ? employee.id : null,
        employeeName: employee ? employee.name : '',
        customerName: (payload.customerName || '').trim()
    };
    data.salesLog.unshift(sale);
    data.dailySalesData.push({
        id: newId(), date: sale.date, time: sale.time,
        desc: lineItems.map(i => `${i.name} × ${i.qty}`).join('، '),
        totalAmount: total, profitAmount: profit,
        employeeName: sale.employeeName
    });
    persist();
    return sale;
}

// =========================== الأرباح والمصاريف ===========================
function addFinanceEntry(payload) {
    const amount = Number(payload.amount);
    if (!payload.desc || isNaN(amount) || amount <= 0) throw new Error('يرجى إدخال الوصف والمبلغ بشكل صحيح.');
    const record = {
        id: newId(), type: payload.type === 'مصروف' ? 'مصروف' : 'دخل',
        desc: payload.desc, amount, date: payload.date || todayLocaleDate(), note: payload.note || ''
    };
    data.financeData.unshift(record);
    persist();
    return record;
}
function deleteFinanceEntry(id) {
    data.financeData = data.financeData.filter(f => f.id !== id);
    persist();
}

// =========================== الديون ===========================
function addDebt(payload) {
    const customerName = (payload.customerName || '').trim();
    if (!customerName) throw new Error('يرجى إدخال اسم الزبون.');
    const amount = Number(payload.amount);
    if (!amount || amount <= 0) throw new Error('يرجى إدخال مبلغ الدين بشكل صحيح.');
    const record = {
        id: newId(),
        customerName,
        phone: (payload.phone || '').trim(),
        amount,
        paid: 0,
        note: payload.note || '',
        date: payload.date || todayLocaleDate(),
        payments: [],
        createdAt: Date.now()
    };
    data.debts.unshift(record);
    persist();
    return record;
}
function addDebtPayment(id, amount) {
    const d = data.debts.find(x => x.id === id);
    if (!d) throw new Error('الدين غير موجود.');
    amount = Number(amount);
    const remaining = d.amount - d.paid;
    if (!amount || amount <= 0) throw new Error('يرجى إدخال مبلغ دفعة صحيح.');
    if (amount > remaining) amount = remaining;
    d.paid += amount;
    d.payments.push({ amount, date: todayLocaleDate(), time: nowTime() });
    persist();
    return d;
}
function deleteDebt(id) {
    data.debts = data.debts.filter(d => d.id !== id);
    persist();
}

// =========================== الأرشيف / التصفير ===========================
function resetTodaySales() {
    const today = todayLocaleDate();
    const daily = data.dailySalesData.filter(t => t.date === today);
    if (daily.length === 0) return null;
    const totalSales = daily.reduce((s, t) => s + t.totalAmount, 0);
    const totalProfit = daily.reduce((s, t) => s + t.profitAmount, 0);
    const archiveEntry = { date: today, sales: daily, totalSales, totalProfit };
    data.dailyArchiveData.push(archiveEntry);
    data.dailySalesData = data.dailySalesData.filter(t => t.date !== today);
    persist();
    return archiveEntry;
}
function clearAllData() {
    const auth = data.auth;
    data = DEFAULT_DATA();
    data.auth = auth;
    persist();
}

function getState() {
    return {
        products: data.products,
        employees: data.employees,
        salesLog: data.salesLog,
        dailySalesData: data.dailySalesData,
        dailyArchiveData: data.dailyArchiveData,
        financeData: data.financeData,
        debts: data.debts
    };
}
function getUsername() { return data.auth.username; }

module.exports = {
    login, logout, verifyToken, changeCredentials, getUsername,
    addProduct, updateProduct, deleteProduct,
    addEmployee, deleteEmployee,
    sellProducts,
    addFinanceEntry, deleteFinanceEntry,
    addDebt, addDebtPayment, deleteDebt,
    resetTodaySales, clearAllData,
    getState
};
