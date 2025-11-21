// Authentication validator
const Joi = require("joi");

class AuthValidator {
  /**
   * Validate send OTP request
   */
  static validateSendOTP(data) {
    const schema = Joi.object({
      email: Joi.string().email().required().messages({
        "string.email": "Please provide a valid email address",
        "any.required": "Email is required",
      }),
      otpType: Joi.string()
        .valid("REGISTER", "VERIFY_EMAIL")
        .default("REGISTER")
        .messages({
          "any.only": "Invalid OTP type",
        }),
    });

    return schema.validate(data);
  }

  /**
   * Validate verify OTP request
   */
  static validateVerifyOTP(data) {
    const schema = Joi.object({
      email: Joi.string().email().required().messages({
        "string.email": "Please provide a valid email address",
        "any.required": "Email is required",
      }),
      otpCode: Joi.string().length(6).pattern(/^\d+$/).required().messages({
        "string.length": "OTP must be 6 digits",
        "string.pattern.base": "OTP must contain only numbers",
        "any.required": "OTP code is required",
      }),
      otpType: Joi.string()
        .valid("REGISTER", "VERIFY_EMAIL")
        .default("REGISTER")
        .messages({
          "any.only": "Invalid OTP type",
        }),
    });

    return schema.validate(data);
  }

  /**
   * Validate complete registration request
   */
  static validateCompleteRegistration(data) {
    const schema = Joi.object({
      businessName: Joi.string().min(2).max(255).required().messages({
        "string.min": "Business name must be at least 2 characters",
        "string.max": "Business name cannot exceed 255 characters",
        "any.required": "Business name is required",
      }),
      businessEmail: Joi.string().email().required().messages({
        "string.email": "Please provide a valid business email",
        "any.required": "Business email is required",
      }),
      website: Joi.string().uri().optional().allow("").messages({
        "string.uri": "Please provide a valid website URL",
      }),
      contactPerson: Joi.string().min(2).max(255).required().messages({
        "string.min": "Contact person name must be at least 2 characters",
        "any.required": "Contact person is required",
      }),
      contactNumber: Joi.string().pattern(/^[0-9]{10,15}$/).required().messages({
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
      pincode: Joi.string().pattern(/^[0-9]{5,10}$/).required().messages({
        "string.pattern.base": "Pincode must be 5-10 digits",
        "any.required": "Pincode is required",
      }),
      subscriptionType: Joi.string()
        .valid("TRIAL", "BASIC", "STANDARD", "PREMIUM", "ENTERPRISE", "CUSTOM")
        .default("TRIAL"),
      billingCycle: Joi.string()
        .valid("MONTHLY", "QUARTERLY", "YEARLY", "LIFETIME")
        .default("MONTHLY"),
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
      ownerRole: Joi.string()
        .valid("OWNER", "ADMIN")
        .default("OWNER"),
    });

    return schema.validate(data);
  }
}

module.exports = AuthValidator;