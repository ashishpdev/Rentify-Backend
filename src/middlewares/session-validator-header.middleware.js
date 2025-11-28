/**
 * Session Validator Middleware - Header Based
 * 
 * This middleware validates that:
 * 1. Session token is present in x-session-token header
 * 2. Session token is valid and not expired
 * 3. Session exists in database and is active (is_active = 1)
 * 
 * If all checks pass, attaches session data to req object:
 *   - req.sessionToken: The session token from header
 *   - req.sessionData: Session data from database
 * 
 * Usage in routes:
 * router.get('/protected-route', SessionValidatorHeader.validateSession, controllerMethod);
 */

const dbConnection = require("../database/connection");
const ResponseUtil = require("../utils/response.util");
const logger = require("../config/logger.config");

class SessionValidatorHeader {
  /**
   * Middleware function to validate session token from x-session-token header
   * Should be used BEFORE accessing protected routes
   * 
   * @param {Object} req - Express request object
   * @param {Object} res - Express response object
   * @param {Function} next - Express next function
   * @returns {void}
   */
  static async validateSession(req, res, next) {
    try {
      // Extract session token from x-session-token header
      const sessionToken = req.headers["x-session-token"];

      // Check if session token is present
      if (!sessionToken) {
        logger.warn("Missing x-session-token header", {
          ip: req.ip,
          path: req.path,
          method: req.method,
        });
        return ResponseUtil.unauthorized(
          res,
          "Session token is required. Please provide x-session-token header."
        );
      }

      // Validate token is a non-empty string
      if (typeof sessionToken !== "string" || sessionToken.trim() === "") {
        logger.warn("Invalid x-session-token header format", {
          ip: req.ip,
          path: req.path,
          tokenType: typeof sessionToken,
        });
        return ResponseUtil.badRequest(
          res,
          "Session token must be a valid non-empty string"
        );
      }

      // Get session data from database
      const sessionData = await this._getSessionFromDB(sessionToken);

      // Check if session exists
      if (!sessionData) {
        logger.warn("Session not found in database", {
          ip: req.ip,
          path: req.path,
          sessionToken: sessionToken.substring(0, 20) + "...",
        });
        return ResponseUtil.unauthorized(
          res,
          "Session not found or invalid. Please login again."
        );
      }

      // Check if session is active
      if (!sessionData.is_active) {
        logger.warn("Inactive session token used", {
          ip: req.ip,
          path: req.path,
          userId: sessionData.user_id,
          sessionId: sessionData.id,
        });
        return ResponseUtil.unauthorized(
          res,
          "Session is no longer active. Please login again."
        );
      }

      // Check if session is expired
      if (sessionData.expiry_at) {
        const now = new Date();
        const expiryTime = new Date(sessionData.expiry_at);

        if (expiryTime < now) {
          logger.warn("Expired session token used", {
            ip: req.ip,
            path: req.path,
            userId: sessionData.user_id,
            expiryAt: sessionData.expiry_at,
          });
          return ResponseUtil.unauthorized(
            res,
            "Session has expired. Please login again."
          );
        }
      }

      // Attach session data to request for downstream middlewares and handlers
      req.sessionToken = sessionToken;
      req.sessionData = {
        id: sessionData.id,
        user_id: sessionData.user_id,
        device_id: sessionData.device_id,
        device_name: sessionData.device_name,
        ip_address: sessionData.ip_address,
        user_agent: sessionData.user_agent,
        created_at: sessionData.created_at,
        expiry_at: sessionData.expiry_at,
        updated_at: sessionData.updated_at,
        last_active: sessionData.last_active,
        is_active: sessionData.is_active,
      };

      logger.debug("Session validated successfully", {
        userId: sessionData.user_id,
        sessionId: sessionData.id,
        path: req.path,
      });

      // Session is valid, proceed to next middleware/handler
      next();
    } catch (err) {
      logger.error("Session validation error", {
        error: err.message,
        ip: req.ip,
        path: req.path,
        stack: err.stack,
      });
      return ResponseUtil.unauthorized(
        res,
        "Failed to validate session. Please try again."
      );
    }
  }

  /**
   * Get session data from master_user_session table
   * Queries the database for the session record matching the provided token
   * 
   * @param {string} sessionToken - The session token to look up
   * @returns {Object|null} - Session data object or null if not found
   * @throws {Error} - If database query fails
   */
  static async _getSessionFromDB(sessionToken) {
    let connection;
    try {
      const pool = dbConnection.getMasterPool();
      connection = await pool.getConnection();

      // Query to get active session data from master_user_session table
      const [rows] = await connection.query(
        `SELECT 
          id,
          user_id,
          device_id,
          device_name,
          ip_address,
          user_agent,
          session_token,
          created_at,
          expiry_at,
          updated_at,
          last_active,
          is_active
         FROM master_user_session
         WHERE session_token = ?
         LIMIT 1`,
        [sessionToken]
      );

      if (rows && rows.length > 0) {
        return rows[0];
      }

      return null;
    } catch (err) {
      logger.error("Database error in session validation", {
        error: err.message,
        stack: err.stack,
      });
      throw new Error(
        `Failed to validate session from database: ${err.message}`
      );
    } finally {
      if (connection) {
        connection.release();
      }
    }
  }

  /**
   * Invalidate/logout a session by marking it inactive
   * Call this when user logs out or session needs to be terminated
   * 
   * @param {string} sessionToken - The session token to invalidate
   * @returns {boolean} - True if session was invalidated successfully
   * @throws {Error} - If database update fails
   */
  static async invalidateSession(sessionToken) {
    let connection;
    try {
      const pool = dbConnection.getMasterPool();
      connection = await pool.getConnection();

      // Update session to set is_active = 0
      const [result] = await connection.query(
        `UPDATE master_user_session 
         SET is_active = 0, updated_at = NOW() 
         WHERE session_token = ?`,
        [sessionToken]
      );

      if (result.affectedRows > 0) {
        logger.info("Session invalidated successfully", {
          sessionToken: sessionToken.substring(0, 20) + "...",
          affectedRows: result.affectedRows,
        });
        return true;
      }

      logger.warn("Session invalidation - no matching session found", {
        sessionToken: sessionToken.substring(0, 20) + "...",
      });
      return false;
    } catch (err) {
      logger.error("Failed to invalidate session", {
        error: err.message,
        sessionToken: sessionToken.substring(0, 20) + "...",
        stack: err.stack,
      });
      throw new Error(`Failed to invalidate session: ${err.message}`);
    } finally {
      if (connection) {
        connection.release();
      }
    }
  }

  /**
   * Update session last_active timestamp
   * Call this to track when the session was last used
   * 
   * @param {string} sessionToken - The session token to update
   * @returns {boolean} - True if session was updated successfully
   */
  static async updateSessionActivity(sessionToken) {
    let connection;
    try {
      const pool = dbConnection.getMasterPool();
      connection = await pool.getConnection();

      // Update session's last_active timestamp
      const [result] = await connection.query(
        `UPDATE master_user_session 
         SET last_active = NOW() 
         WHERE session_token = ?`,
        [sessionToken]
      );

      return result.affectedRows > 0;
    } catch (err) {
      logger.error("Failed to update session activity", {
        error: err.message,
        sessionToken: sessionToken.substring(0, 20) + "...",
      });
      // Don't throw - this is not critical for request processing
      return false;
    } finally {
      if (connection) {
        connection.release();
      }
    }
  }
}

module.exports = SessionValidatorHeader;
