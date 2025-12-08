// WhatsApp Business Logic Layer
const { initWhatsapp, getQr, getClient, getStatus, destroySession } = require("./whatsapp.init");
const fs = require("fs");
const path = require("path");

class WhatsappService {
  /**
   * Initialize WhatsApp session and generate QR code
   * @param {string} businessId - Business identifier
   * @returns {Promise<Object>} - Status and QR code data
   */
  async generateQRCode(businessId) {
    try {
      await initWhatsapp(businessId);
      
      const status = getStatus(businessId);
      const qr = getQr(businessId);

      return {
        success: true,
        data: {
          businessId,
          status,
          qr_base64: qr || null,
          message: this.getStatusMessage(status),
        },
      };
    } catch (error) {
      throw new Error(`Failed to generate QR code: ${error.message}`);
    }
  }

  /**
   * Get WhatsApp connection status for business
   * @param {string} businessId - Business identifier
   * @returns {Object} - Connection status details
   */
  getConnectionStatus(businessId) {
    const status = getStatus(businessId);
    
    return {
      success: true,
      data: {
        businessId,
        status,
        message: this.getStatusMessage(status),
        isConnected: status === "connected",
        requiresQR: status === "qr" || status === "not_initialized",
      },
    };
  }

  /**
   * Send WhatsApp message
   * @param {string} businessId - Business identifier
   * @param {string} number - Recipient phone number
   * @param {string} message - Message content
   * @returns {Promise<Object>} - Send result
   */
  async sendMessage(businessId, number, message) {
    const client = getClient(businessId);
    const status = getStatus(businessId);

    // Check connection status
    if (!client || status !== "connected") {
      return {
        success: false,
        error: "WhatsApp not connected",
        status,
        message: this.getStatusMessage(status),
        requiresQR: true,
      };
    }

    try {
      // Format phone number (remove non-digits and add @c.us)
      const formattedNumber = `${number.replace(/\D/g, "")}@c.us`;
      
      await client.sendMessage(formattedNumber, message);

      return {
        success: true,
        data: {
          businessId,
          recipient: number,
          message: "Message sent successfully",
        },
      };
    } catch (error) {
      throw new Error(`Failed to send message: ${error.message}`);
    }
  }

  /**
   * Logout and clear WhatsApp session
   * @param {string} businessId - Business identifier
   * @returns {Object} - Logout result
   */
  async logout(businessId) {
    try {
      // Destroy WhatsApp client and remove from memory
      await destroySession(businessId);
      
      // Remove all session files from server
      const sessionFolder = path.join("./sessions", `session-business_${businessId}`);
      
      if (fs.existsSync(sessionFolder)) {
        fs.rmSync(sessionFolder, { recursive: true, force: true });
        console.log(`🗑️ Removed session folder: ${sessionFolder}`);
      }

      return {
        success: true,
        data: {
          businessId,
          message: "Session cleared successfully. Please scan QR code to reconnect.",
        },
      };
    } catch (error) {
      throw new Error(`Failed to logout: ${error.message}`);
    }
  }

  /**
   * Get human-readable status message
   * @param {string} status - Connection status
   * @returns {string} - Status description
   */
  getStatusMessage(status) {
    const statusMessages = {
      connected: "WhatsApp is connected and ready to send messages",
      qr: "QR code generated. Please scan with WhatsApp mobile app",
      initializing: "Initializing WhatsApp connection...",
      disconnected: "WhatsApp disconnected. Please reconnect",
      not_initialized: "WhatsApp not initialized. Please generate QR code",
    };

    return statusMessages[status] || "Unknown status";
  }

  /**
   * Get HTTP status code based on WhatsApp status
   * @param {string} status - Connection status
   * @returns {number} - HTTP status code
   */
  getHttpStatusCode(status) {
    const statusCodes = {
      connected: 200,
      qr: 200,
      initializing: 202, // Accepted
      disconnected: 503, // Service Unavailable
      not_initialized: 404, // Not Found
    };

    return statusCodes[status] || 500;
  }
}

module.exports = new WhatsappService();
