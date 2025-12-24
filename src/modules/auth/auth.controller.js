// src/modules/auth/auth.controller.js
// HTTP layer - Request/Response handling
const ResponseUtil = require("../../utils/response.util");
const authService = require("./auth.service");
const { AuthValidator } = require("./auth.validator");
const logger = require("../../config/logger.config");
const config = require("../../config/env.config");
const AccessTokenUtil = require("../../utils/access_token.util");
const { RESPONSE_MESSAGES } = require("../../constants/operations");

class AuthController {
  // ======================== SEND OTP ========================
  async sendOTP(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info("OTP send request received", {
        email: req.body.email,
        otp_type_id: req.body.otp_type_id,
        ip: req.ip,
      });

      // Validate request
      const { error, value } = AuthValidator.validateSendOTP(req.body);
      if (error) {
        logger.warn("OTP send validation failed", {
          email: req.body.email,
          errors: error.details.map((d) => d.message),
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const ipAddress = req.ip || req.headers["x-forwarded-for"] || null;

      // Send OTP
      const result = await authService.sendOTP(value.email, value.otp_type_id, {
        ipAddress,
      });

      const duration = Date.now() - startTime;
      logger.logPerformance("sendOTP", duration, {
        email: value.email,
        otp_type_id: value.otp_type_id,
        success: true,
      });

      logger.info("OTP sent successfully", {
        email: value.email,
        otp_type_id: value.otp_type_id,
        otpId: result.otpId,
      });

      return ResponseUtil.success(
        res,
        { otpId: result.otpId, expiresAt: result.expiresAt },
        result.message
      );
    } catch (err) {
      const errorMessage = err?.message || "Failed to send OTP";

      // Handle specific errors
      if (errorMessage.includes("Email already registered")) {
        return ResponseUtil.conflict(res, errorMessage);
      }

      if (errorMessage.includes("Invalid OTP type")) {
        return ResponseUtil.badRequest(res, errorMessage);
      }

      if (errorMessage.includes("Email not registered")) {
        return ResponseUtil.notFound(res, errorMessage);
      }

      logger.logError(err, req, { operation: "sendOTP" });
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ======================== VERIFY OTP ========================
  async verifyOTP(req, res, next) {
    try {
      logger.info("OTP verification request received", {
        email: req.body.email,
        ip: req.ip,
      });

      // Validate request
      const { error, value } = AuthValidator.validateVerifyOTP(req.body);
      if (error) {
        logger.warn("OTP verification validation failed", {
          email: req.body.email,
          errors: error.details.map((d) => d.message),
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // Verify OTP
      await authService.verifyOTP(
        value.email,
        value.otpCode,
        value.otp_type_id
      );

      logger.logAuth("OTP_VERIFIED", {
        email: value.email,
        ip: req.ip,
      });

      return ResponseUtil.success(
        res,
        { email: value.email, verified: true },
        "OTP verified successfully"
      );
    } catch (err) {
      const errorMessage = err?.message || "Failed to verify OTP";

      if (errorMessage.includes("Invalid or expired OTP")) {
        return ResponseUtil.unauthorized(res, errorMessage);
      }

      logger.logError(err, req, { operation: "verifyOTP" });
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ======================== COMPLETE REGISTRATION ========================
  async completeRegistration(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info("Business registration started", {
        email: req.body.ownerEmail,
        businessName: req.body.businessName,
        ip: req.ip,
      });

      // Validate request
      const { error, value } = AuthValidator.validateCompleteRegistration(
        req.body
      );
      if (error) {
        logger.warn("Registration validation failed", {
          email: req.body.ownerEmail,
          errors: error.details.map((d) => d.message),
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // Complete registration
      const result = await authService.completeRegistration(value);

      if (!result.businessId || !result.branchId || !result.ownerId) {
        logger.error("Registration failed: Missing IDs", {
          email: value.ownerEmail,
          result,
        });
        return ResponseUtil.serverError(
          res,
          "Registration failed: Missing required IDs in response"
        );
      }

      const duration = Date.now() - startTime;
      logger.logPerformance("completeRegistration", duration, {
        email: value.ownerEmail,
        businessId: result.businessId,
        success: true,
      });

      logger.logAuth("REGISTRATION_COMPLETED", {
        email: value.ownerEmail,
        businessId: result.businessId,
        branchId: result.branchId,
        ownerId: result.ownerId,
        businessName: value.businessName,
        ip: req.ip,
      });

      return ResponseUtil.created(
        res,
        {
          businessId: result.businessId,
          branchId: result.branchId,
          ownerId: result.ownerId,
        },
        result.message
      );
    } catch (err) {
      const errorMessage = err?.message || "Registration failed";

      if (errorMessage.includes("Owner email not verified")) {
        return ResponseUtil.badRequest(res, errorMessage);
      }

      if (errorMessage.includes("email must be different")) {
        return ResponseUtil.badRequest(res, errorMessage);
      }

      if (errorMessage.includes("already registered")) {
        return ResponseUtil.conflict(res, errorMessage);
      }

      logger.logError(err, req, { operation: "completeRegistration" });
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ======================== LOGIN WITH OTP ========================
  async loginWithOTP(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info("Login with OTP request received", {
        email: req.body.email,
        ip: req.ip,
      });

      // Validate request
      const { error, value } = AuthValidator.validateLoginOTP(req.body);
      if (error) {
        logger.warn("Login OTP validation failed", {
          email: req.body.email,
          errors: error.details.map((d) => d.message),
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const ipAddress =
        req.ip ||
        req.headers["x-forwarded-for"] ||
        req.connection?.remoteAddress ||
        null;
      const userAgent = req.get("user-agent");

      // Login
      const user = await authService.loginWithOTP(
        value.email,
        value.otpCode,
        ipAddress,
        userAgent
      );

      if (!user || !user.user_id) {
        return ResponseUtil.unauthorized(res, "Invalid login credentials");
      }

      // Generate access token
      const tokenData = {
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
      };

      const tokenResult = AccessTokenUtil.generateAccessToken(tokenData);

      // Set cookies
      const sessionCookieOpts = {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        domain: config.cookie.domain,
        maxAge: 60 * 60 * 1000, // 1 hour
      };

      const accessCookieOpts = {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        domain: config.cookie.domain,
        maxAge:
          parseInt(process.env.ACCESS_TOKEN_EXPIRES_MIN || "15", 10) *
          60 *
          1000,
      };

      res.cookie("session_token", user.session_token, sessionCookieOpts);
      res.cookie("access_token", tokenResult.accessToken, accessCookieOpts);

      const duration = Date.now() - startTime;
      logger.logPerformance("loginWithOTP", duration, { userId: user.user_id });

      logger.logAuth("LOGIN_SUCCESS", {
        email: value.email,
        userId: user.user_id,
        method: "OTP",
      });

      return ResponseUtil.success(
        res,
        {
          session_expires_at: tokenResult.expiresAt,
        },
        "Login successful"
      );
    } catch (err) {
      const errorMessage = err?.message || "Failed to login";

      if (errorMessage.includes("Invalid or expired OTP")) {
        return ResponseUtil.unauthorized(res, errorMessage);
      }

      if (errorMessage.includes("User not found")) {
        return ResponseUtil.unauthorized(res, "Invalid login credentials");
      }

      logger.logError(err, req, { operation: "loginWithOTP" });
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ======================== LOGIN WITH PASSWORD ========================
  async loginWithPassword(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info("Login with password request received", {
        email: req.body.email,
        ip: req.ip,
      });

      // Validate request
      const { error, value } = AuthValidator.validateLoginPassword(req.body);
      if (error) {
        logger.warn("Login password validation failed", {
          email: req.body.email,
          errors: error.details.map((d) => d.message),
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const ipAddress =
        req.ip ||
        req.headers["x-forwarded-for"] ||
        req.connection?.remoteAddress ||
        null;
      const userAgent = req.get("user-agent");

      // Login
      const user = await authService.loginWithPassword(
        value.email,
        value.password,
        ipAddress,
        userAgent
      );

      if (!user || !user.user_id) {
        return ResponseUtil.unauthorized(res, "Invalid email or password");
      }

      // Generate access token
      const tokenData = {
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
      };

      const tokenResult = AccessTokenUtil.generateAccessToken(tokenData);

      // Set cookies
      const sessionCookieOpts = {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        domain: config.cookie.domain,
        maxAge: 60 * 60 * 1000,
      };

      const accessCookieOpts = {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        domain: config.cookie.domain,
        maxAge:
          parseInt(process.env.ACCESS_TOKEN_EXPIRES_MIN || "15", 10) *
          60 *
          1000,
      };

      res.cookie("session_token", user.session_token, sessionCookieOpts);
      res.cookie("access_token", tokenResult.accessToken, accessCookieOpts);

      const duration = Date.now() - startTime;
      logger.logPerformance("loginWithPassword", duration, {
        userId: user.user_id,
      });

      logger.logAuth("LOGIN_SUCCESS", {
        email: value.email,
        userId: user.user_id,
        method: "PASSWORD",
      });

      return ResponseUtil.success(
        res,
        {
          session_expires_at: tokenResult.expiresAt,
        },
        "Login successful"
      );
    } catch (err) {
      const errorMessage = err?.message || "Failed to login";

      if (errorMessage.includes("Invalid email or password")) {
        return ResponseUtil.unauthorized(res, errorMessage);
      }

      if (errorMessage.includes("Account locked")) {
        return ResponseUtil.forbidden(res, errorMessage);
      }

      if (errorMessage.includes("Account is inactive")) {
        return ResponseUtil.forbidden(res, errorMessage);
      }

      logger.logError(err, req, { operation: "loginWithPassword" });
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ======================== CHANGE PASSWORD ========================
  async changePassword(req, res, next) {
    try {
      logger.info("Change password request received", {
        userId: req.user.user_id,
        ip: req.ip,
      });

      // Validate request
      const { error, value } = AuthValidator.validateChangePassword(req.body);
      if (error) {
        logger.warn("Change password validation failed", {
          userId: req.user.user_id,
          errors: error.details.map((d) => d.message),
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // Change password
      const result = await authService.changePassword(
        req.user.user_id,
        value.oldPassword,
        value.newPassword,
        req.user.email
      );

      // Clear cookies to force re-login
      res.clearCookie("access_token", {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
      });
      res.clearCookie("session_token", {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
      });

      logger.logAuth("PASSWORD_CHANGED", {
        userId: req.user.user_id,
        email: req.user.email,
      });

      return ResponseUtil.success(
        res,
        { changed: true },
        result.message || "Password changed successfully. Please login again."
      );
    } catch (err) {
      const errorMessage = err?.message || "Failed to change password";

      if (errorMessage.includes("Current password is incorrect")) {
        return ResponseUtil.badRequest(res, errorMessage);
      }

      if (errorMessage.includes("same password")) {
        return ResponseUtil.badRequest(res, errorMessage);
      }

      if (errorMessage.includes("User not found")) {
        return ResponseUtil.notFound(res, errorMessage);
      }

      logger.logError(err, req, { operation: "changePassword" });
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ======================== RESET PASSWORD ========================
  async resetPassword(req, res, next) {
    try {
      logger.info("Reset password request received", {
        email: req.body.email,
        ip: req.ip,
      });

      // Validate request
      const { error, value } = AuthValidator.validateResetPassword(req.body);
      if (error) {
        logger.warn("Reset password validation failed", {
          email: req.body.email,
          errors: error.details.map((d) => d.message),
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // Reset password
      const result = await authService.resetPassword(
        value.email,
        value.otpCode,
        value.newPassword
      );

      logger.logAuth("PASSWORD_RESET", {
        email: value.email,
      });

      return ResponseUtil.success(
        res,
        { reset: true },
        result.message ||
          "Password reset successfully. Please login with your new password."
      );
    } catch (err) {
      const errorMessage = err?.message || "Failed to reset password";

      if (errorMessage.includes("Invalid or expired OTP")) {
        return ResponseUtil.badRequest(res, errorMessage);
      }

      if (errorMessage.includes("User not found")) {
        return ResponseUtil.notFound(res, errorMessage);
      }

      logger.logError(err, req, { operation: "resetPassword" });
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ======================== DECRYPT USER DATA ========================
  async decryptUserData(req, res, next) {
    try {
      logger.debug("Decrypt user data request received", { ip: req.ip });

      // Extract access token from cookie
      const accessToken = req.cookies?.access_token;

      if (!accessToken) {
        logger.warn("Missing access token cookie", { ip: req.ip });
        return ResponseUtil.badRequest(res, "access_token cookie is required");
      }

      // Validate token structure
      if (!AccessTokenUtil.isValidTokenStructure(accessToken)) {
        logger.warn("Invalid access token structure", { ip: req.ip });
        return ResponseUtil.badRequest(res, "Invalid access token format");
      }

      // Decrypt token
      const userData = AccessTokenUtil.decryptAccessToken(accessToken);

      if (!userData || !userData.user_id) {
        logger.warn("Failed to extract user data from access token", {
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, "Invalid access token");
      }

      // Return user data
      const decryptedData = {
        user_id: userData.user_id,
        business_id: userData.business_id,
        branch_id: userData.branch_id,
        role_id: userData.role_id,
        email: userData.email,
        contact_number: userData.contact_number,
        user_name: userData.user_name,
        business_name: userData.business_name,
        branch_name: userData.branch_name,
        role_name: userData.role_name,
        is_owner: userData.is_owner,
      };

      logger.debug("User data decrypted successfully", {
        userId: userData.user_id,
        businessId: userData.business_id,
        ip: req.ip,
      });

      return ResponseUtil.success(
        res,
        decryptedData,
        "User data decrypted successfully"
      );
    } catch (err) {
      // Handle token errors
      if (err.message.includes("tampered")) {
        return ResponseUtil.unauthorized(
          res,
          "Access token has been compromised"
        );
      }

      if (err.message.includes("expired")) {
        return ResponseUtil.unauthorized(res, "Access token has expired");
      }

      if (err.message.includes("corrupted")) {
        return ResponseUtil.unauthorized(res, "Access token is corrupted");
      }

      logger.error("Error decrypting user data", {
        error: err.message,
        ip: req.ip,
      });
      return ResponseUtil.unauthorized(res, "Failed to decrypt user data");
    }
  }

  // ======================== REFRESH TOKENS ========================
  async refreshTokens(req, res, next) {
    try {
      logger.info("Refresh tokens request received", { ip: req.ip });

      const sessionToken = req.cookies?.session_token;
      if (!sessionToken) {
        return ResponseUtil.badRequest(res, "session_token cookie is required");
      }

      // Refresh tokens
      const refreshResult = await authService.refreshTokens(sessionToken);

      if (!refreshResult || !refreshResult.isSuccess) {
        return ResponseUtil.unauthorized(
          res,
          refreshResult?.errorMessage || "Failed to refresh tokens"
        );
      }

      // Set new cookies
      res.cookie("session_token", refreshResult.sessionToken, {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        domain: config.cookie.domain,
        maxAge: refreshResult.sessionMaxAgeMs || 60 * 60 * 1000,
      });

      res.cookie("access_token", refreshResult.accessToken, {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        domain: config.cookie.domain,
        maxAge:
          parseInt(process.env.ACCESS_TOKEN_EXPIRES_MIN || "15", 10) *
          60 *
          1000,
      });

      logger.info("Tokens refreshed successfully", { ip: req.ip });

      return ResponseUtil.success(
        res,
        { refreshed: true },
        "Tokens refreshed successfully"
      );
    } catch (err) {
      logger.logError(err, req, { operation: "refreshTokens" });
      return ResponseUtil.serverError(res, "Failed to refresh tokens");
    }
  }

  // ======================== LOGOUT ========================
  async logout(req, res, next) {
    try {
      logger.info("Logout request received", {
        userId: req.user.user_id,
        ip: req.ip,
      });

      // Logout
      const result = await authService.logout(req.user.user_id);

      if (!result.isSuccess) {
        logger.warn("Logout failed", {
          userId: req.user.user_id,
          errorMessage: result.errorMessage,
        });
        return ResponseUtil.serverError(
          res,
          result.errorMessage || RESPONSE_MESSAGES.LOGOUT_FAILED
        );
      }

      // Clear cookies
      res.clearCookie("access_token", {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
      });
      res.clearCookie("session_token", {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
      });

      logger.logAuth("LOGOUT_SUCCESS", {
        userId: req.user.user_id,
      });

      return ResponseUtil.success(
        res,
        { logged_out: true, userId: req.user.user_id },
        RESPONSE_MESSAGES.LOGOUT_SUCCESS || "Logged out successfully"
      );
    } catch (error) {
      logger.logError(error, req, { operation: "logout" });
      return ResponseUtil.serverError(res, "Failed to logout");
    }
  }
}

module.exports = new AuthController();
