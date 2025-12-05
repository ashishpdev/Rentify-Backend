/**
 * Session Management Operation Codes
 */
const SESSION_OPERATIONS = {
  CREATE : 1, // Create new session
  UPDATE: 2, // Extend session expiry
  DELETE: 3, // Logout (delete session)
  GET  : 4, // Get session details
};

/**
 * OTP Type IDs
 */
const OTP_TYPES = {
  LOGIN: 1,
  REGISTER: 2,
  RESET_PASSWORD: 3,
  VERIFY_EMAIL: 4,
  VERIFY_PHONE: 5,
};

/**
 * Token Cookie Names
 */
const TOKEN_COOKIES = {
  SESSION: "session_token",
  ACCESS: "access_token",
};

/**
 * Response Messages
 */
const RESPONSE_MESSAGES = {
  SESSION_EXTENDED: "Session extended successfully",
  LOGOUT_SUCCESS: "Logged out successfully",
  SESSION_TOKEN_REQUIRED: "Session token is required. Please ensure session_token cookie is set.",
  ACCESS_TOKEN_REQUIRED: "Access token is required. Please ensure access_token cookie is set.",
  INVALID_TOKEN_FORMAT: "Invalid access token format",
  INVALID_TOKEN: "Invalid access token",
  TOKEN_COMPROMISED: "Access token has been compromised",
  TOKEN_EXPIRED: "Access token has expired",
  SESSION_TOKEN_EXPIRED: "Session token has expired",
  SESSION_TOKEN_COMPROMISED: "Session token has been compromised",
  INVALID_SESSION_TOKEN: "Invalid session token",
  EXTEND_SESSION_FAILED: "Failed to extend session",
  LOGOUT_FAILED: "Failed to logout",
};

/**
 * Error Messages
 */
const ERROR_MESSAGES = {
  TAMPERED_TOKEN: "tampered",
  EXPIRED_TOKEN: "expired",
  INVALID_SESSION: "Invalid or expired session",
};

module.exports = {
  SESSION_OPERATIONS,
  OTP_TYPES,
  TOKEN_COOKIES,
  RESPONSE_MESSAGES,
  ERROR_MESSAGES,
};
