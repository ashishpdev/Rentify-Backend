// src/modules/auth/auth.service.js
// Business logic & orchestration layer
const authRepository = require("./auth.repository");
const EmailService = require("../../services/email.service");
const AccessTokenUtil = require("../../utils/access_token.util");
const SessionTokenUtil = require("../../utils/session_token.util");
const OTPUtil = require("../../utils/otp.util");
const PasswordUtil = require("../../utils/password.utils"); // bcrypt wrapper
const logger = require("../../config/logger.config");
const {
  AuthenticationError,
  ValidationError,
} = require("../../utils/errors.util");
const fs = require("fs");
const path = require("path");
const handlebars = require("handlebars");

class AuthService {
  // ========================= TEMPLATE RENDERING =========================

  /**
   * Render OTP email template
   * @private
   */
  async _renderOtpTemplate({
    otpCode,
    email,
    expiryMinutes = 10,
    purpose = "verification",
  }) {
    const filePath = path.join(__dirname, "../../templates/emailOtpHtml.hbs");
    const source = fs.readFileSync(filePath, "utf8");
    const template = handlebars.compile(source);
    return template({
      otpCode,
      email,
      EXPIRY_MIN: expiryMinutes,
      purpose,
    });
  }

  /**
   * Send OTP via email
   * @private
   */
  async _sendOTPEmail(
    email,
    otp,
    expiryMinutes = 10,
    purpose = "verification"
  ) {
    const html = await this._renderOtpTemplate({
      otpCode: otp,
      email,
      expiryMinutes,
      purpose,
    });

    const subjects = {
      verification: "Rentify - Verify Your Email",
      login: "Rentify - Login OTP",
      reset: "Rentify - Password Reset OTP",
    };

    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: subjects[purpose] || subjects.verification,
      html,
    };

