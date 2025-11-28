const ResponseUtil = require("../utils/response.util");
const logger = require("../config/logger.config");
const { ValidationError } = require("../utils/errors.util");

const accessTokenHeaderMiddleware = (req, res, next) => {
  try {
    const accessToken = req.headers["x-access-token"];

    // Validate token presence and format
    if (!accessToken || typeof accessToken !== "string" || accessToken.trim() === "") {
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

    // Store token reference for downstream middleware
    req.rawAccessToken = accessToken;

    next();
  } catch (error) {
    logger.error("Error validating access token header", {
      error: error.message,
      ip: req.ip,
      path: req.path,
    });
    
    next(error);
  }
};

module.exports = accessTokenHeaderMiddleware;
