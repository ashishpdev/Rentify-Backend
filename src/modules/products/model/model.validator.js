// src/modules/products/model/model.validator.js
const Joi = require("joi");

const base64DataRegex =
  /^(?:data:[\w-]+\/[\w+.-]+;base64,)?(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;

const createModelSchema = Joi.object({
  product_segment_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product segment ID must be a number",
    "number.positive": "Product segment ID must be positive",
    "any.required": "Product segment ID is required",
  }),
  product_category_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product category ID must be a number",
    "number.positive": "Product category ID must be positive",
    "any.required": "Product category ID is required",
  }),
  model_name: Joi.string().min(1).max(255).required().messages({
    "string.base": "Model name must be text",
    "string.min": "Model name must be at least 1 character",
    "string.max": "Model name must be at most 255 characters",
    "any.required": "Model name is required",
  }),
  description: Joi.string().max(2000).allow(null, "").optional().messages({
    "string.base": "Description must be text",
    "string.max": "Description must be at most 2000 characters",
  }),
  product_model_images: Joi.array()
    .items(
      Joi.object({
        // allow either a standard URI or base64 data (raw or data URI)
        url: Joi.alternatives()
          .try(Joi.string().uri(), Joi.string().pattern(base64DataRegex))
          .required()
          .messages({
            "string.base": "Image URL must be a string",
            "alternatives.match":
              "Image must be a valid URI or base64 data (raw base64 or data URI)",
            "string.pattern.base":
              "Image must be valid base64 data or data URI",
            "any.required": "Image URL is required",
          }),
        alt_text: Joi.string().max(512).optional().messages({
          "string.base": "Alt text must be a string",
          "string.max": "Alt text must be at most 512 characters",
        }),
        is_primary: Joi.boolean().optional().messages({
          "boolean.base": "Is primary must be a boolean",
        }),
        image_order: Joi.number().integer().positive().optional().messages({
          "number.base": "Image order must be a number",
          "number.integer": "Image order must be an integer",
          "number.positive": "Image order must be positive",
        }),
      })
    )
    .optional()
    .messages({
      "array.base": "Product model images must be an array",
    }),
  default_rent: Joi.number().precision(2).min(0).required().messages({
    "number.base": "Default rent must be a number",
    "number.min": "Default rent must be at least 0",
    "any.required": "Default rent is required",
  }),
  default_deposit: Joi.number().precision(2).min(0).required().messages({
    "number.base": "Default deposit must be a number",
    "number.min": "Default deposit must be at least 0",
    "any.required": "Default deposit is required",
  }),
  default_warranty_days: Joi.number()
    .integer()
    .min(0)
    .allow(null)
    .optional()
    .messages({
      "number.base": "Default warranty days must be a number",
      "number.integer": "Default warranty days must be an integer",
      "number.min": "Default warranty days must be at least 0",
    }),
  total_quantity: Joi.number().integer().min(0).required().messages({
    "number.base": "Total quantity must be a number",
    "number.integer": "Total quantity must be an integer",
    "number.min": "Total quantity must be at least 0",
    "any.required": "Total quantity is required",
  }),
  available_quantity: Joi.number().integer().min(0).required().messages({
    "number.base": "Available quantity must be a number",
    "number.integer": "Available quantity must be an integer",
    "number.min": "Available quantity must be at least 0",
    "any.required": "Available quantity is required",
  }),
});

const updateModelSchema = Joi.object({
  product_model_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product model ID must be a number",
    "number.positive": "Product model ID must be positive",
    "any.required": "Product model ID is required",
  }),
  product_segment_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product segment ID must be a number",
    "number.positive": "Product segment ID must be positive",
    "any.required": "Product segment ID is required",
  }),
  product_category_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product category ID must be a number",
    "number.positive": "Product category ID must be positive",
    "any.required": "Product category ID is required",
  }),
  model_name: Joi.string().min(1).max(255).required().messages({
    "string.base": "Model name must be text",
    "string.min": "Model name must be at least 1 character",
    "string.max": "Model name must be at most 255 characters",
    "any.required": "Model name is required",
  }),
  description: Joi.string().max(2000).allow(null, "").optional().messages({
    "string.base": "Description must be text",
    "string.max": "Description must be at most 2000 characters",
  }),
  product_model_images: Joi.array()
    .items(
      Joi.object({
        url: Joi.alternatives()
          .try(Joi.string().uri(), Joi.string().pattern(base64DataRegex))
          .required()
          .messages({
            "string.base": "Image URL must be a string",
            "alternatives.match":
              "Image must be a valid URI or base64 data (raw base64 or data URI)",
            "string.pattern.base":
              "Image must be valid base64 data or data URI",
            "any.required": "Image URL is required",
          }),
        alt_text: Joi.string().max(512).optional().messages({
          "string.base": "Alt text must be a string",
          "string.max": "Alt text must be at most 512 characters",
        }),
        is_primary: Joi.boolean().optional().messages({
          "boolean.base": "Is primary must be a boolean",
        }),
        image_order: Joi.number().integer().positive().optional().messages({
          "number.base": "Image order must be a number",
          "number.integer": "Image order must be an integer",
          "number.positive": "Image order must be positive",
        }),
      })
    )
    .optional()
    .messages({
      "array.base": "Product model images must be an array",
    }),
  default_rent: Joi.number().precision(2).min(0).required().messages({
    "number.base": "Default rent must be a number",
    "number.min": "Default rent must be at least 0",
    "any.required": "Default rent is required",
  }),
  default_deposit: Joi.number().precision(2).min(0).required().messages({
    "number.base": "Default deposit must be a number",
    "number.min": "Default deposit must be at least 0",
    "any.required": "Default deposit is required",
  }),
  default_warranty_days: Joi.number()
    .integer()
    .min(0)
    .allow(null)
    .optional()
    .messages({
      "number.base": "Default warranty days must be a number",
      "number.integer": "Default warranty days must be an integer",
      "number.min": "Default warranty days must be at least 0",
    }),
  total_quantity: Joi.number().integer().min(0).optional().default(0).messages({
    "number.base": "Total quantity must be a number",
    "number.integer": "Total quantity must be an integer",
    "number.min": "Total quantity must be at least 0",
  }),
  available_quantity: Joi.number()
    .integer()
    .min(0)
    .optional()
    .default(0)
    .messages({
      "number.base": "Available quantity must be a number",
      "number.integer": "Available quantity must be an integer",
      "number.min": "Available quantity must be at least 0",
    }),
});

const getModelSchema = Joi.object({
  product_model_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product model ID must be a number",
    "number.positive": "Product model ID must be positive",
    "any.required": "Product model ID is required",
  }),
});

const deleteModelSchema = Joi.object({
  product_model_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product model ID must be a number",
    "number.positive": "Product model ID must be positive",
    "any.required": "Product model ID is required",
  }),
});

const listModelsSchema = Joi.object({
  // Optional filters for listing
  page: Joi.number().integer().positive().optional().default(1),
  limit: Joi.number().integer().positive().max(100).optional().default(50),
});

class ModelValidator {
  static validateCreateModel(data) {
    return createModelSchema.validate(data);
  }

  static validateUpdateModel(data) {
    return updateModelSchema.validate(data);
  }

  static validateGetModel(data) {
    return getModelSchema.validate(data);
  }

  static validateDeleteModel(data) {
    return deleteModelSchema.validate(data);
  }

  static validateListModels(data) {
    return listModelsSchema.validate(data);
  }
}

module.exports = {
  ModelValidator,
  schemas: {
    createModelSchema,
    updateModelSchema,
    getModelSchema,
    deleteModelSchema,
    listModelsSchema,
  },
};
