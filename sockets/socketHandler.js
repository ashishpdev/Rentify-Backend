const { WebSocketServer } = require('ws');

// Store connected WebSocket clients by deviceId
const clients = new Map(); // { deviceId: ws }

const createSocketServer = (server) => {
    const wss = new WebSocketServer({ server });

    wss.on('connection', (ws) => {
        console.log('🔗 New client connected via WebSocket');

        ws.on('message', (message) => {
            try {
                const data = JSON.parse(message);

                // Client registering itself
                if (data.type === 'register') {
                    ws.deviceId = data.deviceId;
                    clients.set(data.deviceId, ws);
                    console.log(`✅ Registered device: ${data.deviceId}`);
                    ws.send(JSON.stringify({ type: 'registered', ok: true }));
                }

                // Client sent a system info report
                if (data.type === 'report') {
                    console.log(`📦 Report received from ${data.deviceId}`);
                    console.log(JSON.stringify(data.payload, null, 2));
                }

            } catch (err) {
                console.error('⚠️ WebSocket message error:', err.message);
            }
        });

        ws.on('close', () => {
            if (ws.deviceId && clients.has(ws.deviceId)) {
                clients.delete(ws.deviceId);
                console.log(`❌ Client disconnected: ${ws.deviceId}`);
            } else {
                console.log('❌ Client disconnected (unregistered)');
            }
        });

        ws.on('error', (err) => console.error('⚠️ WebSocket error:', err.message));
    });

    return { wss, clients };
};

module.exports = { createSocketServer, clients };