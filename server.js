/**
 * Combined Express + WebSocket Server
 * Works with on-demand client reporting (via WebSocket)
 */

const express = require('express');
const http = require('http');
const { WebSocketServer } = require('ws');
require('dotenv').config();
const cors = require('cors');
const helmet = require('helmet');
const bodyParser = require('body-parser');

// --- optional: DB connection (if you have one) ---
// const connection = require('./src/config/database');
// connection.connect();

const app = express();
app.use(cors());
app.use(helmet());
app.use(bodyParser.json());

// --- Express HTTP server ---
const server = http.createServer(app);

// --- WebSocket server (attached to same HTTP server) ---
const wss = new WebSocketServer({ server });

// Store connected WebSocket clients by deviceId
const clients = new Map(); // { deviceId: ws }

// --- WebSocket events ---
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

// --- REST APIs ---

// Default route
app.get('/', (req, res) => {
    res.send('✅ Express + WebSocket server is running!');
});

// API to list connected devices
app.get('/api/clients', (req, res) => {
    const deviceList = Array.from(clients.keys());
    res.json({ connectedDevices: deviceList, count: deviceList.length });
});

// API to request data from a specific device
app.get('/api/request-info/:deviceId', async (req, res) => {
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


// API to broadcast a message to all clients (optional)
app.post('/api/broadcast', (req, res) => {
    const { message } = req.body;
    for (const [deviceId, ws] of clients.entries()) {
        if (ws.readyState === 1) {
            ws.send(JSON.stringify({ type: 'broadcast', message }));
        }
    }
    res.json({ ok: true, message: 'Broadcast sent', totalClients: clients.size });
});

// --- Start both servers on same port ---
const port = process.env.PORT || 4000;
server.listen(port, () => {
    console.log(`🚀 Server running at http://localhost:${port}`);
    console.log(`💬 WebSocket server listening on ws://localhost:${port}`);
});
