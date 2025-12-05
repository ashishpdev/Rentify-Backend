// Session Token utility for managing encrypted session tokens
const crypto = require("crypto");

const ENCRYPTION_ALGORITHM = "aes-256-gcm";
const ENCODING = "utf8";

// Session configuration
const SESSION_CONFIG = {
  DEFAULT_EXPIRY_HOURS: 1, // 1 hour session expiry
  EXTENDED_EXPIRY_HOURS: 1, // Extended by 1 hour on refresh
};

class SessionTokenUtil {
  // Get encryption key from environment variable
  static getEncryptionKey() {
    const keyString = process.env.SESSION_ENCRYPTION_KEY;

    if (!keyString) {
      // In production, fail fast if key is not set
      if (process.env.NODE_ENV === "production") {
        throw new Error(
          "CRITICAL: SESSION_ENCRYPTION_KEY environment variable is required in production. " +
            "Set a strong, random key of at least 32 characters."
        );
      }
      // In development, warn and use fallback (never in production!)
      console.warn(
        "⚠️  WARNING: SESSION_ENCRYPTION_KEY not set. Using insecure default key. " +
          "This is acceptable only for local development."
      );
    }

    // Ensure key is exactly 32 bytes (256 bits) for AES-256
    const hash = crypto
      .createHash("sha256")
      .update(keyString || "dev-only-insecure-session-key-do-not-use-in-prod")
      .digest();
    return hash;
  }

  // =================== GENERATE SESSION TOKEN ===================
  static generateSessionToken(sessionData) {
    try {
      // Validate required fields
      const requiredFields = ["user_id"];
      for (const field of requiredFields) {
        if (sessionData[field] === undefined || sessionData[field] === null) {
          throw new Error(`Missing required field: ${field}`);
        }
      }

      // Create a copy to avoid mutating original
      const dataToEncrypt = { ...sessionData };

      // Get current UTC timestamp in milliseconds for precision
      const nowMs = Date.now();
      const nowSeconds = Math.floor(nowMs / 1000);

      // Add metadata to token (all times in UTC)
      dataToEncrypt.iat = nowSeconds; // issued at (UTC seconds)
      dataToEncrypt.exp =
        nowSeconds + SESSION_CONFIG.DEFAULT_EXPIRY_HOURS * 60 * 60; // expires in 1 hour (UTC)
      dataToEncrypt.created_at = new Date(nowMs).toISOString(); // ISO string for readability
      dataToEncrypt.expiry_at = new Date(
        dataToEncrypt.exp * 1000
      ).toISOString();
      dataToEncrypt.session_life = SESSION_CONFIG.DEFAULT_EXPIRY_HOURS * 60; // in minutes
      dataToEncrypt.type = "session_token"; // token type identifier

      // Serialize data to JSON
      const jsonData = JSON.stringify(dataToEncrypt);

      // Generate random IV (initialization vector)
      const iv = crypto.randomBytes(16);

      // Encrypt the data
      const cipher = crypto.createCipheriv(
        ENCRYPTION_ALGORITHM,
        this.getEncryptionKey(),
        iv
      );
      let encrypted = cipher.update(jsonData, ENCODING, "hex");
      encrypted += cipher.final("hex");

      // Get the authentication tag (for integrity verification)
      const authTag = cipher.getAuthTag();

      // Combine IV + authTag + encrypted data and encode to base64
      const token = Buffer.concat([
        iv,
        authTag,
        Buffer.from(encrypted, "hex"),
      ]).toString("base64");

      return {
        sessionToken: token,
        expiresAt: new Date(dataToEncrypt.exp * 1000),
        expiresIn: dataToEncrypt.exp, // Unix timestamp (UTC)
        createdAt: new Date(nowMs),
      };
    } catch (err) {
      throw new Error(`Failed to generate session token: ${err.message}`);
    }
  }

