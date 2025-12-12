// modules/twillio/twillio.service.js
const twilio = require("twilio");
const logger = require("../../config/logger.config");
const { twillio } = require("../../config/env.config");

class TwillioService {
    constructor() {
        // Initialize Twilio Client
        this.client = twilio(twillio.accountSid, twillio.authToken);

        // Must be like "whatsapp:+14155238886"
        this.whatsappFrom = twillio.whatsappNumber;
    }

    // ========================================================================
    // Send WhatsApp Message ONLY
    // ========================================================================
    async sendWhatsApp(to, message) {
        try {
            return await this.client.messages.create({
                from: this.whatsappFrom,
                to: `whatsapp:${to}`,
                body: message,
            });
        } catch (err) {
            logger.error("WhatsApp Send Error", { error: err.message });
            throw err;
        }
    }

    // ========================================================================
    // Public function → Only WhatsApp (NO SMS, NO LOOKUP)
    // ========================================================================
    async sendMessage(to, message) {
        logger.info("Sending WhatsApp message...", { to });

        const result = await this.sendWhatsApp(to, message);

        return {
            channel: "whatsapp",
            sid: result.sid,
        };
    }
}

module.exports = new TwillioService();
