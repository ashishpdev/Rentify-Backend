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
 * Token Headers
 */
const TOKEN_HEADERS = {
  SESSION: "x-session-token",
  ACCESS: "x-access-token",
};

/**
 * Response Messages
 */
const RESPONSE_MESSAGES = {
  SESSION_EXTENDED: "Session extended successfully",
  LOGOUT_SUCCESS: "Logged out successfully",
  SESSION_TOKEN_REQUIRED: "Session token is required. Please provide x-session-token header.",
  ACCESS_TOKEN_REQUIRED: "Access token is required. Please provide x-access-token header.",
  INVALID_TOKEN_FORMAT: "Invalid access token format",
  INVALID_TOKEN: "Invalid access token",
  TOKEN_COMPROMISED: "Access token has been compromised",
  TOKEN_EXPIRED: "Access token has expired",
  EXTEND_SESSION_FAILED: "Failed to extend session",
  LOGOUT_FAILED: "Failed to logout",
};

/**
 * Error Messages
 */
const ERROR_MESSAGES = {
  TAMPERED_TOKEN: "tampered",
  EXPIRED_TOKEN: "expired",
};

module.exports = {
  SESSION_OPERATIONS,
  OTP_TYPES,
  TOKEN_HEADERS,
  RESPONSE_MESSAGES,
  ERROR_MESSAGES,
};
