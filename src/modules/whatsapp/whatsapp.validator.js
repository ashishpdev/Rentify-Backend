// WhatsApp Input Validation
const Joi = require("joi");

const businessIdSchema = Joi.object({
  businessId: Joi.string().required().messages({
    "string.empty": "Business ID is required",
    "any.required": "Business ID is required",
  }),
});

const sendMessageSchema = Joi.object({
  businessId: Joi.string().required().messages({
    "string.empty": "Business ID is required",
    "any.required": "Business ID is required",
  }),
  number: Joi.string()
    .pattern(/^[0-9]{10,15}$/)
    .required()
    .messages({
      "string.pattern.base": "Phone number must be 10-15 digits",
      "string.empty": "Phone number is required",
      "any.required": "Phone number is required",
    }),
  message: Joi.string().min(1).max(4096).required().messages({
    "string.min": "Message cannot be empty",
    "string.max": "Message must be at most 4096 characters",
    "string.empty": "Message is required",
    "any.required": "Message is required",
  }),
});

class WhatsappValidator {
  static validateBusinessId(data) {
    return businessIdSchema.validate(data);
  }

  static validateSendMessage(data) {
    return sendMessageSchema.validate(data);
  }
}

module.exports = {
  WhatsappValidator,
  schemas: {
    businessIdSchema,
    sendMessageSchema,
  },
};
