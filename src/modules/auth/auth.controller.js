// src/modules/auth/auth.controller.js
const ResponseUtil = require("../../utils/response.util");
const authService = require("./auth.service");
const { AuthValidator } = require("./auth.validator");
const {
  SendOTPDTO,
  VerifyOTPDTO,
  CompleteRegistrationDTO,
} = require("./auth.dto");
const logger = require("../../config/logger.config");
const TokenUtil = require("../../utils/token.util");
const SessionValidator = require("../../middlewares/session-validator.middleware");

class AuthController {
  async sendOTP(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info("OTP send request received", {
        email: req.body.email,
        otp_type_id: req.body.otp_type_id,
        ip: req.ip,
      });

      const { error, value } = AuthValidator.validateSendOTP(req.body);
      if (error) {
        logger.warn("OTP send validation failed", {
          email: req.body.email,
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const ipAddress = req.ip || req.headers["x-forwarded-for"] || null;
      const dto = new SendOTPDTO(value.email, value.otp_type_id);

      const result = await authService.sendOTP(dto.email, dto.otp_type_id, {
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
      logger.logError(err, req, {
        operation: "sendOTP",
        email: req.body.email,
      });
      next(err);
    }
  }

  async verifyOTP(req, res, next) {
    try {
      logger.info("OTP verification request received", {
        email: req.body.email,
        ip: req.ip,
      });

      const { error, value } = AuthValidator.validateVerifyOTP(req.body);
      if (error) {
        logger.warn("OTP verification validation failed", {
          email: req.body.email,
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      await authService.verifyOTP(value.email, value.otpCode, value.otp_type_id);

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
      if (err.message && err.message.includes("Invalid or expired OTP")) {
        logger.warn("OTP verification failed", {
          email: req.body.email,
          reason: err.message,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, err.message);
      }
      logger.logError(err, req, {
        operation: "verifyOTP",
        email: req.body.email,
      });
      next(err);
    }
  }

  async completeRegistration(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info("Business registration started", {
        email: req.body.email,
        businessName: req.body.businessName,
        businessType: req.body.businessType,
        ip: req.ip,
      });

      const { error, value } = AuthValidator.validateCompleteRegistration(
        req.body
      );
      if (error) {
        logger.warn("Registration validation failed", {
          email: req.body.email,
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // Create DTO only to keep shapes consistent (service expects plain object)
      const dto = new CompleteRegistrationDTO(value);

      const result = await authService.completeRegistration(dto);

      // service already validates ids, but keep check
      if (!result.businessId || !result.branchId || !result.ownerId) {
        logger.error("Registration failed: Missing IDs", {
          email: value.email,
          result,
        });
        return ResponseUtil.serverError(
          res,
          "Registration failed: Missing required IDs in response"
        );
      }

      const duration = Date.now() - startTime;
      logger.logPerformance("completeRegistration", duration, {
        email: value.email,
        businessId: result.businessId,
        success: true,
      });

      logger.logAuth("REGISTRATION_COMPLETED", {
        email: value.email,
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
      if (
        err.message &&
        (err.message.includes("already registered") ||
          err.message.includes("already exists"))
      ) {
        logger.warn("Registration conflict", {
          email: req.body.email,
          reason: err.message,
        });
        return ResponseUtil.conflict(res, err.message);
      }
      logger.logError(err, req, {
        operation: "completeRegistration",
        email: req.body.email,
      });
      next(err);
    }
  }

  /**
   * Login user with email and OTP
   * This is the login endpoint that verifies OTP and returns user credentials
   * @param {Object} req - Express request object with email and otpCode in body
   * @param {Object} res - Express response object
   * @param {Function} next - Express next middleware function
   */
    async loginWithOTP(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info("Login with OTP request received", {
        email: req.body.email,
        ip: req.ip,
      });

      const { error, value } = AuthValidator.validateLoginOTP(req.body);
      if (error) {
        logger.warn("Login validation failed", {
          email: req.body.email,
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const ipAddress = req.ip || req.headers['x-forwarded-for'] || req.connection?.remoteAddress || null;
      const userAgent = req.get('user-agent');

      const user = await authService.loginWithOTP(value.email, value.otpCode, value.otp_type_id, ipAddress, userAgent);

      if (!user || !user.user_id || !user.business_id || user.role_id === undefined) {
        logger.warn("Login failed - invalid user data", {
          email: value.email,
          ip: req.ip,
          user,
        });
        return ResponseUtil.unauthorized(res, "Invalid login credentials");
      }

      const duration = Date.now() - startTime;
      logger.logPerformance("loginWithOTP", duration, {
        email: value.email,
        userId: user.user_id,
        success: true,
      });

      // Create a session in database
      let sessionToken;
      try {
        const sessionInfo = await SessionValidator.createSession(user, 24);
        sessionToken = sessionInfo.sessionToken;
      } catch (sessionErr) {
        logger.error("Failed to create session, but proceeding with login", {
          error: sessionErr.message,
          userId: user.user_id,
        });
        // If session creation fails, we can continue with a fallback
        // In production, you might want to fail the login
      }

      // Generate encrypted access token from user data
      let accessToken;
      let accessTokenExpiry;
      try {
        const tokenData = {
          user_id: user.user_id,
          business_id: user.business_id,
          branch_id: user.branch_id,
          role_id: user.role_id,
          is_owner: user.is_owner,
          user_name: user.user_name,
          contact_number: user.contact_number,
          business_name: user.business_name,
          email: value.email,
        };

        const tokenResult = TokenUtil.generateAccessToken(tokenData);
        accessToken = tokenResult.accessToken;
        accessTokenExpiry = tokenResult.expiresAt;
      } catch (tokenErr) {
        logger.error("Failed to generate access token", {
          error: tokenErr.message,
          userId: user.user_id,
        });
        return ResponseUtil.serverError(
          res,
          "Failed to generate security tokens"
        );
      }

      logger.logAuth("LOGIN_SUCCESS", {
        email: value.email,
        userId: user.user_id,
        businessId: user.business_id,
        isOwner: user.is_owner,
        sessionToken: sessionToken ? sessionToken.substring(0, 20) + "..." : "failed",
        ip: req.ip,
      });

      return ResponseUtil.success(
        res,
        {
          // Return only tokens - client must call decrypt endpoint for user data
          session_token: sessionToken || null,
          access_token: accessToken,
          token_expires_at: accessTokenExpiry,
        },
        "Login successful"
      );
    } catch (err) {
      // Handle known failure reasons explicitly so clients get meaningful responses
      const msg = (err && err.message) || "";

      if (msg.includes("Invalid or expired OTP")) {
        logger.warn("OTP verification failed during login", {
          email: req.body.email,
          reason: msg,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, "Invalid or expired OTP");
      }

      // If stored procedure returned an error message, surface it (but avoid leaking sensitive details)
      logger.logError(err, req, {
        operation: "loginWithOTP",
        email: req.body.email,
        ip: req.ip,
      });

      // Return generic server error (error handler will also capture full details)
      return ResponseUtil.serverError(res, "Failed to login. Please try again.");
      // OR: if you prefer centralized error handling, call next(err);
      // next(err);
    }
  }

  /**
   * Logout user and invalidate session
   * Requires valid session_token
   */
  async logout(req, res, next) {
    try {
      const sessionToken = req.sessionToken;

      if (!sessionToken) {
        return ResponseUtil.badRequest(res, "No active session to logout");
      }

      // Invalidate the session
      await SessionValidator.invalidateSession(sessionToken);

      logger.logAuth("LOGOUT_SUCCESS", {
        userId: req.sessionData?.user_id,
        sessionId: req.sessionData?.session_id,
        ip: req.ip,
      });

      return ResponseUtil.success(res, { logged_out: true }, "Logged out successfully");
    } catch (err) {
      logger.logError(err, req, {
        operation: "logout",
        userId: req.sessionData?.user_id,
      });
      return ResponseUtil.serverError(res, "Failed to logout");
    }
  }

  /**
   * Decrypt access token and return user data
   * This endpoint decrypts the access_token and returns the encrypted user data
   * Can be called by client to get user info when needed
   * Does NOT require session validation - only validates access token integrity
   * 
   * @param {Object} req - Express request with accessToken in body or header
   * @param {Object} res - Express response
   * @param {Function} next - Express next function
   */
  async decryptUserData(req, res, next) {
    try {
      logger.debug("Decrypt user data request received", {
        ip: req.ip,
      });

      // Extract access token from body or header
      const accessToken = req.body?.accessToken || req.headers["x-access-token"];

      if (!accessToken) {
        logger.warn("Missing access token in decrypt request", {
          ip: req.ip,
        });
        return ResponseUtil.badRequest(res, "Access token is required");
      }

      // Validate token structure
      if (!TokenUtil.isValidTokenStructure(accessToken)) {
        logger.warn("Invalid access token structure in decrypt request", {
          ip: req.ip,
        });
        return ResponseUtil.badRequest(res, "Invalid access token format");
      }

      // Decrypt the token to get user data
      const userData = TokenUtil.decryptAccessToken(accessToken);

      if (!userData || !userData.user_id) {
        logger.warn("Failed to extract user data from access token", {
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, "Invalid access token");
      }

      // Return only the necessary user data fields
      const decryptedData = {
        user_id: userData.user_id,
        business_id: userData.business_id,
        branch_id: userData.branch_id,
        role_id: userData.role_id,
        is_owner: userData.is_owner,
        user_name: userData.user_name,
        contact_number: userData.contact_number,
        business_name: userData.business_name,
        email: userData.email,
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
      // Handle different error types
      if (err.message.includes("tampered")) {
        logger.warn("Tampered access token in decrypt request", {
          error: err.message,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(
          res,
          "Access token has been compromised"
        );
      }

      if (err.message.includes("expired")) {
        logger.warn("Expired access token in decrypt request", {
          error: err.message,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, "Access token has expired");
      }

      if (err.message.includes("corrupted")) {
        logger.warn("Corrupted access token in decrypt request", {
          error: err.message,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, "Access token is corrupted");
      }

      logger.error("Error decrypting user data", {
        error: err.message,
        ip: req.ip,
      });

      return ResponseUtil.unauthorized(res, "Failed to decrypt user data");
    }
  }

}

module.exports = new AuthController();
