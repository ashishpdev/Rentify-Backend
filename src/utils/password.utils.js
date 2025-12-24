// src/utils/password.utils.js
const bcrypt = require('bcryptjs');
const crypto = require('crypto');

class PasswordUtil {
  static async hashPassword(plainPassword) {
    const saltRounds = parseInt(process.env.BCRYPT_SALT_ROUNDS || '12', 10);
    return await bcrypt.hash(plainPassword, saltRounds);
  }

  static async verifyPassword(plainPassword, hash) {
    return await bcrypt.compare(plainPassword, hash);
  }

  static generateTransmissionHash(password) {
    return crypto
      .createHash('sha256')
      .update(password + (process.env.PASSWORD_PEPPER || ''))
      .digest('hex');
  }

  static validatePasswordStrength(password) {
    const errors = [];

    if (password.length < 8) {
      errors.push('Password must be at least 8 characters long');
    }

    if (password.length > 128) {
      errors.push('Password must not exceed 128 characters');
    }

    if (!/[a-z]/.test(password)) {
      errors.push('Password must contain at least one lowercase letter');
    }

    if (!/[A-Z]/.test(password)) {
      errors.push('Password must contain at least one uppercase letter');
    }

    if (!/\d/.test(password)) {
      errors.push('Password must contain at least one number');
    }

    if (!/[@$!%*?&#^()_+=\-\[\]{};:'",.<>/?\\|`~]/.test(password)) {
      errors.push('Password must contain at least one special character');
    }

    return {
      isValid: errors.length === 0,
      errors
    };
  }
}

module.exports = PasswordUtil;