    return await EmailService.sendMail(mailOptions);
  }

  // ========================= OTP OPERATIONS =========================

  /**
   * Send OTP to user email
   * @param {string} email - User email
   * @param {number} otp_type_id - OTP type (1=LOGIN, 2=REGISTRATION, 3=RESET)
   * @param {Object} options - Additional options (ipAddress)
   * @returns {Promise<Object>} OTP sent result
   */
  async sendOTP(email, otp_type_id, options = {}) {
    const { ipAddress = null } = options;

    try {
      // Generate OTP
      const otpCode = OTPUtil.generateOTP();
      const otpCodeHash = OTPUtil.hashOTP(otpCode);

      // Save OTP to database
      const otpRecord = await authRepository.saveOTP({
        targetIdentifier: email,
        otpCodeHash,
        otp_type_id,
        expiryMinutes: 10,
        ipAddress,
        createdBy: "system",
      });

      // Determine purpose for email
      const purposes = {
        1: "login",
        2: "verification",
        3: "reset",
      };
      const purpose = purposes[otp_type_id] || "verification";

      // Send OTP email
      await this._sendOTPEmail(email, otpCode, 10, purpose);

      // Log OTP (remove in production, only for development)
      if (process.env.NODE_ENV === "development") {
        logger.debug(
          `[OTP] Email: ${email}, Type: ${otp_type_id}, Code: ${otpCode}, ID: ${otpRecord.id}`
        );
      }

      return {
        otpId: otpRecord.id,
        message: `OTP sent successfully to ${email}`,
        expiresAt: otpRecord.expiresAt,
      };
    } catch (error) {
      logger.error("AuthService.sendOTP error", {
        email,
        otp_type_id,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Verify OTP code
   * @param {string} email - User email
   * @param {string} otpCode - OTP code to verify
   * @param {number} otp_type_id - OTP type
   * @returns {Promise<boolean>} Verification success
   */
  async verifyOTP(email, otpCode, otp_type_id) {
    try {
      const hash = OTPUtil.hashOTP(otpCode);
      const result = await authRepository.verifyOTP(email, hash, otp_type_id);

      if (!result || !result.success) {
        throw new AuthenticationError("Invalid or expired OTP");
      }

      logger.info("OTP verified successfully", { email, otp_type_id });
      return true;
    } catch (error) {
      logger.error("AuthService.verifyOTP error", {
        email,
        otp_type_id,
        error: error.message,
      });
      throw error;
    }
  }

  // ========================= REGISTRATION =========================

  /**
   * Complete business registration
   * @param {Object} registrationData - Business and owner details
   * @returns {Promise<Object>} Registration result
   */
  async completeRegistration(registrationData) {
    try {
      // Validate business email != owner email
      if (registrationData.businessEmail === registrationData.ownerEmail) {
        throw new ValidationError(
          "Business email and owner email must be different"
        );
      }

      // Register business with owner
      const created =
        await authRepository.registerBusinessWithOwner(registrationData);

      if (!created.businessId || !created.branchId || !created.ownerId) {
        throw new Error("Invalid IDs returned from registration");
      }

      logger.info("Business registered successfully", {
        businessId: created.businessId,
        branchId: created.branchId,
        ownerId: created.ownerId,
        businessEmail: registrationData.businessEmail,
        ownerEmail: registrationData.ownerEmail,
      });

      return {
        businessId: created.businessId,
        branchId: created.branchId,
        ownerId: created.ownerId,
        message: "Business registered successfully",
      };
    } catch (error) {
      logger.error("AuthService.completeRegistration error", {
        email: registrationData.ownerEmail,
        error: error.message,
      });
      throw error;
    }
  }

  // ========================= LOGIN =========================

  /**
   * Login with OTP
   * @param {string} email - User email
   * @param {string} otpCode - OTP code
   * @param {string} ipAddress - Client IP
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} User data with session token
   */
  async loginWithOTP(email, otpCode, ipAddress = null, userAgent = null) {
    try {
      // Hash OTP
      const hash = OTPUtil.hashOTP(otpCode);

      // Login with OTP (verifies OTP in SP)
      const user = await authRepository.loginWithOTP(email, hash, ipAddress);

      if (!user || !user.user_id) {
        throw new AuthenticationError("Failed to retrieve user information");
      }

      // Generate session token
      const sessionTokenData = {
        user_id: user.user_id,
        business_id: user.business_id,
        branch_id: user.branch_id,
        role_id: user.role_id,
        email: user.email,
        contact_number: user.contact_number,
        user_name: user.user_name,
        business_name: user.business_name,
        branch_name: user.branch_name,
        role_name: user.role_name,
        is_owner: user.is_owner,
        ip_address: ipAddress,
        device_id: `device_${user.user_id}_${Date.now()}`,
      };

      const tokenResult =
        SessionTokenUtil.generateSessionToken(sessionTokenData);

      // Parse device info from userAgent
      const deviceInfo = this._parseUserAgent(userAgent);

      // Create session in database
      const sessionResult = await authRepository.createSession(
        user.user_id,
        tokenResult.sessionToken,
        tokenResult.expiresAt,
        ipAddress,
        sessionTokenData.device_id,
        deviceInfo.deviceName,
        deviceInfo.deviceTypeId
      );

      if (!sessionResult.isSuccess) {
        throw new Error(
          sessionResult.errorMessage || "Failed to create session"
        );
      }

      logger.info("Login with OTP successful", {
        userId: user.user_id,
        email: user.email,
      });

      return {
        ...user,
        session_token: sessionResult.sessionToken,
      };
    } catch (error) {
      logger.error("AuthService.loginWithOTP error", {
        email,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Login with password
   * @param {string} email - User email
   * @param {string} password - Plain text password
   * @param {string} ipAddress - Client IP
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} User data with session token
   */
  async loginWithPassword(email, password, ipAddress = null, userAgent = null) {
    try {
      // Hash password
      const passwordHash = PasswordUtil.hashPassword(password);

      // Login with password
      const user = await authRepository.loginWithPassword(
        email,
        passwordHash,
        ipAddress
      );

      if (!user || !user.user_id) {
        throw new AuthenticationError("Invalid email or password");
      }

      // Generate session token
      const sessionTokenData = {
        user_id: user.user_id,
        business_id: user.business_id,
        branch_id: user.branch_id,
        role_id: user.role_id,
        email: user.email,
        contact_number: user.contact_number,
        user_name: user.user_name,
        business_name: user.business_name,
        branch_name: user.branch_name,
        role_name: user.role_name,
        is_owner: user.is_owner,
        ip_address: ipAddress,
        device_id: `device_${user.user_id}_${Date.now()}`,
      };

      const tokenResult =
        SessionTokenUtil.generateSessionToken(sessionTokenData);

      // Parse device info
      const deviceInfo = this._parseUserAgent(userAgent);

      // Create session
      const sessionResult = await authRepository.createSession(
        user.user_id,
        tokenResult.sessionToken,
        tokenResult.expiresAt,
        ipAddress,
        sessionTokenData.device_id,
        deviceInfo.deviceName,
        deviceInfo.deviceTypeId
      );

      if (!sessionResult.isSuccess) {
        throw new Error(
          sessionResult.errorMessage || "Failed to create session"
        );
      }

      logger.info("Login with password successful", {
        userId: user.user_id,
        email: user.email,
      });

      return {
        ...user,
        session_token: sessionResult.sessionToken,
      };
    } catch (error) {
      logger.error("AuthService.loginWithPassword error", {
        email,
        error: error.message,
      });
      throw error;
    }
  }

  // ========================= TOKEN REFRESH =========================

  /**
   * Refresh access and session tokens
   * @param {string} currentSessionToken - Current session token
   * @returns {Promise<Object>} New tokens
   */
  async refreshTokens(currentSessionToken) {
    try {
      // Decrypt current session token
      const currentSessionData =
        SessionTokenUtil.decryptSessionToken(currentSessionToken);

      if (!currentSessionData || !currentSessionData.user_id) {
        throw new AuthenticationError("Invalid session token");
      }

      // Generate new access token
      const accessTokenData = {
        user_id: currentSessionData.user_id,
        business_id: currentSessionData.business_id,
        branch_id: currentSessionData.branch_id,
        role_id: currentSessionData.role_id,
        email: currentSessionData.email,
        contact_number: currentSessionData.contact_number,
        user_name: currentSessionData.user_name,
        business_name: currentSessionData.business_name,
        branch_name: currentSessionData.branch_name,
        role_name: currentSessionData.role_name,
        is_owner: currentSessionData.is_owner,
      };

      const accessTokenResult =
        AccessTokenUtil.generateAccessToken(accessTokenData);

      // Generate rotated session token
      const extendedSessionTokenObj =
        SessionTokenUtil.generateExtendedSessionToken(currentSessionData);

      // Persist rotation in DB
      const repoResult = await authRepository.extendSession(
        currentSessionData.user_id,
        currentSessionToken,
        extendedSessionTokenObj.sessionToken,
        extendedSessionTokenObj.expiresAt
      );

      if (!repoResult.isSuccess) {
        throw new Error(
          repoResult.errorMessage || "Failed to rotate session token"
        );
      }

      logger.info("Tokens refreshed successfully", {
        userId: currentSessionData.user_id,
      });

      return {
        isSuccess: true,
        accessToken: accessTokenResult.accessToken,
        accessExpiresAt: accessTokenResult.expiresAt,
        sessionToken: extendedSessionTokenObj.sessionToken,
        sessionExpiresAt: extendedSessionTokenObj.expiresAt,
        sessionMaxAgeMs: parseInt(
          process.env.SESSION_COOKIE_MAXAGE_MS || String(60 * 60 * 1000),
          10
        ),
      };
    } catch (error) {
      logger.error("AuthService.refreshTokens error", { error: error.message });
      throw error;
    }
  }

  // ========================= PASSWORD MANAGEMENT =========================

  /**
   * Change user password
   * @param {number} userId - User ID
   * @param {string} oldPassword - Current password
   * @param {string} newPassword - New password
   * @param {string} updatedBy - User performing update
   * @returns {Promise<Object>} Password change result
   */
  async changePassword(userId, oldPassword, newPassword, updatedBy) {
    try {
      // Hash passwords
      const oldPasswordHash = PasswordUtil.hashPassword(oldPassword);
      const newPasswordHash = PasswordUtil.hashPassword(newPassword);

      // Change password
      const result = await authRepository.changePassword(
        userId,
        oldPasswordHash,
        newPasswordHash,
        updatedBy
      );

      logger.info("Password changed successfully", { userId });

      return result;
    } catch (error) {
      logger.error("AuthService.changePassword error", {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Reset password using OTP
   * @param {string} email - User email
   * @param {string} otpCode - OTP code
   * @param {string} newPassword - New password
   * @returns {Promise<Object>} Password reset result
   */
  async resetPassword(email, otpCode, newPassword) {
    try {
      // Hash OTP and password
      const otpCodeHash = OTPUtil.hashOTP(otpCode);
      const newPasswordHash = PasswordUtil.hashPassword(newPassword);

      // Reset password
      const result = await authRepository.resetPassword(
        email,
        otpCodeHash,
        newPasswordHash,
        email // updatedBy = email for self-service reset
      );

      logger.info("Password reset successfully", { email });

      return result;
    } catch (error) {
      logger.error("AuthService.resetPassword error", {
        email,
        error: error.message,
      });
      throw error;
    }
  }

  // ========================= LOGOUT =========================

  /**
   * Logout user
   * @param {number} userId - User ID
   * @returns {Promise<Object>} Logout result
   */
  async logout(userId) {
    try {
      const result = await authRepository.logout(userId);

      logger.info("User logged out successfully", { userId });

      return {
        isSuccess: result.success,
        message: "Logged out successfully",
      };
    } catch (error) {
      logger.error("AuthService.logout error", {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  // ========================= HELPER METHODS =========================

  /**
   * Parse user agent string
   * @private
   */
  _parseUserAgent(userAgent) {
    if (!userAgent) {
      return {
        deviceName: "Unknown Device",
        deviceTypeId: 1, // 1 = Unknown/Other
      };
    }

    // Simple device type detection
    const ua = userAgent.toLowerCase();
    let deviceTypeId = 1; // Default: Unknown
    let deviceName = "Unknown Device";

    if (ua.includes("mobile")) {
      deviceTypeId = 2; // Mobile
      deviceName = "Mobile Device";
    } else if (ua.includes("tablet") || ua.includes("ipad")) {
      deviceTypeId = 3; // Tablet
      deviceName = "Tablet";
    } else if (
      ua.includes("windows") ||
      ua.includes("macintosh") ||
      ua.includes("linux")
    ) {
      deviceTypeId = 4; // Desktop
      deviceName = "Desktop Computer";
    }

    // Extract browser name
    if (ua.includes("chrome")) {
      deviceName += " (Chrome)";
    } else if (ua.includes("firefox")) {
      deviceName += " (Firefox)";
    } else if (ua.includes("safari")) {
      deviceName += " (Safari)";
    } else if (ua.includes("edge")) {
      deviceName += " (Edge)";
    }

    return { deviceName, deviceTypeId };
  }
}

module.exports = new AuthService();
