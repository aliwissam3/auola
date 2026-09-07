const path = require('path');
const http = require('http');
const os = require('os');
const express = require('express');
const cors = require('cors');
const { Server: SocketIOServer } = require('socket.io');
const store = require('./data-store');

function getLanAddresses() {
    const interfaces = os.networkInterfaces();
    const addresses = [];
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name] || []) {
            if (iface.family === 'IPv4' && !iface.internal) addresses.push(iface.address);
        }
    }
    return addresses;
}

function createServer() {
    const app = express();
    app.use(cors());
    app.use(express.json({ limit: '15mb' }));
    app.use(express.static(path.join(__dirname, 'public')));

    const server = http.createServer(app);
    const io = new SocketIOServer(server, { cors: { origin: '*' } });

    function broadcastSync() { io.emit('sync'); }

    function requireAuth(req, res, next) {
        const header = req.headers.authorization || '';
        const token = header.startsWith('Bearer ') ? header.slice(7) : '';
        const username = store.verifyToken(token);
        if (!username) return res.status(401).json({ error: 'غير مصرح. يرجى تسجيل الدخول.' });
        req.username = username;
        next();
    }

    // ============ تسجيل الدخول ============
    app.post('/api/login', (req, res) => {
        const { username, password } = req.body || {};
        const result = store.login(username || '', password || '');
        if (!result) return res.status(401).json({ error: 'اسم المستخدم أو كلمة المرور غير صحيحة' });
        res.json(result);
    });
    app.post('/api/logout', requireAuth, (req, res) => {
        const header = req.headers.authorization || '';
        store.logout(header.slice(7));
        res.json({ ok: true });
    });
    app.post('/api/change-credentials', requireAuth, (req, res) => {
        const { username, password } = req.body || {};
        if (!username || !password) return res.status(400).json({ error: 'بيانات ناقصة' });
        store.changeCredentials(username, password);
        res.json({ ok: true });
    });

    // ============ معلومات الشبكة (عام، بدون تسجيل دخول - لعرض رمز الدخول ورابط الشبكة) ============
    app.get('/api/network-info', (req, res) => {
        res.json({ addresses: getLanAddresses(), port: server.address() ? server.address().port : null });
    });

    app.use('/api', (req, res, next) => {
        if (req.path === '/login' || req.path === '/network-info') return next();
        requireAuth(req, res, next);
    });

    // ============ الحالة الكاملة (لكل الجداول دفعة وحدة) ============
    app.get('/api/state', (req, res) => {
        res.json({ ...store.getState(), username: req.username });
    });

    // ============ الأجهزة ============
    app.post('/api/devices', (req, res) => {
        const record = store.addDevice(req.body || {});
        broadcastSync();
        res.json(record);
    });
    app.delete('/api/devices/:id', (req, res) => {
        store.deleteDevice(Number(req.params.id));
        broadcastSync();
        res.json({ ok: true });
    });

    // ============ الإكسسوارات ============
    app.post('/api/accessory-stock', (req, res) => {
        const record = store.addAccessoryStock(req.body || {});
        broadcastSync();
        res.json(record);
    });
    app.delete('/api/accessory-stock/:id', (req, res) => {
        store.deleteAccessoryStock(Number(req.params.id));
        broadcastSync();
        res.json({ ok: true });
    });
    app.post('/api/accessory-stock/sell', (req, res) => {
        try {
            const result = store.sellAccessory(req.body || {});
            broadcastSync();
            res.json(result);
        } catch (e) {
            res.status(400).json({ error: e.message });
        }
    });

    // ============ الأقساط ============
    app.post('/api/installments', (req, res) => {
        const record = store.addInstallment(req.body || {});
        broadcastSync();
        res.json(record);
    });
    app.post('/api/installments/:id/pay', (req, res) => {
        try {
            const result = store.payInstallment(Number(req.params.id), req.body && req.body.amount);
            broadcastSync();
            res.json(result);
        } catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
    app.delete('/api/installments/:id', (req, res) => {
        store.deleteInstallment(Number(req.params.id));
        broadcastSync();
        res.json({ ok: true });
    });

    // ============ الديون ============
    app.post('/api/debts', (req, res) => {
        const record = store.addDebt(req.body || {});
        broadcastSync();
        res.json(record);
    });
    app.post('/api/debts/:id/pay', (req, res) => {
        try {
            const result = store.payDebt(Number(req.params.id), req.body && req.body.amount);
            broadcastSync();
            res.json(result);
        } catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
    app.delete('/api/debts/:id', (req, res) => {
        store.deleteDebt(Number(req.params.id));
        broadcastSync();
        res.json({ ok: true });
    });

    // ============ الأرباح والمصاريف ============
    app.post('/api/finance', (req, res) => {
        try {
            const record = store.addFinanceEntry(req.body || {});
            broadcastSync();
            res.json(record);
        } catch (e) {
            res.status(400).json({ error: e.message });
        }
    });
    app.delete('/api/finance/:id', (req, res) => {
        store.deleteFinanceEntry(Number(req.params.id));
        broadcastSync();
        res.json({ ok: true });
    });

    // ============ التصفير والنسخ الاحتياطي ============
    app.post('/api/sales/reset-today', (req, res) => {
        const archiveEntry = store.resetTodaySales();
        broadcastSync();
        res.json({ archiveEntry });
    });
    app.get('/api/backup', (req, res) => {
        res.setHeader('Content-Disposition', `attachment; filename="auola_backup_${new Date().toISOString().slice(0,10)}.json"`);
        res.json(store.getState());
    });
    app.post('/api/clear-all', (req, res) => {
        store.clearAllData();
        broadcastSync();
        res.json({ ok: true });
    });

    io.on('connection', () => {});

    return server;
}

if (require.main === module) {
    const PORT = process.env.PORT || 4000;
    const server = createServer();
    server.listen(PORT, '0.0.0.0', () => {
        console.log(`✅ AUOLA server running: http://localhost:${PORT}`);
        console.log('استخدم عنوان شبكتك المحلية (LAN IP) لفتح النظام من أجهزة أخرى على نفس الشبكة.');
    });
}

module.exports = { createServer };
