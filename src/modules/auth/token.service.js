/**
 * Token Management Service
 * Handles token validation and extraction
 * Centralizes token-related business logic
 */

const TokenUtil = require("../../utils/token.util");
const {
  AuthenticationError,
  ValidationError,
} = require("../../utils/errors.util");
const { TOKEN_HEADERS } = require("../../constants/operations");

class TokenService {
  /**
   * Extract and validate access token from headers
   * @param {Object} headers - Request headers
   * @returns {string} - Access token
   * @throws {ValidationError} - If token not provided
   */
  extractAccessToken(headers) {
    const token = headers[TOKEN_HEADERS.ACCESS];

    if (!token) {
      throw new ValidationError("Access token is required. Please provide x-access-token header.");
    }

    return token;
  }

  /**
   * Extract and validate session token from headers
   * @param {Object} headers - Request headers
   * @returns {string} - Session token
   * @throws {ValidationError} - If token not provided
   */
  extractSessionToken(headers) {
    const token = headers[TOKEN_HEADERS.SESSION];

    if (!token) {
      throw new ValidationError("Session token is required. Please provide x-session-token header.");
    }

    return token;
  }

  /**
   * Validate and decrypt access token
   * @param {string} accessToken - Access token to validate
   * @returns {Object} - Decrypted user data
   * @throws {AuthenticationError} - If token is invalid/tampered/expired
   */
  validateAndDecryptAccessToken(accessToken) {
    // Validate token structure
    if (!TokenUtil.isValidTokenStructure(accessToken)) {
      throw new AuthenticationError("Invalid access token format");
    }

    // Decrypt the token to get user data
    try {
      const userData = TokenUtil.decryptAccessToken(accessToken);

      if (!userData || !userData.user_id) {
        throw new AuthenticationError("Invalid access token");
      }

      return userData;
    } catch (error) {
      // Handle specific token errors
      if (error.message && error.message.includes("tampered")) {
        throw new AuthenticationError("Access token has been compromised");
      }

      if (error.message && error.message.includes("expired")) {
        throw new AuthenticationError("Access token has expired");
      }

      throw error;
    }
  }

  /**
   * Extract both tokens and validate them
   * @param {Object} headers - Request headers
   * @returns {Object} - { accessToken, sessionToken, userData }
   */
  extractAndValidateTokens(headers) {
    const accessToken = this.extractAccessToken(headers);
    const sessionToken = this.extractSessionToken(headers);
    const userData = this.validateAndDecryptAccessToken(accessToken);

    return {
      accessToken,
      sessionToken,
      userData,
      userId: userData.user_id,
    };
  }

  /**
   * Extract and validate access token only
   * @param {Object} headers - Request headers
   * @returns {Object} - { accessToken, userData, userId }
   */
  extractAndValidateAccessToken(headers) {
    const accessToken = this.extractAccessToken(headers);
    const userData = this.validateAndDecryptAccessToken(accessToken);

    return {
      accessToken,
      userData,
      userId: userData.user_id,
    };
  }
}

module.exports = new TokenService();
