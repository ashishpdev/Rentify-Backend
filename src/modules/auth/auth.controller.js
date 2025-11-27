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

class AuthController {
  async sendOTP(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info("OTP send request received", {
        email: req.body.email,
        otpType: req.body.otpType,
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
      const dto = new SendOTPDTO(value.email, value.otpType);

      const result = await authService.sendOTP(dto.email, dto.otpType, {
        ipAddress,
      });

      const duration = Date.now() - startTime;
      logger.logPerformance("sendOTP", duration, {
        email: value.email,
        otpType: value.otpType,
        success: true,
      });

      logger.info("OTP sent successfully", {
        email: value.email,
        otpType: value.otpType,
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

      await authService.verifyOTP(value.email, value.otpCode);

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

      const user = await authService.loginWithOTP(value.email, value.otpCode, ipAddress, userAgent);

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

      logger.logAuth("LOGIN_SUCCESS", {
        email: value.email,
        userId: user.user_id,
        businessId: user.business_id,
        isOwner: user.is_owner,
        sessionToken: user.session_token,
        ip: req.ip,
      });

      return ResponseUtil.success(
        res,
        {
          user_id: user.user_id,
          business_id: user.business_id,
          branch_id: user.branch_id,
          role_id: user.role_id,
          is_owner: user.is_owner,
          user_name: user.user_name,
          contact_number: user.contact_number,
          business_name: user.business_name,
          session_token: user.session_token,
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

}

module.exports = new AuthController();
