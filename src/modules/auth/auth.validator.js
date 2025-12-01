// Validators --  Input validation & sanitization
const Joi = require("joi");

const sendOTPSchema = Joi.object({
  email: Joi.string().email().required().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  otp_type_id: Joi.number().integer().required().messages({
    "number.base": "OTP type ID must be a number",
    "any.required": "OTP type ID is required",
  }),
});

const verifyOTPSchema = Joi.object({
  email: Joi.string().email().required().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  otpCode: Joi.string().length(6).pattern(/^\d+$/).required().messages({
    "string.length": "OTP must be 6 digits",
    "string.pattern.base": "OTP must contain only numbers",
    "any.required": "OTP code is required",
  }),
  otp_type_id: Joi.number().integer().required().messages({
    "number.base": "OTP type ID must be a number",
    "any.required": "OTP type ID is required",
  }),
});

const loginOTPSchema = Joi.object({
  email: Joi.string().email().required().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  otpCode: Joi.string().length(6).pattern(/^\d+$/).required().messages({
    "string.length": "OTP must be 6 digits",
    "string.pattern.base": "OTP must contain only numbers",
    "any.required": "OTP code is required",
  }),
  otp_type_id: Joi.number().integer().equal(1).required().messages({
    "number.base": "OTP type ID must be a number",
    "any.only": "OTP type ID must be 1 (LOGIN)",
    "any.required": "OTP type ID is required",
  }),
});

const completeRegistrationSchema = Joi.object({
  businessName: Joi.string().min(2).max(255).required().messages({
    "string.min": "Business name must be at least 2 characters",
    "string.max": "Business name must be at most 255 characters",
    "any.required": "Business name is required",
  }),
  businessEmail: Joi.string().email().required().messages({
    "string.email": "Please provide a valid business email address",
    "any.required": "Business email is required",
  }),
  ownerName: Joi.string().min(2).max(255).required().messages({
    "string.min": "Owner name must be at least 2 characters",
    "any.required": "Owner name is required",
  }),
  ownerEmail: Joi.string().email().required().messages({
    "string.email": "Please provide a valid owner email",
    "any.required": "Owner email is required",
  }),
  ownerContactNumber: Joi.string()
    .pattern(/^[0-9]{10}$/)
    .required()
    .messages({
      "string.pattern.base": "Owner contact number must be 10 digits",
      "any.required": "Owner contact number is required",
    }),
});

// keep existing validate* helpers, using schemas above:
class AuthValidator {
  static validateSendOTP(data) {
    return sendOTPSchema.validate(data);
  }
  static validateVerifyOTP(data) {
    return verifyOTPSchema.validate(data);
  }
  static validateLoginOTP(data) {
    return loginOTPSchema.validate(data);
  }
  static validateCompleteRegistration(data) {
    return completeRegistrationSchema.validate(data);
  }
}

module.exports = {
  AuthValidator,
  // export schemas for docs generation
  schemas: {
    sendOTPSchema,
    verifyOTPSchema,
    loginOTPSchema,
    completeRegistrationSchema,
  },
};
