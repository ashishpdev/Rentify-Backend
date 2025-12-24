// src/modules/auth/auth.validator.js
// Input validation & sanitization using Joi
const Joi = require("joi");

// ========================= VALIDATION SCHEMAS =========================

const sendOTPSchema = Joi.object({
  email: Joi.string().email().required().trim().lowercase().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
    "string.empty": "Email cannot be empty",
  }),
  otp_type_id: Joi.number()
    .integer()
    .valid(1, 2, 3) // 1=LOGIN, 2=REGISTRATION, 3=RESET_PASSWORD
    .required()
    .messages({
      "number.base": "OTP type ID must be a number",
      "any.only":
        "Invalid OTP type. Must be 1 (LOGIN), 2 (REGISTRATION), or 3 (RESET_PASSWORD)",
      "any.required": "OTP type ID is required",
    }),
});

const verifyOTPSchema = Joi.object({
  email: Joi.string().email().required().trim().lowercase().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  otpCode: Joi.string().length(6).pattern(/^\d+$/).required().messages({
    "string.length": "OTP must be exactly 6 digits",
    "string.pattern.base": "OTP must contain only numbers",
    "any.required": "OTP code is required",
  }),
  otp_type_id: Joi.number().integer().valid(1, 2, 3).required().messages({
    "number.base": "OTP type ID must be a number",
    "any.only": "Invalid OTP type",
    "any.required": "OTP type ID is required",
  }),
});

const loginOTPSchema = Joi.object({
  email: Joi.string().email().required().trim().lowercase().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  otpCode: Joi.string().length(6).pattern(/^\d+$/).required().messages({
    "string.length": "OTP must be exactly 6 digits",
    "string.pattern.base": "OTP must contain only numbers",
    "any.required": "OTP code is required",
  }),
  otp_type_id: Joi.number()
    .integer()
    .equal(1) // Must be LOGIN type
    .required()
    .messages({
      "number.base": "OTP type ID must be a number",
      "any.only": "OTP type ID must be 1 (LOGIN)",
      "any.required": "OTP type ID is required",
    }),
});

const loginPasswordSchema = Joi.object({
  email: Joi.string().email().required().trim().lowercase().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  password: Joi.string().min(8).max(100).required().messages({
    "string.min": "Password must be at least 8 characters",
    "string.max": "Password must not exceed 100 characters",
    "any.required": "Password is required",
  }),
});

const completeRegistrationSchema = Joi.object({
  businessName: Joi.string().min(2).max(200).required().trim().messages({
    "string.min": "Business name must be at least 2 characters",
    "string.max": "Business name must not exceed 200 characters",
    "any.required": "Business name is required",
  }),
  businessEmail: Joi.string().email().required().trim().lowercase().messages({
    "string.email": "Please provide a valid business email address",
    "any.required": "Business email is required",
  }),
  ownerName: Joi.string().min(2).max(200).required().trim().messages({
    "string.min": "Owner name must be at least 2 characters",
    "string.max": "Owner name must not exceed 200 characters",
    "any.required": "Owner name is required",
  }),
  ownerEmail: Joi.string().email().required().trim().lowercase().messages({
    "string.email": "Please provide a valid owner email",
    "any.required": "Owner email is required",
  }),
  ownerContactNumber: Joi.string()
    .pattern(/^[0-9]{10}$/)
    .required()
    .messages({
      "string.pattern.base": "Owner contact number must be exactly 10 digits",
      "any.required": "Owner contact number is required",
    }),
});

const changePasswordSchema = Joi.object({
  oldPassword: Joi.string().min(8).max(100).required().messages({
    "string.min": "Password must be at least 8 characters",
    "string.max": "Password must not exceed 100 characters",
    "any.required": "Current password is required",
  }),
  newPassword: Joi.string()
    .min(8)
    .max(100)
    .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .required()
    .messages({
      "string.min": "New password must be at least 8 characters",
      "string.max": "New password must not exceed 100 characters",
      "string.pattern.base":
        "New password must contain at least one uppercase letter, one lowercase letter, one number, and one special character",
      "any.required": "New password is required",
    }),
  confirmPassword: Joi.string()
    .valid(Joi.ref("newPassword"))
    .required()
    .messages({
      "any.only": "Passwords do not match",
      "any.required": "Confirm password is required",
    }),
});

const resetPasswordSchema = Joi.object({
  email: Joi.string().email().required().trim().lowercase().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  otpCode: Joi.string().length(6).pattern(/^\d+$/).required().messages({
    "string.length": "OTP must be exactly 6 digits",
    "string.pattern.base": "OTP must contain only numbers",
    "any.required": "OTP code is required",
  }),
  newPassword: Joi.string()
    .min(8)
    .max(100)
    .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]/)
    .required()
    .messages({
      "string.min": "New password must be at least 8 characters",
      "string.max": "New password must not exceed 100 characters",
      "string.pattern.base":
        "New password must contain at least one uppercase letter, one lowercase letter, one number, and one special character",
      "any.required": "New password is required",
    }),
  confirmPassword: Joi.string()
    .valid(Joi.ref("newPassword"))
    .required()
    .messages({
      "any.only": "Passwords do not match",
      "any.required": "Confirm password is required",
    }),
});

// ========================= VALIDATOR CLASS =========================

class AuthValidator {
  static validateSendOTP(data) {
    return sendOTPSchema.validate(data, { abortEarly: false });
  }

  static validateVerifyOTP(data) {
    return verifyOTPSchema.validate(data, { abortEarly: false });
  }

  static validateLoginOTP(data) {
    return loginOTPSchema.validate(data, { abortEarly: false });
  }

  static validateLoginPassword(data) {
    return loginPasswordSchema.validate(data, { abortEarly: false });
  }

  static validateCompleteRegistration(data) {
    return completeRegistrationSchema.validate(data, { abortEarly: false });
  }

  static validateChangePassword(data) {
    return changePasswordSchema.validate(data, { abortEarly: false });
  }

  static validateResetPassword(data) {
    return resetPasswordSchema.validate(data, { abortEarly: false });
  }
}

// ========================= EXPORTS =========================

module.exports = {
  AuthValidator,
  // Export schemas for API documentation generation
  schemas: {
    sendOTPSchema,
    verifyOTPSchema,
    loginOTPSchema,
    loginPasswordSchema,
    completeRegistrationSchema,
    changePasswordSchema,
    resetPasswordSchema,
  },
};
