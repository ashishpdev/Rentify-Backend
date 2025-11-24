// src/modules/auth/auth.service.js
const authRepository = require("./auth.repository");
const EmailService = require("../../services/email.service");
const fs = require("fs");
const path = require("path");
const handlebars = require("handlebars");

class AuthService {
  generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  hashOTP(otp) {
    const crypto = require("crypto");
    return crypto.createHash("sha256").update(otp).digest("hex");
  }

  async _renderOtpTemplate({ otpCode, email, expiryMinutes = 10 }) {
    const filePath = path.join(__dirname, "../../templates/emailOtpHtml.hbs");
    const source = fs.readFileSync(filePath, "utf8");
    const template = handlebars.compile(source);
    return template({ otpCode, email, EXPIRY_MIN: expiryMinutes });
  }

  async sendVerificationCode(email, otp, expiryMinutes = 10) {
    const html = await this._renderOtpTemplate({
      otpCode: otp,
      email,
      expiryMinutes,
    });

    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: "Rentify - OTP Verification",
      html,
    };

    // EmailService.sendMail returns Promise
    const info = await EmailService.sendMail(mailOptions);
    return info;
  }

  async sendOTP(email, otpType, options = {}) {
    const { ipAddress = null } = options;

    try {
      const otpCode = this.generateOTP();
      const otpCodeHash = this.hashOTP(otpCode);

      const otpRecord = await authRepository.saveOTP({
        targetIdentifier: email,
        otpCodeHash,
        otpType,
        expiryMinutes: 10,
        ipAddress,
      });

      // send email (fire and await - if email fails we bubble up)
      await this.sendVerificationCode(email, otpCode, 10);

      console.log(
        `[OTP] Email: ${email}, Type: ${otpType}, Code: ${otpCode}, ID: ${otpRecord.id}`
      );

      return {
        otpId: otpRecord.id,
        message: `OTP sent successfully to ${email}`,
        expiresAt: otpRecord.expiresAt,
      };
    } catch (err) {
      throw new Error(`Failed to send OTP: ${err.message}`);
    }
  }

  async verifyOTP(email, otpCode, otpType) {
    try {
      const hash = this.hashOTP(otpCode);
      const result = await authRepository.verifyOTP(email, hash, otpType);

      if (!result || !result.verified) {
        throw new Error("Invalid or expired OTP");
      }
      return true;
    } catch (err) {
      throw new Error(`Failed to verify OTP: ${err.message}`);
    }
  }

  async completeRegistration(registrationData) {
    try {
      // business email already exists?
      const businessExists = await authRepository.emailExists(
        registrationData.businessEmail
      );
      if (businessExists) {
        throw new Error("Business email already registered");
      }

      const ownerExists = await authRepository.emailExists(
        registrationData.ownerEmail
      );
      if (ownerExists) {
        throw new Error("Owner email already registered");
      }

      const created = await authRepository.registerBusinessWithOwner(
        registrationData
      );

      if (!created.businessId || !created.branchId || !created.ownerId) {
        throw new Error("Invalid IDs returned from registration");
      }

      return {
        businessId: created.businessId,
        branchId: created.branchId,
        ownerId: created.ownerId,
        message: "Business registered successfully",
      };
    } catch (err) {
      throw new Error(`Failed to complete registration: ${err.message}`);
    }
  }
}

module.exports = new AuthService();
