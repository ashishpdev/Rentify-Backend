const express = require('express');
const router = express.Router();
const { clients } = require('../sockets/socketHandler');

// API to list connected devices
router.get('/clients', (req, res) => {
    const deviceList = Array.from(clients.keys());
    res.json({ connectedDevices: deviceList, count: deviceList.length });
});

// API to request data from a specific device
router.get('/request-info/:deviceId', async (req, res) => {
    const deviceId = req.params.deviceId;
    const client = clients.get(deviceId);

    if (!client || client.readyState !== 1) {
        return res.status(404).json({ error: `Device ${deviceId} not connected` });
    }

    console.log(`📡 Requesting system info from device: ${deviceId}`);

    // Create a promise that resolves when the client responds
    const responsePromise = new Promise((resolve, reject) => {
        const timeout = setTimeout(() => {
            reject(new Error('Client did not respond in time'));
        }, 15000); // 15 seconds timeout

        const handleMessage = (msg) => {
            try {
                const data = JSON.parse(msg);
                if (data.type === 'report' && data.deviceId === deviceId) {
                    clearTimeout(timeout);
                    client.off('message', handleMessage); // remove listener
                    resolve(data.payload);
                }
            } catch (err) {
                console.error('Invalid message format:', err.message);
            }
        };

        // Listen for report from this specific client
        client.on('message', handleMessage);

        // Send the request command
        client.send(JSON.stringify({ type: 'getInfo' }));
    });

    try {
        const info = await responsePromise;
        console.log(`✅ Received report from ${deviceId}`);
        return res.json({ ok: true, deviceId, info });
    } catch (err) {
        console.error(`❌ ${deviceId} failed to respond:`, err.message);
        return res.status(504).json({ error: 'Timeout: client did not respond' });
    }
});

// API to broadcast a message to all clients
router.post('/broadcast', (req, res) => {
    const { message } = req.body;
    for (const [deviceId, ws] of clients.entries()) {
        if (ws.readyState === 1) {
            ws.send(JSON.stringify({ type: 'broadcast', message }));
        }
    }
    res.json({ ok: true, message: 'Broadcast sent', totalClients: clients.size });
});

module.exports = router;