  // =================== GENERATE EXTENDED SESSION TOKEN ===================
  static generateExtendedSessionToken(existingSessionData) {
    try {
      // Create new session token with extended expiry
      const nowMs = Date.now();
      const nowSeconds = Math.floor(nowMs / 1000);

      const dataToEncrypt = {
        user_id: existingSessionData.user_id,
        business_id: existingSessionData.business_id,
        branch_id: existingSessionData.branch_id,
        role_id: existingSessionData.role_id,
        is_owner: existingSessionData.is_owner,
        user_name: existingSessionData.user_name,
        contact_number: existingSessionData.contact_number,
        business_name: existingSessionData.business_name,
        device_id: existingSessionData.device_id,
        ip_address: existingSessionData.ip_address,
        iat: nowSeconds,
        exp: nowSeconds + SESSION_CONFIG.EXTENDED_EXPIRY_HOURS * 60 * 60,
        created_at: new Date(nowMs).toISOString(),
        expiry_at: new Date(
          (nowSeconds + SESSION_CONFIG.EXTENDED_EXPIRY_HOURS * 60 * 60) * 1000
        ).toISOString(),
        session_life: SESSION_CONFIG.EXTENDED_EXPIRY_HOURS * 60,
        type: "session_token",
      };

      // Serialize data to JSON
      const jsonData = JSON.stringify(dataToEncrypt);

      // Generate random IV
      const iv = crypto.randomBytes(16);

      // Encrypt the data
      const cipher = crypto.createCipheriv(
        ENCRYPTION_ALGORITHM,
        this.getEncryptionKey(),
        iv
      );
      let encrypted = cipher.update(jsonData, ENCODING, "hex");
      encrypted += cipher.final("hex");

      const authTag = cipher.getAuthTag();

      const token = Buffer.concat([
        iv,
        authTag,
        Buffer.from(encrypted, "hex"),
      ]).toString("base64");

      return {
        sessionToken: token,
        expiresAt: new Date(dataToEncrypt.exp * 1000),
        expiresIn: dataToEncrypt.exp,
        createdAt: new Date(nowMs),
      };
    } catch (err) {
      throw new Error(`Failed to extend session token: ${err.message}`);
    }
  }

  // =================== DECRYPT SESSION TOKEN ===================
  static decryptSessionToken(token) {
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
      const decipher = crypto.createDecipheriv(
        ENCRYPTION_ALGORITHM,
        this.getEncryptionKey(),
        iv
      );

      // Set the auth tag for verification
      decipher.setAuthTag(authTag);

      // Decrypt
      let decrypted = decipher.update(encrypted, "hex", ENCODING);
      decrypted += decipher.final(ENCODING);

      // Parse JSON
      const sessionData = JSON.parse(decrypted);

      // Validate token type
      if (sessionData.type !== "session_token") {
        throw new Error("Invalid token type");
      }

      // Check expiration using UTC timestamp
      const nowUtcSeconds = Math.floor(Date.now() / 1000);
      if (sessionData.exp && sessionData.exp < nowUtcSeconds) {
        throw new Error("Session token expired");
      }

      return sessionData;
    } catch (err) {
      // Check for GCM authentication failure (tampered token)
      if (
        err.code === "ERR_OSSL_EVP_BAD_DECRYPT" ||
        err.message.includes(
          "Unsupported state or unable to authenticate data"
        ) ||
        err.message.includes("bad decrypt")
      ) {
        throw new Error("Session token has been tampered with");
      }
      if (err instanceof SyntaxError) {
        throw new Error("Session token is corrupted");
      }
      throw err;
    }
  }

  // =================== VALIDATE TOKEN WITHOUT FULL DECRYPT ===================
  static validateSessionToken(token) {
    try {
      const sessionData = this.decryptSessionToken(token);
      return {
        isValid: true,
        sessionData,
        error: null,
      };
    } catch (err) {
      return {
        isValid: false,
        sessionData: null,
        error: err.message,
      };
    }
  }

  // =================== VALIDATE TOKEN STRUCTURE ===================
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

  // =================== CHECK IF TOKEN IS EXPIRED ===================
  static isTokenExpired(token) {
    try {
      const sessionData = this.decryptSessionToken(token);
      const nowUtcSeconds = Math.floor(Date.now() / 1000);
      return sessionData.exp < nowUtcSeconds;
    } catch (err) {
      // If we can't decrypt, consider it expired/invalid
      return true;
    }
  }

  // =================== GET REMAINING SESSION TIME ===================
  static getRemainingTime(token) {
    try {
      const sessionData = this.decryptSessionToken(token);
      const nowUtcSeconds = Math.floor(Date.now() / 1000);
      const remainingSeconds = sessionData.exp - nowUtcSeconds;
      return remainingSeconds > 0 ? remainingSeconds : 0;
    } catch (err) {
      return 0;
    }
  }
}

module.exports = SessionTokenUtil;
