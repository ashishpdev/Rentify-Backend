// src/modules/auth/auth.service.js
const authRepository = require("./auth.repository");
const EmailService = require("../../services/email.service");
const AccessTokenUtil = require("../../utils/access_token.util");
const SessionTokenUtil = require("../../utils/session_token.util");
const OTPUtil = require("../../utils/otp.util");
const PasswordUtil = require("../../utils/password.utils");
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
  async sendOTP(email, otp_type_id, options = {}) {
    const { ipAddress = null } = options;

    try {
      const otpCode = OTPUtil.generateOTP();
      const otpCodeHash = OTPUtil.hashOTP(otpCode);

      const otpRecord = await authRepository.saveOTP({
        targetIdentifier: email,
        otpCodeHash,
        otp_type_id,
        expiryMinutes: 10,
        ipAddress,
        createdBy: "system",
      });

      const purposes = {
        1: "login",
        2: "verification",
        3: "reset",
      };
      const purpose = purposes[otp_type_id] || "verification";

      await this._sendOTPEmail(email, otpCode, 10, purpose);

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
  async completeRegistration(registrationData) {
    try {
      if (registrationData.businessEmail === registrationData.ownerEmail) {
        throw new ValidationError(
          "Business email and owner email must be different"
        );
      }

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
  async loginWithOTP(email, otpCode, ipAddress = null, userAgent = null) {
    try {
      const hash = OTPUtil.hashOTP(otpCode);
      const user = await authRepository.loginWithOTP(email, hash, ipAddress);

      if (!user || !user.user_id) {
        throw new AuthenticationError("Failed to retrieve user information");
      }

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

      const deviceInfo = this._parseUserAgent(userAgent);

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
   * FIXED: Login with password using bcrypt verification
   */
  async loginWithPassword(email, password, ipAddress = null, userAgent = null) {
    try {
      // Step 1: Get user credentials
      const userCredentials = await authRepository.getUserCredentials(email);

      if (!userCredentials || !userCredentials.user_id) {
        logger.warn("Login attempt for non-existent user", { email });
        throw new AuthenticationError("Invalid email or password");
      }

      // Step 2: Check account locks and status
      if (userCredentials.locked_until) {
        const lockedUntil = new Date(userCredentials.locked_until);
        if (lockedUntil > new Date()) {
          throw new AuthenticationError(
            `Account locked until ${lockedUntil.toISOString()}. Please try again later.`
          );
        }
      }

      if (!userCredentials.user_active) {
        throw new AuthenticationError("Account is inactive");
      }

      if (!userCredentials.business_active) {
        throw new AuthenticationError("Business account is inactive");
      }

      // Step 3: CRITICAL - Verify password using bcrypt
      const isPasswordValid = await PasswordUtil.verifyPassword(
        password,
        userCredentials.hash_password
      );

      if (!isPasswordValid) {
        logger.warn("Invalid password attempt", {
          email,
          userId: userCredentials.user_id,
        });
        throw new AuthenticationError("Invalid email or password");
      }

      // Step 4: Update last login
      await authRepository.updateLastLogin(userCredentials.user_id, ipAddress);

      // Step 5: Generate session token
      const sessionTokenData = {
        user_id: userCredentials.user_id,
        business_id: userCredentials.business_id,
        branch_id: userCredentials.branch_id,
        role_id: userCredentials.role_id,
        email: userCredentials.email,
        contact_number: userCredentials.contact_number,
        user_name: userCredentials.user_name,
        business_name: userCredentials.business_name,
        branch_name: userCredentials.branch_name,
        role_name: userCredentials.role_name,
        is_owner: userCredentials.is_owner,
        ip_address: ipAddress,
        device_id: `device_${userCredentials.user_id}_${Date.now()}`,
      };

      const tokenResult =
        SessionTokenUtil.generateSessionToken(sessionTokenData);

      const deviceInfo = this._parseUserAgent(userAgent);

      // Step 6: Create session
      const sessionResult = await authRepository.createSession(
        userCredentials.user_id,
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
        userId: userCredentials.user_id,
        email: userCredentials.email,
      });

      return {
        user_id: userCredentials.user_id,
        business_id: userCredentials.business_id,
        branch_id: userCredentials.branch_id,
        role_id: userCredentials.role_id,
        email: userCredentials.email,
        contact_number: userCredentials.contact_number,
        user_name: userCredentials.user_name,
        business_name: userCredentials.business_name,
        branch_name: userCredentials.branch_name,
        role_name: userCredentials.role_name,
        is_owner: userCredentials.is_owner,
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
  async refreshTokens(currentSessionToken) {
    try {
      const currentSessionData =
        SessionTokenUtil.decryptSessionToken(currentSessionToken);

      if (!currentSessionData || !currentSessionData.user_id) {
        throw new AuthenticationError("Invalid session token");
      }

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

      const extendedSessionTokenObj =
        SessionTokenUtil.generateExtendedSessionToken(currentSessionData);

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
   * FIXED: Change password with bcrypt verification
   */
  async changePassword(userId, oldPassword, newPassword, updatedBy) {
    try {
      // Step 1: Validate new password strength
      const validation = PasswordUtil.validatePasswordStrength(newPassword);
      if (!validation.isValid) {
        throw new ValidationError(validation.errors.join(", "));
      }

      // Step 2: Get stored password hash
      const userRecord = await authRepository.getStoredPasswordHash(userId);

      if (!userRecord || !userRecord.hash_password) {
        throw new AuthenticationError("User not found");
      }

      if (!userRecord.is_active) {
        throw new AuthenticationError("Account is inactive");
      }

      // Step 3: CRITICAL - Verify old password using bcrypt
      const isOldPasswordValid = await PasswordUtil.verifyPassword(
        oldPassword,
        userRecord.hash_password
      );

      if (!isOldPasswordValid) {
        logger.warn("Change password failed - incorrect old password", {
          userId,
        });
        throw new AuthenticationError("Current password is incorrect");
      }

      // Step 4: Check if new password is same as old
      const isSamePassword = await PasswordUtil.verifyPassword(
        newPassword,
        userRecord.hash_password
      );

      if (isSamePassword) {
        throw new ValidationError(
          "New password must be different from current password"
        );
      }

      // Step 5: Hash new password with bcrypt
      const newPasswordHash = await PasswordUtil.hashPassword(newPassword);

      // Step 6: Update password
      await authRepository.updatePasswordHash(
        userId,
        newPasswordHash,
        updatedBy
      );

      logger.info("Password changed successfully", { userId });

      return {
        success: true,
        message: "Password changed successfully. Please login again.",
      };
    } catch (error) {
      logger.error("AuthService.changePassword error", {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * FIXED: Reset password with OTP verification
   */
  async resetPassword(email, otpCode, newPassword) {
    try {
      // Step 1: Validate password strength
      const validation = PasswordUtil.validatePasswordStrength(newPassword);
      if (!validation.isValid) {
        throw new ValidationError(validation.errors.join(", "));
      }

      // Step 2: Verify OTP (this consumes the OTP)
      const otpHash = OTPUtil.hashOTP(otpCode);
      const otpResult = await authRepository.verifyOTP(email, otpHash, 3); // 3 = RESET_PASSWORD

      if (!otpResult || !otpResult.success) {
        throw new AuthenticationError("Invalid or expired OTP");
      }

      // Step 3: Hash new password with bcrypt
      const newPasswordHash = await PasswordUtil.hashPassword(newPassword);

      // Step 4: Update password
      await authRepository.resetPasswordWithOTP(email, newPasswordHash, email);

      logger.info("Password reset successfully", { email });

      return {
        success: true,
        message:
          "Password reset successfully. Please login with your new password.",
      };
    } catch (error) {
      logger.error("AuthService.resetPassword error", {
        email,
        error: error.message,
      });
      throw error;
    }
  }

  // ========================= LOGOUT =========================
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
  _parseUserAgent(userAgent) {
    if (!userAgent) {
      return {
        deviceName: "Unknown Device",
        deviceTypeId: 1,
      };
    }

    const ua = userAgent.toLowerCase();
    let deviceTypeId = 1;
    let deviceName = "Unknown Device";

    if (ua.includes("mobile")) {
      deviceTypeId = 2;
      deviceName = "Mobile Device";
    } else if (ua.includes("tablet") || ua.includes("ipad")) {
      deviceTypeId = 3;
      deviceName = "Tablet";
    } else if (
      ua.includes("windows") ||
      ua.includes("macintosh") ||
      ua.includes("linux")
    ) {
      deviceTypeId = 4;
      deviceName = "Desktop Computer";
    }

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
