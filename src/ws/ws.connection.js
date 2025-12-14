const http = require("http");
const WebSocket = require("ws");
const config = require("../config/env.config");

let server;
let wss;

/**
 * key format:
 * businessId:branchId:deviceId
 */
const devices = new Map();

/**
 * requestId => { resolve, reject, timeout }
 */
const pendingRequests = new Map();

/* ================= SIMPLE REQUEST ID GENERATOR ================= */
function generateRequestId() {
    return (
        "req_" +
        Date.now().toString(36) +
        "_" +
        Math.random().toString(36).substring(2, 10)
    );
}

/* ================= START SERVER ================= */
function startWebSocketServer(app) {
    server = http.createServer(app);
    wss = new WebSocket.Server({ server });

    wss.on("connection", (ws) => {
        console.log("🟡 New socket connected, waiting for registration...");

        ws.on("message", (message) => {
            let data;
            try {
                data = JSON.parse(message.toString());
            } catch {
                console.error("❌ Invalid JSON received");
                return;
            }

            /* ================= HANDLE DEVICE RESPONSE ================= */
            if (data.requestId && pendingRequests.has(data.requestId)) {
                const pending = pendingRequests.get(data.requestId);
                clearTimeout(pending.timeout);
                pending.resolve(data);
                pendingRequests.delete(data.requestId);
                return;
            }

            /* ================= DEVICE REGISTRATION ================= */
            if (data.type === "register") {
                const { deviceId, businessId, branchId } = data;

                if (!deviceId || !businessId || !branchId) {
                    ws.send(JSON.stringify({
                        type: "register_failed",
                        reason: "Missing deviceId / businessId / branchId",
                    }));
                    return;
                }

                const key = `${businessId}:${branchId}:${deviceId}`;

                ws.deviceKey = key;
                ws.deviceId = deviceId;
                ws.businessId = businessId;
                ws.branchId = branchId;

                devices.set(key, ws);

                console.log(`🟢 Device registered → ${key}`);
                console.log(`📡 Online devices: ${devices.size}`);

                ws.send(JSON.stringify({
                    type: "registered",
                    deviceId,
                    businessId,
                    branchId,
                    port: config.port,
                }));
                return;
            }

            /* ================= OPTIONAL LOGS ================= */
            if (data.type === "SYSTEM_INFO") {
                console.log(`📊 System info from ${ws.deviceKey}`);
            }

            if (data.type === "LOCATION") {
                console.log(`📍 Location from ${ws.deviceKey}`);
            }

            if (data.type === "FULL_REPORT") {
                console.log(`📦 Full report from ${ws.deviceKey}`);
            }
        });

        ws.on("close", () => {
            if (ws.deviceKey) {
                devices.delete(ws.deviceKey);
                console.log(`🔴 Device disconnected → ${ws.deviceKey}`);
                console.log(`📡 Online devices: ${devices.size}`);
            }
        });

        ws.on("error", (err) => {
            console.error("❌ WebSocket error:", err.message);
        });

        ws.send(JSON.stringify({
            type: "STATUS",
            connected: true,
            port: config.port,
        }));
    });

    server.listen(config.port, () => {
        console.log(`🚀 HTTP + WebSocket running on port ${config.port}`);
        console.log(`🔌 WebSocket URL: ws://localhost:${config.port}`);
    });

    return server;
}

/* ================= REQUEST → RESPONSE ================= */
function requestFromDevice(
    { businessId, branchId, deviceId },
    payload,
    timeoutMs = 10000
) {
    return new Promise((resolve, reject) => {
        const key = `${businessId}:${branchId}:${deviceId}`;
        const ws = devices.get(key);

        if (!ws || ws.readyState !== WebSocket.OPEN) {
            return reject(new Error("Device is offline or not connected"));
        }

        const requestId = generateRequestId();

        const timeout = setTimeout(() => {
            pendingRequests.delete(requestId);
            reject(new Error("Device response timeout"));
        }, timeoutMs);

        pendingRequests.set(requestId, { resolve, reject, timeout });

        ws.send(JSON.stringify({
            ...payload,
            requestId,
        }));
    });
}

/* ================= LIST ONLINE DEVICES ================= */
function getOnlineDevices() {
    return Array.from(devices.keys()).map((key) => {
        const [businessId, branchId, deviceId] = key.split(":");
        return { businessId, branchId, deviceId };
    });
}

module.exports = {
    startWebSocketServer,
    requestFromDevice,
    getOnlineDevices,
};
