// src/modules/whatsapp/whatsapp.controller.js

const { initWhatsapp, getQr, getClient, getStatus } = require("./whatsapp.init");
const fs = require("fs");
const path = require("path");

class WhatsappController {

    // ========== QR Generate API ==========
    async generateQR(req, res) {
        const { businessId } = req.params;

        await initWhatsapp(businessId);

        const status = getStatus(businessId);
        const qr = getQr(businessId);

        return res.json({
            businessId,
            status,
            qr_base64: qr || null   // frontend will show if available
        });
    }

    // ========== Status API ==========
    async getStatus(req, res) {
        const { businessId } = req.params;
        return res.json({
            businessId,
            status: getStatus(businessId)
        });
    }

    // ========== Send Message ==========
    async sendMessage(req, res) {
        const { businessId } = req.params;
        const { number, message } = req.body;

        const client = getClient(businessId);

        if (!client || getStatus(businessId) !== "connected") {
            return res.status(400).json({
                error: "WhatsApp not connected. Scan QR first."
            });
        }

        try {
            await client.sendMessage(`${number.replace(/\D/g, '')}@c.us`, message);
            res.json({ success: true, sent_by: businessId });
        } catch (err) {
            return res.status(500).json({ error: err.message });
        }
    }

    // ========== Logout/Destroy Session ==========
    async logout(req, res) {
        const { businessId } = req.params;

        const folder = path.join("./sessions", `business_${businessId}`);
        if (fs.existsSync(folder)) fs.rmSync(folder, { recursive: true, force: true });

        return res.json({ success: true, message: "Session cleared, user must re-scan QR." });
    }
}

module.exports = new WhatsappController();
