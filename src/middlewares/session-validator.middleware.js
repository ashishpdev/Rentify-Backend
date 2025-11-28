const dbConnection = require("../database/connection");
const ResponseUtil = require("../utils/response.util");
const logger = require("../config/logger.config");

const sessionValidator = async (req, res, next) => {
  try {
    const token = req.headers["x-session-token"];

    if (!token) {
      return ResponseUtil.badRequest(res, "x-session-token header is required");
    }

    const sessionData = await getSessionFromDB(token);

    if (!sessionData) {
      return ResponseUtil.unauthorized(res, "Invalid session token");
    }

    if (!sessionData.is_active) {
      return ResponseUtil.unauthorized(res, "Session is no longer active");
    }

    const now = new Date();
    if (sessionData.expiry_at && new Date(sessionData.expiry_at) < now) {
      return ResponseUtil.unauthorized(res, "Session has expired");
    }

    req.sessionToken = token;
    req.sessionData = {
      id: sessionData.id,
      user_id: sessionData.user_id,
      device_id: sessionData.device_id,
      device_name: sessionData.device_name,
      ip_address: sessionData.ip_address,
      user_agent: sessionData.user_agent,
      created_at: sessionData.created_at,
      expiry_at: sessionData.expiry_at,
      is_active: sessionData.is_active,
    };

    next();
  } catch (error) {
    logger.error("Session validation error", { error: error.message });
    return ResponseUtil.serverError(res, "Session validation failed");
  }
};

async function getSessionFromDB(sessionToken) {
  let connection;
  try {
    const pool = dbConnection.getMasterPool();
    connection = await pool.getConnection();

    const [rows] = await connection.query(
      `SELECT id, user_id, device_id, device_name, ip_address, user_agent, is_active, created_at, expiry_at 
       FROM master_user_session 
       WHERE session_token = ? AND is_active = 1 LIMIT 1`,
      [sessionToken]
    );

    return rows && rows.length > 0 ? rows[0] : null;
  } finally {
    if (connection) connection.release();
  }
}

async function invalidateSession(sessionToken) {
  let connection;
  try {
    const pool = dbConnection.getMasterPool();
    connection = await pool.getConnection();

    await connection.query(
      `UPDATE master_user_session SET is_active = 0, updated_at = NOW() WHERE session_token = ?`,
      [sessionToken]
    );
  } finally {
    if (connection) connection.release();
  }
}

module.exports = sessionValidator;
module.exports.invalidateSession = invalidateSession;
