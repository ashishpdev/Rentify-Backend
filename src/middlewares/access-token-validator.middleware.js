const TokenUtil = require("../utils/access_token.util");
const ResponseUtil = require("../utils/response.util");
const logger = require("../config/logger.config");

const accessTokenValidator = (req, res, next) => {
  try {
    const token = req.headers["x-access-token"];

    if (!token) {
      return ResponseUtil.badRequest(res, "x-access-token header is required");
    }

    if (!TokenUtil.isValidTokenStructure(token)) {
      return ResponseUtil.unauthorized(res, "Invalid access token format");
    }

    const userData = TokenUtil.decryptAccessToken(token);

    if (!userData || !userData.user_id) {
      return ResponseUtil.unauthorized(res, "Invalid access token");
    }

    if (
      req.sessionData &&
      req.sessionData.user_id &&
      userData.user_id !== req.sessionData.user_id
    ) {
      return ResponseUtil.unauthorized(
        res,
        "Access token does not match session"
      );
    }

    req.accessToken = token;
    req.user = userData;

    next();
  } catch (error) {
    logger.error("Access token validation error", { error: error.message });

    if (error.message.includes("tampered")) {
      return ResponseUtil.unauthorized(
        res,
        "Access token has been compromised"
      );
    }

    if (error.message.includes("expired")) {
      return ResponseUtil.unauthorized(res, "Access token has expired");
    }

    if (error.message.includes("corrupted")) {
      return ResponseUtil.unauthorized(res, "Access token is corrupted");
    }

    return ResponseUtil.unauthorized(res, "Failed to validate access token");
  }
};

module.exports = accessTokenValidator;
