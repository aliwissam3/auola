const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const DATA_DIR = process.env.AUOLA_DATA_DIR || path.join(__dirname, 'data');
const DATA_FILE = path.join(DATA_DIR, 'auola-data.json');

const DEFAULT_DATA = () => ({
    auth: { username: 'admin', password: '1234' },
    deviceSalesLog: [],
    accessoryStock: [],
    installmentsData: [],
    completedInstallmentsData: [],
    debtsData: [],
    dailySalesData: [],
    dailyArchiveData: [],
    financeData: []
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

// =========================== الأجهزة ===========================
function addDevice(payload) {
    const cost = Number(payload.cost) || 0;
    const sell = Number(payload.sell) || 0;
    const qty = Number(payload.qty) || 1;
    const profit = (sell - cost) * qty;
    const record = {
        id: newId(),
        date: todayLocaleDate(),
        time: nowTime(),
        model: payload.model || '',
        storage: payload.storage || '',
        sim: payload.sim || '',
        battery: payload.battery || '',
        imei: payload.imei || '',
        damaged: payload.damaged || '',
        cost, sell, qty,
        note: payload.note || '',
        image: payload.image || '',
        profit
    };
    data.deviceSalesLog.unshift(record);
    data.dailySalesData.push({
        id: newId(), date: record.date, time: record.time,
        desc: `بيع جهاز: ${record.model} (${record.storage})`,
        totalAmount: sell * qty, profitAmount: profit
    });
    persist();
    return record;
}
function deleteDevice(id) {
    data.deviceSalesLog = data.deviceSalesLog.filter(d => d.id !== id);
    persist();
}

// =========================== الإكسسوارات ===========================
function addAccessoryStock(payload) {
    const cost = Number(payload.cost) || 0;
    const qty = Number(payload.qty) || 0;
    const type = payload.type || '';
    const brand = payload.brand || '';
    const extra = (payload.extra || '').trim();
    const existing = data.accessoryStock.find(p => p.type === type && p.brand === brand && (p.extra || '') === extra);
    if (existing) {
        const newQty = existing.qty + qty;
        existing.cost = ((existing.cost * existing.qty) + (cost * qty)) / newQty;
        existing.qty = newQty;
        if (payload.note) existing.note = payload.note;
        if (payload.image) existing.image = payload.image;
        persist();
        return existing;
    }
    const record = { id: newId(), type, brand, extra, cost, qty, note: payload.note || '', image: payload.image || '' };
    data.accessoryStock.unshift(record);
    persist();
    return record;
}
function deleteAccessoryStock(id) {
    data.accessoryStock = data.accessoryStock.filter(p => p.id !== id);
    persist();
}
function sellAccessory(payload) {
    const item = data.accessoryStock.find(p => p.id === Number(payload.pieceId));
    if (!item) throw new Error('القطعة غير موجودة بالمخزون.');
    const qty = Number(payload.qty) || 1;
    const price = Number(payload.price);
    const cost = payload.cost !== undefined && payload.cost !== '' && !isNaN(Number(payload.cost)) ? Number(payload.cost) : item.cost;
    if (isNaN(price)) throw new Error('يرجى إدخال سعر البيع.');
    if (qty > item.qty) throw new Error('الكمية المطلوبة أكبر من المتوفر بالمخزون.');
    item.qty -= qty;
    const profit = (price - cost) * qty;
    const sale = {
        id: newId(), date: todayLocaleDate(), time: nowTime(),
        desc: `بيع إكسسوار: ${item.type} (${item.brand})`,
        totalAmount: price * qty, profitAmount: profit
    };
    data.dailySalesData.push(sale);
    persist();
    return { item, sale };
}

// =========================== الأقساط ===========================
function addInstallment(payload) {
    const total = Number(payload.total);
    const paid = Number(payload.paid) || 0;
    const months = Number(payload.months);
    const remMonths = Number(payload.remMonths) || months;
    const remaining = payload.remaining !== undefined && payload.remaining !== '' ? Number(payload.remaining) : (total - paid);
    const regDate = payload.regDate || todayLocaleDate();
    const record = {
        id: newId(),
        date: new Date(regDate).toLocaleDateString('en-US'),
        regDate,
        customer: payload.customer || '',
        phone: payload.phone || '',
        deviceName: payload.deviceName || 'غير محدد',
        months, total, paid, remaining, remMonths,
        note: payload.note || 'بدون ملاحظة'
    };
    data.installmentsData.push(record);
    persist();
    return record;
}
function payInstallment(id, amount) {
    const inst = data.installmentsData.find(i => i.id === id);
    if (!inst) throw new Error('العقد غير موجود.');
    amount = Number(amount);
    if (isNaN(amount) || amount <= 0) throw new Error('مبلغ غير صالح.');
    if (amount > inst.remaining) throw new Error('المبلغ أكبر من المتبقي.');
    inst.remaining -= amount;
    inst.paid += amount;
    inst.remMonths = Math.max(0, inst.remMonths - 1);
    data.dailySalesData.push({
        id: newId(), date: todayLocaleDate(), time: nowTime(),
        desc: `تسديد قسط (${inst.customer})`, totalAmount: amount, profitAmount: 0
    });
    let completed = false;
    if (inst.remaining === 0) {
        data.installmentsData = data.installmentsData.filter(i => i.id !== id);
        data.completedInstallmentsData.push(inst);
        completed = true;
    }
    persist();
    return { inst, completed };
}
function deleteInstallment(id) {
    data.installmentsData = data.installmentsData.filter(i => i.id !== id);
    persist();
}

// =========================== الديون ===========================
function addDebt(payload) {
    const total = Number(payload.total);
    const record = {
        id: newId(), date: todayLocaleDate(),
        customer: payload.customer || '', phone: payload.phone || '',
        desc: payload.details || 'دين', total, remaining: total, paid: 0,
        dueDate: payload.dueDate || '', note: payload.note || ''
    };
    data.debtsData.push(record);
    persist();
    return record;
}
function payDebt(id, amount) {
    const debt = data.debtsData.find(d => d.id === id);
    if (!debt) throw new Error('السجل غير موجود.');
    amount = Number(amount);
    if (isNaN(amount) || amount <= 0) throw new Error('مبلغ غير صالح.');
    if (amount > debt.remaining) throw new Error('المبلغ أكبر من المتبقي.');
    debt.remaining -= amount;
    debt.paid += amount;
    data.dailySalesData.push({
        id: newId(), date: todayLocaleDate(), time: nowTime(),
        desc: `تسديد دين (${debt.customer})`, totalAmount: amount, profitAmount: 0
    });
    let settled = false;
    if (debt.remaining === 0) {
        data.debtsData = data.debtsData.filter(d => d.id !== id);
        settled = true;
    }
    persist();
    return { debt, settled };
}
function deleteDebt(id) {
    data.debtsData = data.debtsData.filter(d => d.id !== id);
    persist();
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
        deviceSalesLog: data.deviceSalesLog,
        accessoryStock: data.accessoryStock,
        installmentsData: data.installmentsData,
        completedInstallmentsData: data.completedInstallmentsData,
        debtsData: data.debtsData,
        dailySalesData: data.dailySalesData,
        dailyArchiveData: data.dailyArchiveData,
        financeData: data.financeData
    };
}
function getUsername() { return data.auth.username; }

module.exports = {
    login, logout, verifyToken, changeCredentials, getUsername,
    addDevice, deleteDevice,
    addAccessoryStock, deleteAccessoryStock, sellAccessory,
    addInstallment, payInstallment, deleteInstallment,
    addDebt, payDebt, deleteDebt,
    addFinanceEntry, deleteFinanceEntry,
    resetTodaySales, clearAllData,
    getState
};
