// Access token validator middleware
// Decrypts and validates the encrypted access token
// Extracts user data from the token and makes it available for route handlers
const TokenUtil = require("../utils/token.util");
const ResponseUtil = require("../utils/response.util");
const logger = require("../config/logger.config");

class AccessTokenValidator {
  /**
   * Middleware to validate and decrypt access token
   * Should be used AFTER session-validator middleware
   * 
   * Expected header: X-Access-Token: <encrypted_token>
   * Or in Authorization header as second part: Authorization: Bearer <session> <access_token>
   * Or in body: accessToken field
   * 
   * Attaches to req: req.accessToken, req.user (decrypted user data)
   */
  static validateAccessToken(req, res, next) {
    try {
      // Extract access token from various sources
      const token =
        this._extractFromHeader(req) ||
        this._extractFromAuthHeader(req) ||
        this._extractFromBody(req) ||
        this._extractFromCookie(req, "access_token");

      if (!token) {
        logger.warn("Missing access token", {
          ip: req.ip,
          path: req.path,
          userId: req.sessionData?.user_id,
        });
        return ResponseUtil.unauthorized(res, "Access token is required");
      }

      // Check if token has valid structure before decrypting
      if (!TokenUtil.isValidTokenStructure(token)) {
        logger.warn("Invalid access token structure", {
          ip: req.ip,
          path: req.path,
          userId: req.sessionData?.user_id,
        });
        return ResponseUtil.unauthorized(res, "Invalid access token format");
      }

      // Decrypt the token and extract user data
      const userData = TokenUtil.decryptAccessToken(token);

      if (!userData || !userData.user_id) {
        logger.warn("Failed to extract user data from access token", {
          ip: req.ip,
          path: req.path,
          userId: req.sessionData?.user_id,
        });
        return ResponseUtil.unauthorized(res, "Invalid access token");
      }

      // Verify that access token user_id matches session user_id
      // This prevents token hijacking/misuse
      if (
        req.sessionData &&
        req.sessionData.user_id &&
        userData.user_id !== req.sessionData.user_id
      ) {
        logger.warn("Access token user mismatch with session", {
          tokenUserId: userData.user_id,
          sessionUserId: req.sessionData.user_id,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(
          res,
          "Access token does not match session"
        );
      }

      // Verify that business_id matches if present in session
      if (
        req.sessionData &&
        req.sessionData.business_id &&
        userData.business_id !== req.sessionData.business_id
      ) {
        logger.warn("Access token business mismatch with session", {
          tokenBusinessId: userData.business_id,
          sessionBusinessId: req.sessionData.business_id,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(
          res,
          "Access token does not match session"
        );
      }

      // Attach decrypted user data to request
      req.accessToken = token;
      req.user = userData;

      logger.debug("Access token validated successfully", {
        userId: userData.user_id,
        businessId: userData.business_id,
      });

      next();
    } catch (err) {
      // Different error messages for different failure reasons
      if (err.message.includes("tampered")) {
        logger.warn("Tampered access token detected", {
          error: err.message,
          ip: req.ip,
          path: req.path,
          userId: req.sessionData?.user_id,
        });
        return ResponseUtil.unauthorized(
          res,
          "Access token has been compromised"
        );
      }

      if (err.message.includes("expired")) {
        logger.warn("Expired access token used", {
          error: err.message,
          ip: req.ip,
          path: req.path,
          userId: req.sessionData?.user_id,
        });
        return ResponseUtil.unauthorized(res, "Access token has expired");
      }

      if (err.message.includes("corrupted")) {
        logger.warn("Corrupted access token", {
          error: err.message,
          ip: req.ip,
          path: req.path,
        });
        return ResponseUtil.unauthorized(res, "Access token is corrupted");
      }

      logger.error("Access token validation error", {
        error: err.message,
        ip: req.ip,
        path: req.path,
        userId: req.sessionData?.user_id,
      });

      return ResponseUtil.unauthorized(res, "Failed to validate access token");
    }
  }

  /**
   * Extract access token from X-Access-Token header
   */
  static _extractFromHeader(req) {
    return req.headers["x-access-token"];
  }

  /**
   * Extract access token from Authorization header
   * Expected format: "Bearer <session> <access_token>"
   * Or alternative: "AccessToken <token>"
   */
  static _extractFromAuthHeader(req) {
    const authHeader = req.headers.authorization || req.headers.Authorization;

    if (!authHeader) return null;

    const parts = authHeader.split(" ");

    // Check for "AccessToken <token>" format
    if (parts.length === 2 && /^AccessToken$/i.test(parts[0])) {
      return parts[1];
    }

    // Check for "Bearer <session> <access_token>" format (3 parts)
    if (parts.length === 3 && /^Bearer$/i.test(parts[0])) {
      return parts[2];
    }

    return null;
  }

  /**
   * Extract access token from request body
   */
  static _extractFromBody(req) {
    return req.body && req.body.accessToken;
  }

  /**
   * Extract access token from cookies
   */
  static _extractFromCookie(req, cookieName) {
    if (!req.headers.cookie) return null;

    const cookies = req.headers.cookie.split(";");
    for (const cookie of cookies) {
      const [name, value] = cookie.split("=").map((c) => c.trim());
      if (name === cookieName) {
        return decodeURIComponent(value);
      }
    }

    return null;
  }
}

module.exports = AccessTokenValidator;
