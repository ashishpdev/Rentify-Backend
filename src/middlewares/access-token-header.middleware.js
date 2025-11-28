// Middleware to ensure X-Access-Token header is present
// This is a simple validation middleware that only checks for the presence of the header
// The actual token validation and decryption happens in the controller or access-token-validator middleware

const ResponseUtil = require("../utils/response.util");
const logger = require("../config/logger.config");

class AccessTokenHeaderMiddleware {
  /**
   * Middleware to ensure X-Access-Token header is present
   * Use this before routes that require the access token in header
   *
   * @param {Object} req - Express request
   * @param {Object} res - Express response
   * @param {Function} next - Express next function
   */
  static requireAccessTokenHeader(req, res, next) {
    const accessToken = req.headers["x-access-token"];

    if (
      !accessToken ||
      typeof accessToken !== "string" ||
      accessToken.trim() === ""
    ) {
      logger.warn("Missing or invalid X-Access-Token header", {
        ip: req.ip,
        path: req.path,
        method: req.method,
      });

      return ResponseUtil.badRequest(
        res,
        "X-Access-Token header is required and must be a valid string"
      );
    }

    // Header is present, continue to next middleware or route handler
    next();
  }
}

module.exports = AccessTokenHeaderMiddleware;
