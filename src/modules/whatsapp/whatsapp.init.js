// src/modules/whatsapp/whatsapp.init.js

const { Client, LocalAuth } = require("whatsapp-web.js");
const QRCode = require("qrcode");
const fs = require("fs");

const sessions = {}; // businessId: { client, qr, status }

// Safe init – no crash if session folder removed
const initWhatsapp = async (businessId) => {
    return new Promise((resolve) => {
        if (sessions[businessId]?.status === "connected")
            return resolve("Already connected");

        if (!sessions[businessId]?.client) {
            console.log(`🔄 Initializing WhatsApp for business ${businessId}`);

            const client = new Client({
                authStrategy: new LocalAuth({
                    clientId: `business_${businessId}`,
                    dataPath: "./sessions"   // session cache storage
                }),
                puppeteer: { headless: true }
            });

            sessions[businessId] = { client, qr: null, status: "initializing" };

            client.on("qr", async (qr) => {
                sessions[businessId].qr = await QRCode.toDataURL(qr);
                sessions[businessId].status = "qr";
                console.log(`📲 QR generated for business ${businessId}`);
            });

            client.on("ready", () => {
                sessions[businessId].status = "connected";
                sessions[businessId].qr = null;
                console.log(`✅ Business ${businessId} WhatsApp connected`);
            });

            client.on("disconnected", () => {
                sessions[businessId].status = "disconnected";
                sessions[businessId].qr = null;
                sessions[businessId].client = null;
                console.log(`⚠ Business ${businessId} disconnected`);
            });

            client.initialize();
        }

        resolve("Initializing WhatsApp...");
    });
};

const getClient = (businessId) => sessions[businessId]?.client;
const getQr = (businessId) => sessions[businessId]?.qr;
const getStatus = (businessId) => sessions[businessId]?.status || "not_initialized";

module.exports = { initWhatsapp, getClient, getQr, getStatus };
