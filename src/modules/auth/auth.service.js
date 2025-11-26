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

  async verifyOTP(email, otpCode) {
    try {
      const hash = this.hashOTP(otpCode);
      const result = await authRepository.verifyOTP(email, hash);

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
      // Check if business email already exists
      const businessExists = await authRepository.emailExists(
        registrationData.businessEmail
      );
      if (businessExists) {
        throw new Error("Business email already registered");
      }

      // Check if owner email already exists
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

  /**
   * Login user with email and OTP verification
   * Verifies the OTP and returns user details if successful
   * @param {string} email - User email
   * @param {string} otpCode - OTP code (6 digits)
   * @returns {Object} - User object with user_id, business_id, branch_id, role_id, is_owner
   */
  async loginWithOTP(email, otpCode) {
    try {
      // Step 1: Verify OTP code
      const hash = this.hashOTP(otpCode);
      const verifyResult = await authRepository.verifyOTP(email, hash);

      if (!verifyResult || !verifyResult.verified) {
        throw new Error("Invalid or expired OTP");
      }

      // Step 2: Fetch user details from database
      const user = await authRepository.loginWithOTP(email);

      if (!user || !user.user_id) {
        throw new Error("Failed to retrieve user information");
      }

      return {
        user_id: user.user_id,
        business_id: user.business_id,
        branch_id: user.branch_id,
        role_id: user.role_id,
        is_owner: user.is_owner,
        user_name: user.user_name,
        contact_number: user.contact_number,
        business_name: user.business_name,
      };
    } catch (err) {
      throw new Error(`Failed to login: ${err.message}`);
    }
  }
}

module.exports = new AuthService();
