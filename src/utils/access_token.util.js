// src/utils/access_token.util.js
const jwt = require("jsonwebtoken");

const DEFAULT_EXPIRES_MIN = parseInt(
  process.env.ACCESS_TOKEN_EXPIRES_MIN || "15",
  10
);
const SIGNING_KEY =
  process.env.TOKEN_SIGNING_KEY ||
  "dev-insecure-token-signing-key-do-not-use-in-prod";

class AccessTokenUtil {
  static generateAccessToken(userData) {
    try {
      const requiredFields = [
        "user_id",
        "business_id",
        "branch_id",
        "role_id",
        "email",
        "contact_number",
        "user_name",
        "business_name",
        "branch_name",
        "role_name",
        "is_owner",
      ];
      for (const field of requiredFields) {
        if (userData[field] === undefined || userData[field] === null) {
          throw new Error(`Missing required field: ${field}`);
        }
      }

      // Add token type marker to payload
      const payload = {
        ...userData,
        type: "access_token",
      };

      const expiresIn = `${DEFAULT_EXPIRES_MIN}m`;
      const token = jwt.sign(payload, SIGNING_KEY, {
        expiresIn,
      });

      const expiresAt = new Date(Date.now() + DEFAULT_EXPIRES_MIN * 60 * 1000);

      return {
        accessToken: token,
        expiresAt,
        expiresIn: Math.floor(expiresAt.getTime() / 1000),
      };
    } catch (err) {
      throw new Error(`Failed to generate access token: ${err.message}`);
    }
  }

  static decryptAccessToken(token) {
    try {
      if (!token || typeof token !== "string") {
        throw new Error("Invalid token format");
      }

      const payload = jwt.verify(token, SIGNING_KEY);

      if (payload.type !== "access_token") {
        throw new Error("Invalid token type");
      }

      // Remove metadata we don't want as part of user object
      const { iat, exp, nbf, jti, type, ...userData } = payload;

      // minimal sanity check
      if (!userData.user_id) {
        throw new Error("Invalid access token payload");
      }

      return userData;
    } catch (err) {
      // Normalize error messages similar to previous behaviour
      if (err.name === "TokenExpiredError") {
        throw new Error("Access token expired");
      }
      if (err.name === "JsonWebTokenError") {
        throw new Error("Access token has been tampered with");
      }
      throw new Error(err.message || "Failed to verify access token");
    }
  }

  static isValidTokenStructure(token) {
    try {
      if (!token || typeof token !== "string") return false;
      // JWT should contain two dots
      const parts = token.split(".");
      return parts.length === 3 && parts[0].length > 0;
    } catch (err) {
      return false;
    }
  }
}

module.exports = AccessTokenUtil;
