// src/modules/auth/auth.validator.js
const Joi = require("joi");

/**
 * Export Joi schema objects so we can reuse them to generate docs.
 * Keep the validate* helpers for runtime validation.
 */

const sendOTPSchema = Joi.object({
  email: Joi.string().email().required().messages({
    "string.email": "Please provide a valid email address",
    "any.required": "Email is required",
  }),
  otpType: Joi.string().default("REGISTER").messages({
    "any.only": "Invalid OTP type",
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
  otpType: Joi.string().default("REGISTER").messages({
    "any.only": "Invalid OTP type",
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
  website: Joi.string().uri().optional().allow(""),
  contactPerson: Joi.string().min(2).max(255).required().messages({
    "string.min": "Contact person name must be at least 2 characters",
    "string.max": "Contact person name must be at most 255 characters",
    "any.required": "Contact person name is required",
  }),
  contactNumber: Joi.string()
    .pattern(/^[0-9]{10,15}$/)
    .required()
    .messages({
      "string.pattern.base": "Contact number must be 10-15 digits",
      "any.required": "Contact number is required",
    }),
  addressLine: Joi.string().min(5).max(255).required().messages({
    "string.min": "Address must be at least 5 characters",
    "any.required": "Address is required",
  }),
  city: Joi.string().min(2).max(100).required().messages({
    "string.min": "City must be at least 2 characters",
    "any.required": "City is required",
  }),
  state: Joi.string().min(2).max(100).required().messages({
    "string.min": "State must be at least 2 characters",
    "any.required": "State is required",
  }),
  country: Joi.string().max(100).default("India"),
  pincode: Joi.string()
    .pattern(/^[0-9]{5,10}$/)
    .required()
    .messages({
      "string.pattern.base": "Pincode must be 5-10 digits",
      "any.required": "Pincode is required",
    }),
  subscriptionType: Joi.string().default("TRIAL"),
  billingCycle: Joi.string().default("MONTHLY"),
  ownerName: Joi.string().min(2).max(255).required().messages({
    "string.min": "Owner name must be at least 2 characters",
    "any.required": "Owner name is required",
  }),
  ownerEmail: Joi.string().email().required().messages({
    "string.email": "Please provide a valid owner email",
    "any.required": "Owner email is required",
  }),
  ownerContactNumber: Joi.string()
    .pattern(/^[0-9]{10,15}$/)
    .required()
    .messages({
      "string.pattern.base": "Owner contact number must be 10-15 digits",
      "any.required": "Owner contact number is required",
    }),
  ownerRole: Joi.string().default("OWNER"),
});

// keep existing validate* helpers, using schemas above:
class AuthValidator {
  static validateSendOTP(data) {
    return sendOTPSchema.validate(data);
  }
  static validateVerifyOTP(data) {
    return verifyOTPSchema.validate(data);
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
    completeRegistrationSchema,
  },
};
