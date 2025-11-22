// Authentication service layer
const authRepository = require("./auth.repository");
const fs = require("fs");
const path = require("path");
const nodemailer = require("nodemailer");
const handlebars = require("handlebars");
// const emailService = require("../../services/email.service");

class AuthService {
  /**
   * Generate a random 6-digit OTP
   * @returns {string} - 6-digit OTP
   */
  generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  /**
   * Send OTP to user email
   * @param {string} email - User email
   * @param {string} otpType - OTP type (REGISTER, VERIFY_EMAIL, etc)
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} - OTP record
   */
  async sendOTP(email, otpType, options = {}) {
    const { ipAddress = null } = options;

    try {
      // Generate OTP
      const otpCode = this.generateOTP();

      // Hash the OTP code
      const otpCodeHash = this.hashOTP(otpCode);

      // Save OTP to database via stored procedure
      const otpRecord = await authRepository.saveOTP({
        targetIdentifier: email,
        otpCodeHash,
        otpType,
        expiryMinutes: 10, // 10 minutes validity
        ipAddress,
      });

      // Send OTP via email
      await this.sendVerificationCode(email, otpCode, 10);
      // Log OTP for testing purposes
      console.log(
        `[OTP] Email: ${email}, Type: ${otpType}, Code: ${otpCode}, ID: ${otpRecord.id}`
      );

      return {
        otpId: otpRecord.id,
        message: `OTP sent successfully to ${email}`,
        expiresAt: otpRecord.expiresAt,
      };
    } catch (error) {
      throw new Error(`Failed to send OTP: ${error.message}`);
    }
  }

  /**
   * Hash OTP code using SHA256
   * @param {string} otp - OTP code
   * @returns {string} - Hashed OTP
   */
  hashOTP(otp) {
    const crypto = require("crypto");
    return crypto.createHash("sha256").update(otp).digest("hex");
  }

  /**
   * Send verification code via email
   * @param {string} email - User email
   * @param {string} otp - OTP code
   * @param {number} expiryMinutes - OTP expiry time in minutes
   * @returns {Promise<Object>} - Email send result
   */
  async sendVerificationCode(email, otp, expiryMinutes) {
    try {
      const emailTemplateSource = fs.readFileSync(
        path.join(__dirname, "../../templates/emailOtpHtml.hbs"),
        "utf8"
      );
      const otpTemplate = handlebars.compile(emailTemplateSource);
      const htmlToSend = otpTemplate({
        otpCode: otp,
        email,
        EXPIRY_MIN: expiryMinutes
      });

      const mailOptions = {
        from: process.env.EMAIL_USER,
        to: email,
        subject: "Rentify - OTP Verification",
        html: htmlToSend
      };

      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: process.env.EMAIL_USER,
          pass: process.env.EMAIL_PASSWORD
        }
      });

      // Convert callback to Promise
      const result = await new Promise((resolve, reject) => {
        transporter.sendMail(mailOptions, (error, info) => {
          if (error) {
            console.error("Error sending email:", error);
            reject(new Error(`Failed to send email: ${error.message}`));
          } else {
            console.log("Email sent successfully:", info.messageId);
            resolve({
              success: true,
              messageId: info.messageId,
              message: "Email sent successfully"
            });
          }
        });
      });

      return result;
    } catch (error) {
      throw new Error(`Failed to send verification code: ${error.message}`);
    }
  }

  /**
   * Verify OTP code
   * @param {string} email - User email
   * @param {string} otpCode - OTP code provided by user
   * @param {string} otpType - OTP type (REGISTER, VERIFY_EMAIL, etc)
   * @returns {Promise<boolean>} - True if verification successful
   */
  async verifyOTP(email, otpCode, otpType) {
    try {
      // Hash the OTP code
      const otpCodeHash = this.hashOTP(otpCode);

      // Verify via stored procedure
      const result = await authRepository.verifyOTP(
        email,
        otpCodeHash,
        otpType
      );

      if (!result.verified) {
        throw new Error("Invalid or expired OTP");
      }

      return true;
    } catch (error) {
      throw new Error(`Failed to verify OTP: ${error.message}`);
    }
  }

  /**
   * Complete registration by creating business and owner
   * @param {Object} registrationData - Registration data
   * @returns {Promise<Object>} - Success response with IDs
   */
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

      // Register business with owner via stored procedure
      const result = await authRepository.registerBusinessWithOwner(
        registrationData
      );

      // Validate all required IDs are present and valid
      if (!result.businessId || result.businessId <= 0) {
        throw new Error("Invalid business ID returned from registration");
      }

      if (!result.branchId || result.branchId <= 0) {
        throw new Error("Invalid branch ID returned from registration");
      }

      if (!result.ownerId || result.ownerId <= 0) {
        throw new Error("Invalid owner ID returned from registration");
      }

      return {
        businessId: result.businessId,
        branchId: result.branchId,
        ownerId: result.ownerId,
        message: "Business registered successfully",
      };
    } catch (error) {
      throw new Error(`Failed to complete registration: ${error.message}`);
    }
  }
}

module.exports = new AuthService();