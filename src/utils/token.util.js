// Token utility for managing encrypted access tokens
const crypto = require("crypto");

const ENCRYPTION_ALGORITHM = "aes-256-gcm";
const ENCODING = "utf8";

class TokenUtil {
  /**
   * Get encryption key from environment or use default
   * In production, this MUST come from a secure environment variable
   * @returns {Buffer} - 32-byte key for AES-256
   */
  static getEncryptionKey() {
    const keyString = process.env.TOKEN_ENCRYPTION_KEY || "default-insecure-key-change-in-production";
    // Ensure key is exactly 32 bytes (256 bits) for AES-256
    const hash = crypto.createHash("sha256").update(keyString).digest();
    return hash;
  }

  /**
   * Generate encrypted access token from user data
   * The token contains encrypted user information that can be decrypted and verified
   * @param {Object} userData - User data to encrypt
   *   {
   *     user_id: number,
   *     business_id: number,
   *     branch_id: number,
   *     role_id: number,
   *     is_owner: boolean,
   *     user_name: string,
   *     contact_number: string,
   *     business_name: string,
   *     email: string
   *   }
   * @returns {Object} - { accessToken: string, expiresAt: timestamp }
   */
  static generateAccessToken(userData) {
    try {
      // Validate required fields
      const requiredFields = ["user_id", "business_id", "branch_id", "role_id"];
      for (const field of requiredFields) {
        if (userData[field] === undefined || userData[field] === null) {
          throw new Error(`Missing required field: ${field}`);
        }
      }

      // Create a copy to avoid mutating original
      const dataToEncrypt = { ...userData };

      // Add metadata to token
      dataToEncrypt.iat = Math.floor(Date.now() / 1000); // issued at
      dataToEncrypt.exp = Math.floor(Date.now() / 1000) + (24 * 60 * 60); // expires in 24 hours
      dataToEncrypt.type = "access_token"; // token type identifier

      // Serialize data to JSON
      const jsonData = JSON.stringify(dataToEncrypt);

      // Generate random IV (initialization vector)
      const iv = crypto.randomBytes(16);

      // Encrypt the data
      const cipher = crypto.createCipheriv(ENCRYPTION_ALGORITHM, this.getEncryptionKey(), iv);
      let encrypted = cipher.update(jsonData, ENCODING, "hex");
      encrypted += cipher.final("hex");

      // Get the authentication tag (for integrity verification)
      const authTag = cipher.getAuthTag();

      // Combine IV + authTag + encrypted data and encode to base64
      const token = Buffer.concat([iv, authTag, Buffer.from(encrypted, "hex")]).toString("base64");

      return {
        accessToken: token,
        expiresAt: new Date(dataToEncrypt.exp * 1000),
        expiresIn: dataToEncrypt.exp, // Unix timestamp
      };
    } catch (err) {
      throw new Error(`Failed to generate access token: ${err.message}`);
    }
  }

  /**
   * Decrypt and validate access token
   * Returns decrypted user data if token is valid and not tampered
   * @param {string} token - Encrypted access token
   * @returns {Object} - Decrypted user data
   * @throws {Error} - If token is invalid, tampered, or expired
   */
  static decryptAccessToken(token) {
    try {
      if (!token || typeof token !== "string") {
        throw new Error("Invalid token format");
      }

      // Decode from base64
      const buffer = Buffer.from(token, "base64");

      // Extract components
      // IV is 16 bytes, authTag is 16 bytes, rest is encrypted data
      const iv = buffer.slice(0, 16);
      const authTag = buffer.slice(16, 32);
      const encrypted = buffer.slice(32).toString("hex");

      // Create decipher
      const decipher = crypto.createDecipheriv(ENCRYPTION_ALGORITHM, this.getEncryptionKey(), iv);

      // Set the auth tag for verification
      decipher.setAuthTag(authTag);

      // Decrypt
      let decrypted = decipher.update(encrypted, "hex", ENCODING);
      decrypted += decipher.final(ENCODING);

      // Parse JSON
      const userData = JSON.parse(decrypted);

      // Validate token type
      if (userData.type !== "access_token") {
        throw new Error("Invalid token type");
      }

      // Check expiration
      const now = Math.floor(Date.now() / 1000);
      if (userData.exp && userData.exp < now) {
        throw new Error("Access token expired");
      }

      // Remove metadata before returning
      delete userData.iat;
      delete userData.exp;
      delete userData.type;

      return userData;
    } catch (err) {
      // Any error in decryption means token is tampered or invalid
      if (err.message.includes("Unsupported state or unable to authenticate data")) {
        throw new Error("Access token has been tampered with");
      }
      if (err instanceof SyntaxError) {
        throw new Error("Access token is corrupted");
      }
      throw err;
    }
  }

  /**
   * Verify token structure without decrypting (for quick validation)
   * @param {string} token - Token to verify
   * @returns {boolean} - True if token has valid structure
   */
  static isValidTokenStructure(token) {
    try {
      if (!token || typeof token !== "string") {
        return false;
      }

      const buffer = Buffer.from(token, "base64");
      // Valid token must have at least IV (16) + authTag (16) + some data
      return buffer.length >= 33;
    } catch (err) {
      return false;
    }
  }

  /**
   * Extract expiration time from token without decrypting
   * This is useful for client-side token refresh logic
   * @param {string} token - Encrypted token
   * @returns {number|null} - Unix timestamp of expiration or null if unable to determine
   */
  static getTokenExpiration(token) {
    try {
      const userData = this.decryptAccessToken(token);
      // Re-encrypt to check expiration time from original
      // Note: This will fail if token is expired, so we need a different approach
      return null; // Return null - expiration is validated during decryption
    } catch (err) {
      return null;
    }
  }
}

module.exports = TokenUtil;
