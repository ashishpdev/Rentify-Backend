// src/modules/whatsapp/whatsapp.controller.js

const WhatsappService = require("./whatsapp.service");
const { WhatsappValidator } = require("./whatsapp.validator");
const ResponseUtil = require("../../utils/response.util");

class WhatsappController {
  // ========== QR Generate API ==========
  async generateQR(req, res) {
    try {
      const { businessId } = req.params;

      // Validate business ID
      const { error } = WhatsappValidator.validateBusinessId({ businessId });
      if (error) {
        return ResponseUtil.badRequest(res, "Validation failed", error.details);
      }

      const result = await WhatsappService.generateQRCode(businessId);

      if (result.success) {
        const statusCode = WhatsappService.getHttpStatusCode(result.data.status);
        return res.status(statusCode).json({
          success: true,
          message: result.data.message,
          data: {
            businessId: result.data.businessId,
            status: result.data.status,
            qr_base64: result.data.qr_base64,
          },
        });
      }

      return ResponseUtil.serverError(res, "Failed to generate QR code");
    } catch (error) {
      return ResponseUtil.serverError(res, error.message);
    }
  }

  // ========== Status API ==========
  async getStatus(req, res) {
    try {
      const { businessId } = req.params;

      // Validate business ID
      const { error } = WhatsappValidator.validateBusinessId({ businessId });
      if (error) {
        return ResponseUtil.badRequest(res, "Validation failed", error.details);
      }

      const result = WhatsappService.getConnectionStatus(businessId);

      if (result.success) {
        const statusCode = WhatsappService.getHttpStatusCode(result.data.status);
        return res.status(statusCode).json({
          success: true,
          message: result.data.message,
          data: {
            businessId: result.data.businessId,
            status: result.data.status,
            isConnected: result.data.isConnected,
            requiresQR: result.data.requiresQR,
          },
        });
      }

      return ResponseUtil.serverError(res, "Failed to get status");
    } catch (error) {
      return ResponseUtil.serverError(res, error.message);
    }
  }

  // ========== Send Message ==========
  async sendMessage(req, res) {
    try {
      const { businessId } = req.params;
      const { number, message } = req.body;

      // Validate input
      const { error } = WhatsappValidator.validateSendMessage({
        businessId,
        number,
        message,
      });
      if (error) {
        return ResponseUtil.badRequest(res, "Validation failed", error.details);
      }

      const result = await WhatsappService.sendMessage(
        businessId,
        number,
        message
      );

      if (result.success) {
        return ResponseUtil.success(res, result.data, result.data.message);
      }

      // Handle not connected status
      if (result.requiresQR) {
        return res.status(503).json({
          success: false,
          message: result.message,
          data: {
            status: result.status,
            requiresQR: true,
          },
        });
      }

      return ResponseUtil.serverError(res, result.error || "Failed to send message");
    } catch (error) {
      return ResponseUtil.serverError(res, error.message);
    }
  }

  // ========== Logout/Destroy Session ==========
  async logout(req, res) {
    try {
      const { businessId } = req.params;

      // Validate business ID
      const { error } = WhatsappValidator.validateBusinessId({ businessId });
      if (error) {
        return ResponseUtil.badRequest(res, "Validation failed", error.details);
      }

      const result = await WhatsappService.logout(businessId);

      if (result.success) {
        return ResponseUtil.success(res, result.data, result.data.message);
      }

      return ResponseUtil.serverError(res, "Failed to logout");
    } catch (error) {
      return ResponseUtil.serverError(res, error.message);
    }
  }
}

module.exports = new WhatsappController();
