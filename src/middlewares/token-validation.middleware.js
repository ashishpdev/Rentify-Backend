const logger = require("../config/logger.config");
const ResponseUtil = require("../utils/response.util");
const AccessTokenUtil = require("../utils/access_token.util");
const dbConnection = require("../database/connection");

function createTokenValidationMiddleware(
  requireAccess = true,
  requireSession = false
) {
  return async (req, res, next) => {
    try {
      if (requireAccess && requireSession) {
        const sessionToken = req.headers["x-session-token"];
        const accessToken = req.headers["x-access-token"];

        if (!sessionToken) {
          return ResponseUtil.badRequest(
            res,
            "x-session-token header is required"
          );
        }
        if (!accessToken) {
          return ResponseUtil.badRequest(
            res,
            "x-access-token header is required"
          );
        }

        const sessionData = await getSessionFromDB(sessionToken);
        if (!sessionData || !sessionData.is_active) {
          return ResponseUtil.unauthorized(res, "Invalid or inactive session");
        }

        if (
          sessionData.expiry_at &&
          new Date(sessionData.expiry_at) < new Date()
        ) {
          return ResponseUtil.unauthorized(res, "Session has expired");
        }

        if (!AccessTokenUtil.isValidTokenStructure(accessToken)) {
          return ResponseUtil.unauthorized(res, "Invalid access token format");
        }

        const userData = AccessTokenUtil.decryptAccessToken(accessToken);
        if (!userData || !userData.user_id) {
          return ResponseUtil.unauthorized(res, "Invalid access token");
        }

        if (userData.user_id !== sessionData.user_id) {
          return ResponseUtil.unauthorized(
            res,
            "Access token does not match session"
          );
        }

        req.sessionToken = sessionToken;
        req.sessionData = sessionData;
        req.accessToken = accessToken;
        req.user = userData;
      } else if (requireAccess) {
        const accessToken = req.headers["x-access-token"];

        if (!accessToken) {
          return ResponseUtil.badRequest(
            res,
            "x-access-token header is required"
          );
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
      } else if (requireSession) {
        const sessionToken = req.headers["x-session-token"];

        if (!sessionToken) {
          return ResponseUtil.badRequest(
            res,
            "x-session-token header is required"
          );
        }

        const sessionData = await getSessionFromDB(sessionToken);
        if (!sessionData || !sessionData.is_active) {
          return ResponseUtil.unauthorized(res, "Invalid or inactive session");
        }

        if (
          sessionData.expiry_at &&
          new Date(sessionData.expiry_at) < new Date()
        ) {
          return ResponseUtil.unauthorized(res, "Session has expired");
        }

        req.sessionToken = sessionToken;
        req.sessionData = sessionData;
      }

      next();
    } catch (error) {
      logger.error("Token validation error", { error: error.message });

      if (error.message.includes("tampered")) {
        return ResponseUtil.unauthorized(
          res,
          "Access token has been compromised"
        );
      }

      return ResponseUtil.unauthorized(res, "Token validation failed");
    }
  };
}

async function getSessionFromDB(sessionToken) {
  let connection;
  try {
    const pool = dbConnection.getMasterPool();
    connection = await pool.getConnection();

    const [rows] = await connection.query(
      `SELECT id, user_id, device_id, device_name, ip_address, user_agent, is_active, created_at, expiry_at 
       FROM master_user_session 
       WHERE session_token = ? LIMIT 1`,
      [sessionToken]
    );

    return rows && rows.length > 0 ? rows[0] : null;
  } finally {
    if (connection) connection.release();
  }
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
