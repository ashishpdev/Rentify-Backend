// Session validator middleware
// Validates that the session_token is still active and user session exists in database
const dbConnection = require("../database/connection");
const ResponseUtil = require("../utils/response.util");
const logger = require("../config/logger.config");

class SessionValidator {
  /**
   * Middleware to validate session token
   * Checks if user session is still active in database
   * Call this middleware BEFORE access-token-validator
   * 
   * Expected header: Authorization: Bearer <session_token>
   * Or can be in cookies: session_token=<token>
   * 
   * Attaches to req: req.sessionToken, req.sessionData
   */
  static async validateSession(req, res, next) {
    try {
      // Extract session token from header or cookies
      const token =
        this._extractFromAuthHeader(req) ||
        this._extractFromCookie(req, "session_token");

      if (!token) {
        logger.warn("Missing session token", {
          ip: req.ip,
          path: req.path,
        });
        return ResponseUtil.unauthorized(res, "Session token is required");
      }

      // Get session data from database using the token
      const sessionData = await this._getSessionFromDB(token);

      if (!sessionData || !sessionData.session_id) {
        logger.warn("Invalid or expired session token", {
          ip: req.ip,
          path: req.path,
        });
        return ResponseUtil.unauthorized(res, "Session expired or invalid");
      }

      // Check if session is still active
      if (!sessionData.is_active) {
        logger.warn("Inactive session token used", {
          sessionId: sessionData.session_id,
          userId: sessionData.user_id,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, "Session is no longer active");
      }

      // Check session expiration
      const now = new Date();
      if (sessionData.expires_at && new Date(sessionData.expires_at) < now) {
        logger.warn("Expired session token used", {
          sessionId: sessionData.session_id,
          userId: sessionData.user_id,
          expiresAt: sessionData.expires_at,
          ip: req.ip,
        });
        return ResponseUtil.unauthorized(res, "Session has expired");
      }

      // Attach session data to request for downstream middlewares
      req.sessionToken = token;
      req.sessionData = {
        session_id: sessionData.session_id,
        user_id: sessionData.user_id,
        business_id: sessionData.business_id,
        branch_id: sessionData.branch_id,
        created_at: sessionData.created_at,
        expires_at: sessionData.expires_at,
        is_active: sessionData.is_active,
      };

      logger.debug("Session validated successfully", {
        sessionId: sessionData.session_id,
        userId: sessionData.user_id,
      });

      next();
    } catch (err) {
      logger.error("Session validation error", {
        error: err.message,
        ip: req.ip,
      });
      return ResponseUtil.unauthorized(res, "Failed to validate session");
    }
  }

  /**
   * Extract session token from Authorization header
   * Expected format: "Bearer <token>" or "Token <token>"
   */
  static _extractFromAuthHeader(req) {
    const authHeader = req.headers.authorization || req.headers.Authorization;

    if (!authHeader) return null;

    const parts = authHeader.split(" ");
    if (parts.length === 2) {
      const scheme = parts[0];
      const credentials = parts[1];

      if (/^Bearer$/i.test(scheme) || /^Token$/i.test(scheme)) {
        return credentials;
      }
    }

    return null;
  }

  /**
   * Extract session token from cookies
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

  /**
   * Query database to get session information
   * Assumes a sessions table with columns:
   * session_id, user_id, business_id, branch_id, session_token, is_active, created_at, expires_at
   */
  static async _getSessionFromDB(sessionToken) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        // Query to get active session data
        const [rows] = await connection.query(
          `SELECT 
            session_id, 
            user_id, 
            business_id, 
            branch_id, 
            is_active, 
            created_at, 
            expires_at 
          FROM sessions 
          WHERE session_token = ? AND is_active = 1 
          LIMIT 1`,
          [sessionToken]
        );

        if (rows && rows.length > 0) {
          return rows[0];
        }

        return null;
      } finally {
        connection.release();
      }
    } catch (err) {
      logger.error("Database error in session validation", {
        error: err.message,
      });
      throw new Error(`Failed to validate session from database: ${err.message}`);
    }
  }

  /**
   * Invalidate/logout a session
   * Call this when user logs out or session needs to be terminated
   */
  static async invalidateSession(sessionToken) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        await connection.query(
          `UPDATE sessions SET is_active = 0, updated_at = NOW() WHERE session_token = ?`,
          [sessionToken]
        );

        logger.info("Session invalidated", {
          sessionToken: sessionToken.substring(0, 20) + "...",
        });

        return true;
      } finally {
        connection.release();
      }
    } catch (err) {
      logger.error("Failed to invalidate session", {
        error: err.message,
      });
      throw err;
    }
  }

  /**
   * Create a new session in database
   * Called during login
   */
  static async createSession(userData, expiresInHours = 24) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        // Generate a unique session token using crypto
        const crypto = require("crypto");
        const sessionToken = crypto.randomBytes(32).toString("hex");

        const expiresAt = new Date(Date.now() + expiresInHours * 60 * 60 * 1000);

        await connection.query(
          `INSERT INTO sessions 
           (user_id, business_id, branch_id, session_token, is_active, created_at, expires_at) 
           VALUES (?, ?, ?, ?, 1, NOW(), ?)`,
          [
            userData.user_id,
            userData.business_id,
            userData.branch_id,
            sessionToken,
            expiresAt,
          ]
        );

        logger.debug("Session created successfully", {
          userId: userData.user_id,
          businessId: userData.business_id,
        });

        return {
          sessionToken,
          expiresAt,
        };
      } finally {
        connection.release();
      }
    } catch (err) {
      logger.error("Failed to create session", {
        error: err.message,
      });
      throw new Error(`Failed to create session: ${err.message}`);
    }
  }
}

module.exports = SessionValidator;
