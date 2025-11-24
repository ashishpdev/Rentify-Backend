// src/modules/auth/auth.controller.js
const ResponseUtil = require("../../utils/response.util");
const authService = require("./auth.service");
const { AuthValidator } = require("./auth.validator");
const {
  SendOTPDTO,
  VerifyOTPDTO,
  CompleteRegistrationDTO,
} = require("./auth.dto");

class AuthController {
  async sendOTP(req, res, next) {
    try {
      const { error, value } = AuthValidator.validateSendOTP(req.body);
      if (error) return ResponseUtil.badRequest(res, error.details[0].message);

      const ipAddress = req.ip || req.headers["x-forwarded-for"] || null;
      const dto = new SendOTPDTO(value.email, value.otpType);

      const result = await authService.sendOTP(dto.email, dto.otpType, {
        ipAddress,
      });

      return ResponseUtil.success(
        res,
        { otpId: result.otpId, expiresAt: result.expiresAt },
        result.message
      );
    } catch (err) {
      next(err);
    }
  }

  async verifyOTP(req, res, next) {
    try {
      const { error, value } = AuthValidator.validateVerifyOTP(req.body);
      if (error) return ResponseUtil.badRequest(res, error.details[0].message);

      await authService.verifyOTP(value.email, value.otpCode, value.otpType);

      return ResponseUtil.success(
        res,
        { email: value.email, verified: true },
        "OTP verified successfully"
      );
    } catch (err) {
      if (err.message && err.message.includes("Invalid or expired OTP")) {
        return ResponseUtil.unauthorized(res, err.message);
      }
      next(err);
    }
  }

  async completeRegistration(req, res, next) {
    try {
      const { error, value } = AuthValidator.validateCompleteRegistration(
        req.body
      );
      if (error) return ResponseUtil.badRequest(res, error.details[0].message);

      // Create DTO only to keep shapes consistent (service expects plain object)
      const dto = new CompleteRegistrationDTO(value);

      const result = await authService.completeRegistration(dto);

      // service already validates ids, but keep check
      if (!result.businessId || !result.branchId || !result.ownerId) {
        return ResponseUtil.serverError(
          res,
          "Registration failed: Missing required IDs in response"
        );
      }

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
        return ResponseUtil.conflict(res, err.message);
      }
      next(err);
    }
  }
}

module.exports = new AuthController();
