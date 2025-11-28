/**
 * Middleware Factories for Consistent Token Handling
 * Following DRY principle and middleware composition patterns
 */

const logger = require("../../config/logger.config");
const ResponseUtil = require("../../utils/response.util");
const tokenService = require("../../modules/auth/token.service");
const {
  ValidationError,
  AuthenticationError,
} = require("../../utils/errors.util");

/**
 * Factory function to create token validation middleware
 * @param {boolean} requireSession - Whether to require session token
 * @param {boolean} requireAccess - Whether to require access token
 * @returns {Function} - Express middleware function
 */
function createTokenValidationMiddleware(
  requireAccess = true,
  requireSession = false
) {
  return (req, res, next) => {
    try {
      if (requireAccess && requireSession) {
        // Extract and validate both tokens
        const { userId, sessionToken, userData } =
          tokenService.extractAndValidateTokens(req.headers);

        req.userId = userId;
        req.sessionToken = sessionToken;
        req.userData = userData;
      } else if (requireAccess) {
        // Extract and validate access token only
        const { userId, userData } =
          tokenService.extractAndValidateAccessToken(req.headers);

        req.userId = userId;
        req.userData = userData;
      } else if (requireSession) {
        // Extract session token only
        const sessionToken = tokenService.extractSessionToken(req.headers);
        req.sessionToken = sessionToken;
      }

      next();
    } catch (error) {
      // Errors from token service are already AppError instances
      next(error);
    }
  };
}

/**
 * Middleware requiring both access and session tokens
 */
const requireBothTokens = createTokenValidationMiddleware(true, true);

/**
 * Middleware requiring only access token
 */
const requireAccessToken = createTokenValidationMiddleware(true, false);

/**
 * Middleware requiring only session token
 */
const requireSessionToken = createTokenValidationMiddleware(false, true);

module.exports = {
  createTokenValidationMiddleware,
  requireBothTokens,
  requireAccessToken,
  requireSessionToken,
};
