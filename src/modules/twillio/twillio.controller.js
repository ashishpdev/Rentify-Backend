// modules/twillio/twillio.controller.js
const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");
const TwillioService = require("./twillio.service");
const { TwillioValidator } = require("./twillio.validator");

class TwillioController {
    async sendMessage(req, res) {
        const startTime = Date.now();

        try {
            logger.info("Twilio send message request received", {
                to: req.body.to,
            });

            // ---------------- REQUEST VALIDATION ----------------
            const { error, value } = TwillioValidator.validateSendMessage(req.body);
            if (error) {
                logger.warn("Twilio validation failed", {
                    to: req.body.to,
                    error: error.details[0].message,
                });
                return ResponseUtil.badRequest(res, error.details[0].message);
            }

            // ---------------- SERVICE CALL ----------------
            const result = await TwillioService.sendMessage(
                value.to,
                value.message
            );

            const duration = Date.now() - startTime;
            logger.info("Twilio message sent", {
                channel: result.channel,
                sid: result.sid,
                duration,
            });

            return ResponseUtil.success(
                res,
                {
                    channel: result.channel,
                    sid: result.sid,
                },
                `Message sent via ${result.channel}`
            );
        } catch (err) {
            logger.error("Twilio send message failed", {
                error: err.message,
            });

            return ResponseUtil.serverError(res, err.message || "Failed to send message");
        }
    }
}

module.exports = new TwillioController();
