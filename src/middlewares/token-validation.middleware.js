const logger = require("../config/logger.config");
const ResponseUtil = require("../utils/response.util");
const AccessTokenUtil = require("../utils/access_token.util");
const dbConnection = require("../database/connection");
const { SESSION_OPERATIONS } = require("../constants/operations");

function createTokenValidationMiddleware(
  requireAccess = true,
  requireSession = false
) { 
  return async (req, res, next) => {
    try {
      // =================== VALIDATE BOTH TOKENS ===================
      if (requireAccess && requireSession) {
        const sessionToken = req.headers["x-session-token"]?.trim();
        const accessToken = req.headers["x-access-token"]?.trim();

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

        // First, validate access token to get user_id
        if (!AccessTokenUtil.isValidTokenStructure(accessToken)) {
          return ResponseUtil.unauthorized(res, "Invalid access token format");
        }

        const userData = AccessTokenUtil.decryptAccessToken(accessToken);
        if (!userData || !userData.user_id) {
          return ResponseUtil.unauthorized(res, "Invalid access token");
        }

        // Now validate session with user_id from access token
        const sessionData = await getSessionFromDB(
          sessionToken,
          userData.user_id
        );
        if (!sessionData || !sessionData.is_active) {
          return ResponseUtil.unauthorized(res, "Invalid or inactive session");
        }

        // Session is already validated by SP (expiry_at > UTC_TIMESTAMP())
        // No need for redundant expiry check here as SP already filters expired sessions

        req.sessionToken = sessionToken;
        req.sessionData = sessionData;
        req.accessToken = accessToken;
        req.user = userData;
      }
      // =================== VALIDATE ACCESS TOKEN ===================
      else if (requireAccess) {
        const accessToken = req.headers["x-access-token"]?.trim();

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
      }
      // =================== VALIDATE SESSION TOKEN ===================
      else if (requireSession) {
        const sessionToken = req.headers["x-session-token"]?.trim();

        if (!sessionToken) {
          return ResponseUtil.badRequest(
            res,
            "x-session-token header is required"
          );
        }

        // Validate session token (UUID) from database
        const sessionData = await getSessionFromDB(sessionToken, userId);
        if (!sessionData) {
          return ResponseUtil.unauthorized(res, "Invalid or expired session");
        }

        // Session is already validated by SP (expiry_at > UTC_TIMESTAMP())
        // No need for redundant expiry check here as SP already filters expired sessions

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

async function getSessionFromDB(sessionToken, userId = null) {
  let connection;
  try {
    const pool = dbConnection.getMasterPool();
    connection = await pool.getConnection();

    // Use sp_manage_session with action=4 (Get session)
    await connection.query(
      `CALL sp_manage_session(?, ?, ?, NULL, NULL, @p_is_success, @p_session_token_out, @p_expiry_at, @p_error_message)`,
      [SESSION_OPERATIONS.GET, userId, sessionToken]
    );

    // Get output parameters
    const [outputRows] = await connection.query(
      "SELECT @p_is_success as is_success, @p_session_token_out as session_token, @p_expiry_at as expiry_at, @p_error_message as error_message"
    );

    if (!outputRows || outputRows.length === 0) {
      logger.debug(
        "Session validation failed: No output from stored procedure",
        {
          sessionToken: sessionToken?.substring(0, 8) + "...",
        }
      );
      return null;
    }

    const output = outputRows[0];

    if (!output.is_success || !output.session_token) {
      logger.debug("Session validation failed", {
        sessionToken: sessionToken?.substring(0, 8) + "...",
        errorMessage: output.error_message,
      });
      return null;
    }

    // Return session data structure compatible with middleware expectations
    return {
      session_token: output.session_token, // UUID
      expiry_at: output.expiry_at,
      user_id: userId, // May be null if not provided
      is_active: true, // If SP returns success, session is valid and active
    };
  } catch (error) {
    logger.error("Database error during session validation", {
      error: error.message,
      sessionToken: sessionToken?.substring(0, 8) + "...",
    });
    return null;
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
