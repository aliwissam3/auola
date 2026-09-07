const { app, BrowserWindow, Menu, shell, dialog } = require('electron');
const path = require('path');
const os = require('os');

const PORT = 4000;
let mainWindow = null;
let httpServer = null;

function getServerModulePath() {
    return app.isPackaged
        ? path.join(process.resourcesPath, 'server', 'server.js')
        : path.join(__dirname, '..', 'server', 'server.js');
}

function getLanUrl() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name] || []) {
            if (iface.family === 'IPv4' && !iface.internal) return `http://${iface.address}:${PORT}`;
        }
    }
    return `http://localhost:${PORT}`;
}

function startServer() {
    process.env.AUOLA_DATA_DIR = path.join(app.getPath('userData'), 'data');
    const { createServer } = require(getServerModulePath());
    httpServer = createServer();
    return new Promise((resolve, reject) => {
        httpServer.listen(PORT, '0.0.0.0', () => resolve());
        httpServer.on('error', reject);
    });
}

function createWindow() {
    mainWindow = new BrowserWindow({
        width: 1440,
        height: 900,
        minWidth: 1000,
        minHeight: 650,
        title: 'AUOLA - نظام إدارة المبيعات',
        autoHideMenuBar: true,
        webPreferences: {
            contextIsolation: true,
            nodeIntegration: false
        }
    });

    const menu = Menu.buildFromTemplate([
        {
            label: 'القائمة',
            submenu: [
                {
                    label: 'عنوان الشبكة (للأجهزة الأخرى)',
                    click: () => {
                        dialog.showMessageBox(mainWindow, {
                            type: 'info',
                            title: 'عنوان سيرفر المحل',
                            message: 'استخدم هذا العنوان لفتح النظام من أجهزة أخرى على نفس الشبكة (أندرويد / آيفون):',
                            detail: getLanUrl()
                        });
                    }
                },
                { label: 'إعادة تحميل', role: 'reload' },
                { label: 'أدوات المطور', role: 'toggleDevTools' },
                { type: 'separator' },
                { label: 'خروج', role: 'quit' }
            ]
        }
    ]);
    Menu.setApplicationMenu(menu);

    mainWindow.loadURL(`http://localhost:${PORT}`);
    mainWindow.webContents.setWindowOpenHandler(({ url }) => {
        shell.openExternal(url);
        return { action: 'deny' };
    });
}

app.whenReady().then(async () => {
    try {
        await startServer();
    } catch (e) {
        dialog.showErrorBox('تعذر تشغيل سيرفر AUOLA', e.message || String(e));
        app.quit();
        return;
    }
    createWindow();

    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) createWindow();
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') app.quit();
});
