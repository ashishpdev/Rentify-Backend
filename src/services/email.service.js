// src/services/email.service.js
const nodemailer = require("nodemailer");
const config = require("../config/env.config");

class EmailService {
  constructor() {
    // create transporter lazily so tests can mock easily
    this.transporter = null;
  }

  _createTransporter() {
    if (this.transporter) return this.transporter;

    // For simple Gmail usage we can accept provider 'gmail' via env
    if (
      config.email.provider === "gmail" ||
      process.env.EMAIL_PROVIDER === "gmail"
    ) {
      this.transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: config.email.user,
          pass: config.email.password,
        },
      });
    } else {
      // generic SMTP
      this.transporter = nodemailer.createTransport({
        host: config.email.host,
        port: config.email.port,
        secure: config.email.port === 465, // true for 465, false for other ports
        auth: {
          user: config.email.user,
          pass: config.email.password,
        },
      });
    }
    return this.transporter;
  }

  /**
   * Send email
   * @param {Object} options - { from, to, subject, html, text }
   */
  async sendMail(options = {}) {
    const transporter = this._createTransporter();
    return transporter.sendMail(options); // returns Promise
  }
}

module.exports = new EmailService();
