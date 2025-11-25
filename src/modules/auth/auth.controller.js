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
        otpType: req.body.otpType,
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

      await authService.verifyOTP(value.email, value.otpCode, value.otpType);

      logger.logAuth("OTP_VERIFIED", {
        email: value.email,
        otpType: value.otpType,
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
}

module.exports = new AuthController();
