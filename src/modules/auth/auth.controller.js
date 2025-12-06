// controllers -- HTTP layer / request <-> response
const ResponseUtil = require('../../utils/response.util');
const authService = require('./auth.service');
const { AuthValidator } = require('./auth.validator');
const logger = require('../../config/logger.config');
const config = require('../../config/env.config');
const AccessTokenUtil = require('../../utils/access_token.util');
const { RESPONSE_MESSAGES } = require('../../constants/operations');

class AuthController {
  // ======================== SEND OTP CONTROLLER ========================
  async sendOTP(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info('OTP send request received', {
        email: req.body.email,
        otp_type_id: req.body.otp_type_id,
        ip: req.ip,
      });

      const { error, value } = AuthValidator.validateSendOTP(req.body);
      if (error) {
        logger.warn('OTP send validation failed', {
          email: req.body.email,
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const ipAddress = req.ip || req.headers['x-forwarded-for'] || null;

      // 'value' is already validated and typed - no need for DTO wrapper
      const result = await authService.sendOTP(value.email, value.otp_type_id, {
        ipAddress,
      });

      const duration = Date.now() - startTime;
      logger.logPerformance('sendOTP', duration, {
        email: value.email,
        otp_type_id: value.otp_type_id,
        success: true,
      });

      logger.info('OTP sent successfully', {
        email: value.email,
        otp_type_id: value.otp_type_id,
        otpId: result.otpId,
      });

      return ResponseUtil.success(
        res,
        { otpId: result.otpId, expiresAt: result.expiresAt },
        result.message,
      );
    } catch (err) {
      const errorMessage = (err && err.message) || 'Failed to send OTP';

      // Handle email already registered
      if (errorMessage === 'Email already registered') {
        logger.warn('OTP send failed: Email already registered', {
          email: req.body.email,
          ip: req.ip,
        });
        return ResponseUtil.conflict(res, errorMessage);
      }

      // Handle invalid OTP type
      if (errorMessage === 'Invalid OTP type') {
        logger.warn('OTP send failed: Invalid OTP type', {
          email: req.body.email,
          otp_type_id: req.body.otp_type_id,
          ip: req.ip,
        });
        return ResponseUtil.badRequest(res, errorMessage);
      }

      // Log full error for debugging
      logger.logError(err, req, {
        operation: 'sendOTP',
        email: req.body.email,
      });

      // Return generic server error for unknown issues
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ======================= VERIFY OTP CONTROLLER =======================
  async verifyOTP(req, res, next) {
    try {
      logger.info('OTP verification request received', {
        email: req.body.email,
        ip: req.ip,
      });

      const { error, value } = AuthValidator.validateVerifyOTP(req.body);
      if (error) {
        logger.warn('OTP verification validation failed', {
          email: req.body.email,
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // 'value' is already validated - no need for DTO wrapper
      await authService.verifyOTP(
        value.email,
        value.otpCode,
        value.otp_type_id,
      );

      logger.logAuth('OTP_VERIFIED', {
        email: value.email,
        ip: req.ip,
      });

      return ResponseUtil.success(
        res,
        { email: value.email, verified: true },
        'OTP verified successfully',
      );
    } catch (err) {
      const errorMessage = (err && err.message) || 'Failed to verify OTP';

      if (errorMessage === 'Invalid or expired OTP') {
        logger.warn('OTP verification failed', {
          email: req.body.email,
          reason: errorMessage,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, errorMessage);
      }

      logger.logError(err, req, {
        operation: 'verifyOTP',
        email: req.body.email,
      });

      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // =================== COMPLETE REGISTRATION CONTROLLER ===================
  async completeRegistration(req, res, next) {
    const startTime = Date.now();

    try {
      logger.info('Business registration started', {
        email: req.body.email,
        businessName: req.body.businessName,
        businessType: req.body.businessType,
        ip: req.ip,
      });

      const { error, value } = AuthValidator.validateCompleteRegistration(
        req.body,
      );
      if (error) {
        logger.warn('Registration validation failed', {
          email: req.body.email,
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // 'value' is already validated - pass it directly to service
      const result = await authService.completeRegistration(value);

      // service already validates ids, but keep check
      if (!result.businessId || !result.branchId || !result.ownerId) {
        logger.error('Registration failed: Missing IDs', {
          email: value.email,
          result,
        });
        return ResponseUtil.serverError(
          res,
          'Registration failed: Missing required IDs in response',
        );
      }

      const duration = Date.now() - startTime;
      logger.logPerformance('completeRegistration', duration, {
        email: value.email,
        businessId: result.businessId,
        success: true,
      });

      logger.logAuth('REGISTRATION_COMPLETED', {
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
        result.message,
      );
    } catch (err) {
      const errorMessage = (err && err.message) || 'Registration failed';

      // Handle OTP verification failure
      if (errorMessage === 'Owner email not verified') {
        logger.warn('Registration failed: OTP not verified', {
          email: req.body.email,
          reason: errorMessage,
          ip: req.ip,
        });
        return ResponseUtil.badRequest(res, errorMessage);
      }

      // Handle email mismatch
      if (errorMessage === 'Business email and owner email must be different') {
        logger.warn('Registration validation failed: Email mismatch', {
          email: req.body.email,
          reason: errorMessage,
          ip: req.ip,
        });
        return ResponseUtil.badRequest(res, errorMessage);
      }

      // Log full error for debugging
      logger.logError(err, req, {
        operation: 'completeRegistration',
        email: req.body.email,
      });

      // Return the error message directly
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ========================= LOGIN WITH OTP CONTROLLER =========================
  async loginWithOTP(req, res, next) {
    const startTime = Date.now();

    try {
      // validation and service call remains same (AuthValidator etc.)
      const { error, value } = AuthValidator.validateLoginOTP(req.body);
      if (error) {
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const ipAddress =
        req.ip ||
        req.headers['x-forwarded-for'] ||
        req.connection?.remoteAddress ||
        null;
      const userAgent = req.get('user-agent');

      const user = await authService.loginWithOTP(
        value.email,
        value.otpCode,
        value.otp_type_id,
        ipAddress,
        userAgent,
      );

      if (!user || !user.user_id) {
        return ResponseUtil.unauthorized(res, 'Invalid login credentials');
      }

      // session token created by authService.loginWithOTP
      const sessionToken = user.session_token;

      // Generate signed access token
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
      const accessToken = tokenResult.accessToken;
      const accessTokenExpiry = tokenResult.expiresAt;

      // set cookies (HttpOnly)
      // session token usually longer-lived (but still moderately short)
      // Set cookie expiration from session token metadata if needed; using tokenResult for access token
      const sessionCookieOpts = {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        maxAge: 60 * 60 * 1000,
      };
      const accessCookieOpts = {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        maxAge:
          parseInt(process.env.ACCESS_TOKEN_EXPIRES_MIN || '15', 10) *
          60 *
          1000,
      };

      res.cookie('session_token', sessionToken, sessionCookieOpts);
      res.cookie('access_token', accessToken, accessCookieOpts);

      logger.logAuth('LOGIN_SUCCESS', {
        email: value.email,
        userId: user.user_id,
        sessionToken: sessionToken
          ? sessionToken.substring(0, 20) + '...'
          : 'failed',
      });

      return ResponseUtil.success(
        res,
        {
          session_expires_at: accessTokenExpiry, // still provide expiry info
        },
        'Login successful',
      );
    } catch (err) {
      // existing error handling
      const errorMessage = (err && err.message) || 'Failed to login';
      if (errorMessage === 'Invalid or expired OTP') {
        return ResponseUtil.unauthorized(res, errorMessage);
      }
      logger.logError(err, req, {
        operation: 'loginWithOTP',
        email: req.body.email,
        ip: req.ip,
      });
      return ResponseUtil.serverError(res, errorMessage);
    }
  }

  // ========================= DECRYPT USER DATA CONTROLLER =========================
  async decryptUserData(req, res, next) {
    try {
      logger.debug('Decrypt user data request received', {
        ip: req.ip,
      });

      // Extract access token from cookie (mandatory)
      const accessToken = req.cookies?.access_token;

      if (!accessToken) {
        logger.warn('Missing access token cookie in decrypt request', {
          ip: req.ip,
        });
        return ResponseUtil.badRequest(res, 'access_token cookie is required');
      }

      // Validate token structure
      if (!AccessTokenUtil.isValidTokenStructure(accessToken)) {
        logger.warn('Invalid access token structure in decrypt request', {
          ip: req.ip,
        });
        return ResponseUtil.badRequest(res, 'Invalid access token format');
      }

      // Decrypt the token to get user data
      const userData = AccessTokenUtil.decryptAccessToken(accessToken);

      if (!userData || !userData.user_id) {
        logger.warn('Failed to extract user data from access token', {
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, 'Invalid access token');
      }

      // Return only the necessary user data fields
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

      logger.debug('User data decrypted successfully', {
        userId: userData.user_id,
        businessId: userData.business_id,
        ip: req.ip,
      });

      return ResponseUtil.success(
        res,
        decryptedData,
        'User data decrypted successfully',
      );
    } catch (err) {
      // Handle different error types
      if (err.message.includes('tampered')) {
        logger.warn('Tampered access token in decrypt request', {
          error: err.message,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(
          res,
          'Access token has been compromised',
        );
      }

      if (err.message.includes('expired')) {
        logger.warn('Expired access token in decrypt request', {
          error: err.message,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, 'Access token has expired');
      }

      if (err.message.includes('corrupted')) {
        logger.warn('Corrupted access token in decrypt request', {
          error: err.message,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, 'Access token is corrupted');
      }

      logger.error('Error decrypting user data', {
        error: err.message,
        ip: req.ip,
      });

      return ResponseUtil.unauthorized(res, 'Failed to decrypt user data');
    }
  }

  // ========================= REFRESH TOKENS CONTROLLER =========================
  // Called by clients when access token expired; session cookie present
  async refreshTokens(req, res, next) {
    try {
      const sessionToken = req.cookies?.session_token;
      if (!sessionToken) {
        return ResponseUtil.badRequest(res, 'session_token cookie is required');
      }

      const refreshResult = await authService.refreshTokens(sessionToken);

      if (!refreshResult || !refreshResult.isSuccess) {
        return ResponseUtil.unauthorized(
          res,
          refreshResult?.errorMessage || 'Failed to refresh tokens',
        );
      }

      // set rotated session cookie + new access token cookie
      res.cookie('session_token', refreshResult.sessionToken, {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        maxAge: refreshResult.sessionMaxAgeMs || 60 * 60 * 1000,
      });
      res.cookie('access_token', refreshResult.accessToken, {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
        maxAge:
          parseInt(process.env.ACCESS_TOKEN_EXPIRES_MIN || '15', 10) *
          60 *
          1000,
      });

      return ResponseUtil.success(res, { refreshed: true }, 'Tokens refreshed');
    } catch (err) {
      logger.logError(err, req, { operation: 'refreshTokens' });
      return ResponseUtil.serverError(res, 'Failed to refresh tokens');
    }
  }

  // ========================= LOGOUT CONTROLLER =========================
  async logout(req, res, next) {
    try {
      // Middleware (requireAccessToken) already validated and attached:
      // - req.user (from access token)
      // - req.accessToken (access token)

      const userId = req.user.user_id;

      const result = await authService.logout(userId);

      if (!result.isSuccess) {
        logger.warn('Logout failed', {
          userId,
          errorMessage: result.errorMessage,
        });
        return ResponseUtil.serverError(
          res,
          result.errorMessage || RESPONSE_MESSAGES.LOGOUT_FAILED,
        );
      }

      // Clear authentication cookies
      res.clearCookie('access_token', {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
      });
      res.clearCookie('session_token', {
        httpOnly: config.cookie.httpOnly,
        secure: config.cookie.secure,
        sameSite: config.cookie.sameSite,
      });

      logger.logAuth('LOGOUT_SUCCESS', {
        userId,
      });

      return ResponseUtil.success(
        res,
        { logged_out: true, userId },
        RESPONSE_MESSAGES.LOGOUT_SUCCESS,
      );
    } catch (error) {
      logger.logError(error, req, {
        operation: 'logout',
      });
      return ResponseUtil.serverError(res, 'Failed to logout');
    }
  }
}

module.exports = new AuthController();
