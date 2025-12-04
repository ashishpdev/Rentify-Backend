// src/modules/products/segment/segment.validator.js
const Joi = require("joi");

const createSegmentSchema = Joi.object({
  code: Joi.string().min(1).max(128).required().messages({
    "string.base": "Code must be text",
    "string.min": "Code must be at least 1 character",
    "string.max": "Code must be at most 128 characters",
    "any.required": "Code is required",
  }),
  name: Joi.string().min(2).max(255).required().messages({
    "string.base": "Name must be text",
    "string.min": "Name must be at least 2 characters",
    "string.max": "Name must be at most 255 characters",
    "any.required": "Name is required",
  }),
  description: Joi.string().max(1000).allow(null, "").optional().messages({
    "string.base": "Description must be text",
    "string.max": "Description must be at most 1000 characters",
  }),
});

const updateSegmentSchema = Joi.object({
  product_segment_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product segment ID must be a number",
    "number.positive": "Product segment ID must be positive",
    "any.required": "Product segment ID is required",
  }),
  code: Joi.string().min(1).max(128).required().messages({
    "string.base": "Code must be text",
    "string.min": "Code must be at least 1 character",
    "string.max": "Code must be at most 128 characters",
    "any.required": "Code is required",
  }),
  name: Joi.string().min(2).max(255).required().messages({
    "string.base": "Name must be text",
    "string.min": "Name must be at least 2 characters",
    "string.max": "Name must be at most 255 characters",
    "any.required": "Name is required",
  }),
  description: Joi.string().max(1000).allow(null, "").optional().messages({
    "string.base": "Description must be text",
    "string.max": "Description must be at most 1000 characters",
  }),
});

const getSegmentSchema = Joi.object({
  product_segment_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product segment ID must be a number",
    "number.positive": "Product segment ID must be positive",
    "any.required": "Product segment ID is required",
  }),
});

const deleteSegmentSchema = Joi.object({
  product_segment_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product segment ID must be a number",
    "number.positive": "Product segment ID must be positive",
    "any.required": "Product segment ID is required",
  }),
});

const listSegmentsSchema = Joi.object({
  // Optional filters for listing
  page: Joi.number().integer().positive().optional().default(1),
  limit: Joi.number().integer().positive().max(100).optional().default(50),
});

class SegmentValidator {
  static validateCreateSegment(data) {
    return createSegmentSchema.validate(data);
  }

  static validateUpdateSegment(data) {
    return updateSegmentSchema.validate(data);
  }

  static validateGetSegment(data) {
    return getSegmentSchema.validate(data);
  }

  static validateDeleteSegment(data) {
    return deleteSegmentSchema.validate(data);
  }

  static validateListSegments(data) {
    return listSegmentsSchema.validate(data);
  }
}

module.exports = {
  SegmentValidator,
  schemas: {
    createSegmentSchema,
    updateSegmentSchema,
    getSegmentSchema,
    deleteSegmentSchema,
    listSegmentsSchema,
  },
};
