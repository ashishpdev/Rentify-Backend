// Authentication controller
const ResponseUtil = require("../../utils/response.util");
const authService = require("./auth.service");
const authValidator = require("./auth.validator");
const {
  SendOTPDTO,
  VerifyOTPDTO,
  CompleteRegistrationDTO,
} = require("./auth.dto");

class AuthController {
  /**
   * @desc    Send OTP to email
   * @route   POST /api/auth/send-otp
   * @access  Public
   */
  async sendOTP(req, res, next) {
    try {
      const { email, otpType } = req.body;

      // Validate request
      const { error, value } = authValidator.validateSendOTP({
        email,
        otpType,
      });

      if (error) {
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // Get user IP
      const ipAddress = req.ip || req.connection.remoteAddress;

      // Create DTO
      const dto = new SendOTPDTO(value.email, value.otpType);

      // Send OTP
      const result = await authService.sendOTP(dto.email, dto.otpType, {
        ipAddress,
      });

      return ResponseUtil.success(
        res,
        {
          otpId: result.otpId,
          expiresAt: result.expiresAt,
        },
        result.message
      );
    } catch (error) {
      next(error);
    }
  }

  /**
   * @desc    Verify OTP code
   * @route   POST /api/auth/verify-otp
   * @access  Public
   */
  async verifyOTP(req, res, next) {
    try {
      const { email, otpCode, otpType } = req.body;

      // Validate request
      const { error, value } = authValidator.validateVerifyOTP({
        email,
        otpCode,
        otpType,
      });

      if (error) {
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // Verify OTP
      await authService.verifyOTP(value.email, value.otpCode, value.otpType);

      return ResponseUtil.success(
        res,
        { email: value.email, verified: true },
        "OTP verified successfully"
      );
    } catch (error) {
      if (error.message.includes("Invalid or expired OTP")) {
        return ResponseUtil.unauthorized(res, error.message);
      }
      next(error);
    }
  }

  /**
   * @desc    Complete registration with verified OTPs
   * @route   POST /api/auth/complete-registration
   * @access  Public
   */
  async completeRegistration(req, res, next) {
    try {
      const registrationData = req.body;

      // Validate request
      const { error, value } =
        authValidator.validateCompleteRegistration(registrationData);

      if (error) {
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // Create DTO
      const dto = new CompleteRegistrationDTO(value);

      // Complete registration
      const result = await authService.completeRegistration(value);

      // Ensure we have all required IDs before sending success response
      if (!result.businessId || !result.branchId || !result.ownerId) {
        return ResponseUtil.internalServerError(
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
    } catch (error) {
      if (
        error.message.includes("already registered") ||
        error.message.includes("already exists")
      ) {
        return ResponseUtil.conflict(res, error.message);
      }
      next(error);
    }
  }

  // /**
  //  * @desc    Register a new user
  //  * @route   POST /api/auth/signup
  //  * @access  Public
  //  */
  // async signup(req, res, next) {
  //   try {
  //     const { email, password, firstName, lastName, businessName } = req.body;

  //     // TODO: Add validation
  //     if (!email || !password) {
  //       return ResponseUtil.badRequest(res, "Email and password are required");
  //     }

  //     // TODO: Implement signup logic
  //     // 1. Check if user already exists
  //     // 2. Hash password
  //     // 3. Create user in database
  //     // 4. Generate JWT token
  //     // 5. Return user data and token

  //     const userData = {
  //       id: 1,
  //       email,
  //       firstName,
  //       lastName,
  //       businessName,
  //     };

  //     return ResponseUtil.created(
  //       res,
  //       userData,
  //       "User registered successfully"
  //     );
  //   } catch (error) {
  //     next(error);
  //   }
  // }

  // /**
  //  * @desc    Login user
  //  * @route   POST /api/auth/login
  //  * @access  Public
  //  */
  // async login(req, res, next) {
  //   try {
  //     const { email, password } = req.body;

  //     // TODO: Implement login logic

  //     return ResponseUtil.success(
  //       res,
  //       null,
  //       "Login endpoint - To be implemented"
  //     );
  //   } catch (error) {
  //     next(error);
  //   }
  // }

  // /**
  //  * @desc    Get current user
  //  * @route   GET /api/auth/me
  //  * @access  Private
  //  */
  // async getCurrentUser(req, res, next) {
  //   try {
  //     // TODO: Implement get current user logic

  //     return ResponseUtil.success(
  //       res,
  //       null,
  //       "Get current user - To be implemented"
  //     );
  //   } catch (error) {
  //     next(error);
  //   }
  // }

  // /**
  //  * @desc    Logout user
  //  * @route   POST /api/auth/logout
  //  * @access  Private
  //  */
  // async logout(req, res, next) {
  //   try {
  //     // TODO: Implement logout logic

  //     return ResponseUtil.success(res, null, "Logged out successfully");
  //   } catch (error) {
  //     next(error);
  //   }
  // }
}

module.exports = new AuthController();
