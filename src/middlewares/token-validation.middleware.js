// src/middlewares/token-validation.middleware.js
const logger = require("../config/logger.config");
const ResponseUtil = require("../utils/response.util");
const AccessTokenUtil = require("../utils/access_token.util");
const SessionTokenUtil = require("../utils/session_token.util");

function createTokenValidationMiddleware(
  requireAccess = true,
  requireSession = false
) {
  return async (req, res, next) => {
    try {
      // read tokens from cookies now (HttpOnly cookies set by server)
      const cookieAccessToken = req.cookies?.access_token;
      const cookieSessionToken = req.cookies?.session_token;

      // =================== VALIDATE BOTH TOKENS ===================
      if (requireAccess && requireSession) {
        const sessionToken = cookieSessionToken?.trim();
        const accessToken = cookieAccessToken?.trim();

        if (!sessionToken) {
          return ResponseUtil.badRequest(res, "session_token cookie is required");
        }
        if (!accessToken) {
          return ResponseUtil.badRequest(res, "access_token cookie is required");
        }

        // Validate access token JWT structure and decrypt
        if (!AccessTokenUtil.isValidTokenStructure(accessToken)) {
          return ResponseUtil.unauthorized(res, "Invalid access token format");
        }

        const userData = AccessTokenUtil.decryptAccessToken(accessToken);
        if (!userData || !userData.user_id) {
          return ResponseUtil.unauthorized(res, "Invalid access token");
        }

        // Validate session token structure and decrypt (local decrypt, no DB call)
        if (!SessionTokenUtil.isValidTokenStructure(sessionToken)) {
          return ResponseUtil.unauthorized(res, "Invalid session token format");
        }

        const sessionValidation =
          SessionTokenUtil.validateSessionToken(sessionToken);
        if (!sessionValidation.isValid) {
          if (sessionValidation.error.includes("expired")) {
            return ResponseUtil.unauthorized(res, "Session token expired");
          }
          if (sessionValidation.error.includes("tampered")) {
            return ResponseUtil.unauthorized(
              res,
              "Session token has been compromised"
            );
          }
          return ResponseUtil.unauthorized(res, "Invalid session token");
        }

        const sessionData = sessionValidation.sessionData;

        if (sessionData.user_id !== userData.user_id) {
          return ResponseUtil.unauthorized(res, "Token user mismatch");
        }

        req.sessionToken = sessionToken;
        req.sessionData = {
          user_id: sessionData.user_id,
          business_id: sessionData.business_id,
          branch_id: sessionData.branch_id,
          device_id: sessionData.device_id,
          ip_address: sessionData.ip_address,
          expiry_at: sessionData.expiry_at,
          is_active: true,
        };
        req.accessToken = accessToken;
        req.user = userData;
      }
      // =================== VALIDATE ACCESS TOKEN ===================
      else if (requireAccess) {
        const accessToken = cookieAccessToken?.trim();

        if (!accessToken) {
          return ResponseUtil.badRequest(res, "access_token cookie is required");
        }

        if (!AccessTokenUtil.isValidTokenStructure(accessToken)) {
          return ResponseUtil.unauthorized(res, "Invalid access token format");
        }

        const userData = AccessTokenUtil.decryptAccessToken(accessToken);
        if (!userData || !userData.user_id) {
          return ResponseUtil.unauthorized(res, "Invalid access token");
        }

        req.accessToken = accessToken;
        req.user = userData;
      }
      // =================== VALIDATE SESSION TOKEN ===================
      else if (requireSession) {
        const sessionToken = cookieSessionToken?.trim();

        if (!sessionToken) {
          return ResponseUtil.badRequest(res, "session_token cookie is required");
        }

        if (!SessionTokenUtil.isValidTokenStructure(sessionToken)) {
          return ResponseUtil.unauthorized(res, "Invalid session token format");
        }

        const sessionValidation =
          SessionTokenUtil.validateSessionToken(sessionToken);
        if (!sessionValidation.isValid) {
          if (sessionValidation.error.includes("expired")) {
            return ResponseUtil.unauthorized(res, "Session token expired");
          }
          if (sessionValidation.error.includes("tampered")) {
            return ResponseUtil.unauthorized(
              res,
              "Session token has been compromised"
            );
          }
          return ResponseUtil.unauthorized(res, "Invalid or expired session");
        }

        const sessionData = sessionValidation.sessionData;

        req.sessionToken = sessionToken;
        req.sessionData = {
          user_id: sessionData.user_id,
          business_id: sessionData.business_id,
          branch_id: sessionData.branch_id,
          device_id: sessionData.device_id,
          ip_address: sessionData.ip_address,
          expiry_at: sessionData.expiry_at,
          is_active: true,
        };
      }

      next();
    } catch (error) {
      logger.error("Token validation error", { error: error.message });

      if (error.message.includes("tampered")) {
        return ResponseUtil.unauthorized(
          res,
          "Token has been compromised"
        );
      }

      if (error.message.includes("expired")) {
        return ResponseUtil.unauthorized(res, "Token has expired");
      }

      return ResponseUtil.unauthorized(res, "Token validation failed");
    }
  };
}

const requireBothTokens = createTokenValidationMiddleware(true, true);
const requireAccessToken = createTokenValidationMiddleware(true, false);
const requireSessionToken = createTokenValidationMiddleware(false, true);

module.exports = {
  createTokenValidationMiddleware,
  requireBothTokens,
  requireAccessToken,
  requireSessionToken,
};
