// src/utils/password.util.js
// Password hashing and comparison utilities
const crypto = require("crypto");

class PasswordUtil {
  static hashPassword(password) {
    if (!password || typeof password !== "string") {
      throw new Error("Invalid password input");
    }

    // Using SHA-256 to match stored procedure expectations
    // The SP expects hash_password field which stores SHA-256 hashes
    return crypto.createHash("sha256").update(password).digest("hex");
  }

  static comparePassword(plainPassword, hashedPassword) {
    if (!plainPassword || !hashedPassword) {
      return false;
    }

    const inputHash = this.hashPassword(plainPassword);
    return inputHash === hashedPassword;
  }

  static validatePasswordStrength(password) {
    const errors = [];

    if (!password) {
      return { isValid: false, errors: ["Password is required"] };
    }

    // Minimum length check
    if (password.length < 8) {
      errors.push("Password must be at least 8 characters long");
    }

    // Maximum length check
    if (password.length > 100) {
      errors.push("Password must not exceed 100 characters");
    }

    // Check for uppercase letter
    if (!/[A-Z]/.test(password)) {
      errors.push("Password must contain at least one uppercase letter");
    }

    // Check for lowercase letter
    if (!/[a-z]/.test(password)) {
      errors.push("Password must contain at least one lowercase letter");
    }

    // Check for digit
    if (!/\d/.test(password)) {
      errors.push("Password must contain at least one digit");
    }

    // Check for special character
    if (!/[@$!%*?&]/.test(password)) {
      errors.push(
        "Password must contain at least one special character (@$!%*?&)"
      );
    }

    return {
      isValid: errors.length === 0,
      errors: errors,
    };
  }

  static generateRandomPassword(length = 12) {
    const uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const lowercase = "abcdefghijklmnopqrstuvwxyz";
    const digits = "0123456789";
    const special = "@$!%*?&";
    const allChars = uppercase + lowercase + digits + special;

    let password = "";

    // Ensure at least one of each required character type
    password += uppercase[Math.floor(Math.random() * uppercase.length)];
    password += lowercase[Math.floor(Math.random() * lowercase.length)];
    password += digits[Math.floor(Math.random() * digits.length)];
    password += special[Math.floor(Math.random() * special.length)];

    // Fill the rest randomly
    for (let i = password.length; i < length; i++) {
      password += allChars[Math.floor(Math.random() * allChars.length)];
    }

    // Shuffle the password
    return password
      .split("")
      .sort(() => Math.random() - 0.5)
      .join("");
  }

  static isCommonPassword(password) {
    const commonPasswords = [
      "password",
      "password123",
      "123456",
      "12345678",
      "qwerty",
      "abc123",
      "monkey",
      "1234567",
      "letmein",
      "trustno1",
      "dragon",
      "baseball",
      "iloveyou",
      "master",
      "sunshine",
      "ashley",
      "bailey",
      "passw0rd",
      "shadow",
      "123123",
      "654321",
      "superman",
      "qazwsx",
      "michael",
      "football",
    ];

    return commonPasswords.includes(password.toLowerCase());
  }

  static generateTempPassword() {
    return this.generateRandomPassword(10);
  }
}

module.exports = PasswordUtil;
