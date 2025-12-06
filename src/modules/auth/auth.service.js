// service -- Business logic / orchestration
const authRepository = require("./auth.repository");
const EmailService = require("../../services/email.service");
const TokenUtil = require("../../utils/access_token.util");
const SessionTokenUtil = require("../../utils/session_token.util");
const OTPUtil = require("../../utils/otp.util");
const logger = require("../../config/logger.config");
const {
  DatabaseError,
  AuthenticationError,
} = require("../../utils/errors.util");
const fs = require("fs");
const path = require("path");
const handlebars = require("handlebars");

class AuthService {
  async _renderOtpTemplate({ otpCode, email, expiryMinutes = 10 }) {
    const filePath = path.join(__dirname, "../../templates/emailOtpHtml.hbs");
    const source = fs.readFileSync(filePath, "utf8");
    const template = handlebars.compile(source);
    return template({ otpCode, email, EXPIRY_MIN: expiryMinutes });
  }

  // ======================== SEND OTP EMAIL ========================
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

  // ========================= OTP SERVICES =========================
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
      });

      // send email (fire and await - if email fails we bubble up)
      await this.sendVerificationCode(email, otpCode, 10);

      console.log(
        `[OTP] Email: ${email}, Type ID: ${otp_type_id}, Code: ${otpCode}, ID: ${otpRecord.id}`
      );

      return {
        otpId: otpRecord.id,
        message: `OTP sent successfully to ${email}`,
        expiresAt: otpRecord.expiresAt,
      };
    } catch (err) {
      // Re-throw with original error message from repository/SP
      throw err;
    }
  }

  // ======================== VERIFY OTP CODE =======================
  async verifyOTP(email, otpCode, otp_type_id) {
    try {
      const hash = OTPUtil.hashOTP(otpCode);
      const result = await authRepository.verifyOTP(email, hash, otp_type_id);

      if (!result || !result.success) {
        throw new Error("Invalid or expired OTP");
      }
      return true;
    } catch (err) {
      // Re-throw the original error message without wrapping
      throw err;
    }
  }

  // ===================== COMPLETE REGISTRATION ====================
  async completeRegistration(registrationData) {
    try {
      // // Check if owner email already exists
      // const ownerExists = await authRepository.emailExists(
      //   registrationData.ownerEmail
      // );
      // if (ownerExists) {
      //   throw new Error("Owner email already registered");
      // }

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

  // ======================== LOGIN WITH OTP ========================
  async loginWithOTP(email, otpCode, ipAddress = null) {
    try {
      // Hash the OTP code
      const hash = OTPUtil.hashOTP(otpCode);

      // Login with OTP - get user info (OTP verification happens in SP)
      const user = await authRepository.loginWithOTP(email, hash, ipAddress);

      if (!user || !user.user_id) {
        throw new Error("Failed to retrieve user information");
      }

      // Generate encrypted session token with user data
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

      // Create session in database with encrypted token
      const sessionResult = await authRepository.createSession(
        user.user_id,
        tokenResult.sessionToken,
        tokenResult.expiresAt,
        ipAddress
      );

      if (!sessionResult.isSuccess) {
        throw new Error(
          sessionResult.errorMessage || "Failed to create session"
        );
      }

      return {
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
        session_token: sessionResult.sessionToken,
      };
    } catch (err) {
      // Re-throw the original error message without wrapping
      throw err;
    }
  }

  // ======================== EXTEND SESSION ========================
  // async extendSession(userId, currentSessionToken) {
  //   try {
  //     if (!userId || !currentSessionToken) {
  //       throw new AuthenticationError("User ID and session token are required");
  //     }

  //     // Decrypt current session token to get session data
  //     const currentSessionData =
  //       SessionTokenUtil.decryptSessionToken(currentSessionToken);

  //     // Generate new extended session token
  //     const extendedToken =
  //       SessionTokenUtil.generateExtendedSessionToken(currentSessionData);

  //     // Call repository to extend session (passing both old and new tokens)
  //     const result = await authRepository.extendSession(
  //       userId,
  //       currentSessionToken,
  //       extendedToken.sessionToken,
  //       extendedToken.expiresAt
  //     );

  //     if (!result.isSuccess) {
  //       throw new AuthenticationError(
  //         result.errorMessage || "Failed to extend session"
  //       );
  //     }

  //     return {
  //       isSuccess: result.isSuccess,
  //       sessionToken: result.sessionToken,
  //       expiryAt: result.expiryAt,
  //       errorMessage: result.errorMessage,
  //     };
  //   } catch (error) {
  //     if (error.statusCode) {
  //       throw error;
  //     }
  //     logger.error("AuthService.extendSession error", {
  //       userId,
  //       error: error.message,
  //     });
  //     throw new DatabaseError(
  //       `Failed to extend session: ${error.message}`,
  //       error
  //     );
  //   }
  // }

  // inside src/modules/auth/auth.service.js

  // ======================== REFRESH TOKENS ========================
  async refreshTokens(currentSessionToken) {
    try {
      // Decrypt current session token locally
      const currentSessionData =
        SessionTokenUtil.decryptSessionToken(currentSessionToken);

      if (!currentSessionData || !currentSessionData.user_id) {
        throw new AuthenticationError("Invalid session token");
      }

      // Generate new access token payload
      const tokenData = {
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

      const accessTokenResult = TokenUtil.generateAccessToken(tokenData);

      // Generate rotated session token
      const extendedSessionTokenObj =
        SessionTokenUtil.generateExtendedSessionToken(currentSessionData);
      const newSessionToken = extendedSessionTokenObj.sessionToken;
      const newExpiryAt = extendedSessionTokenObj.expiresAt;

      // Persist rotation in DB (extendSession stored procedure)
      // NOTE: extendSession in repository expects: (userId, oldSessionToken, newSessionToken, newExpiryAt)
      const repoResult = await authRepository.extendSession(
        currentSessionData.user_id,
        currentSessionToken,
        newSessionToken,
        newExpiryAt
      );

      if (!repoResult.isSuccess) {
        throw new Error(
          repoResult.errorMessage || "Failed to rotate session token"
        );
      }

      return {
        isSuccess: true,
        accessToken: accessTokenResult.accessToken,
        accessExpiresAt: accessTokenResult.expiresAt,
        sessionToken: newSessionToken,
        sessionExpiresAt: newExpiryAt,
        sessionMaxAgeMs: parseInt(
          process.env.SESSION_COOKIE_MAXAGE_MS || String(60 * 60 * 1000),
          10
        ),
      };
    } catch (err) {
      logger.error("AuthService.refreshTokens error", { error: err.message });
      throw err;
    }
  }

  // ======================== LOGOUT ========================
  async logout(userId) {
    try {
      if (!userId) {
        throw new AuthenticationError("User ID is required");
      }

      const result = await authRepository.logout(userId);

      return {
        isSuccess: result.success,
        errorMessage: result.error_message,
      };
    } catch (error) {
      if (error.statusCode) {
        throw error;
      }
      logger.error("AuthService.logout error", {
        userId,
        error: error.message,
      });
      throw new DatabaseError(`Failed to logout: ${error.message}`, error);
    }
  }
}

module.exports = new AuthService();
