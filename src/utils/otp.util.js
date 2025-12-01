/**
 * OTP Utility Functions
 * Centralized OTP generation and hashing logic
 * Ensures consistent hash generation across the application
 */

const crypto = require("crypto");

class OTPUtil {
  /**
   * Generate a random 6-digit OTP code
   * @returns {string} 6-digit OTP code
   */
  static generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  /**
   * Hash OTP code using SHA256
   * IMPORTANT: This is the ONLY method to be used for OTP hashing
   * Ensures consistency between storage and verification
   *
   * @param {string} otpCode - The plain text OTP code (6 digits)
   * @returns {string} SHA256 hash of the OTP code
   */
  static hashOTP(otpCode) {
    if (!otpCode) {
      throw new Error("OTP code is required for hashing");
    }

    // Ensure OTP is a string
    const codeString = String(otpCode).trim();

    // Optional: Validate OTP format (6 digits)
    if (!/^\d{6}$/.test(codeString)) {
      throw new Error("OTP must be exactly 6 digits");
    }

    return crypto.createHash("sha256").update(codeString).digest("hex");
  }

  /**
   * Verify OTP by comparing the provided code with stored hash
   * @param {string} providedOTPCode - The OTP code provided by user
   * @param {string} storedHash - The hash stored in database
   * @returns {boolean} true if hashes match, false otherwise
   */
  static verifyOTP(providedOTPCode, storedHash) {
    try {
      const providedHash = this.hashOTP(providedOTPCode);
      return providedHash === storedHash;
    } catch (error) {
      return false;
    }
  }
}

module.exports = OTPUtil;
