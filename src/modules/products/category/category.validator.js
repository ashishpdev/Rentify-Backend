// src/modules/products/category/category.validator.js
const Joi = require("joi");

const createCategorySchema = Joi.object({
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

const updateCategorySchema = Joi.object({
  product_category_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product category ID must be a number",
    "number.positive": "Product category ID must be positive",
    "any.required": "Product category ID is required",
  }),
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

const getCategorySchema = Joi.object({
  product_category_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product category ID must be a number",
    "number.positive": "Product category ID must be positive",
    "any.required": "Product category ID is required",
  }),
});

const deleteCategorySchema = Joi.object({
  product_category_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product category ID must be a number",
    "number.positive": "Product category ID must be positive",
    "any.required": "Product category ID is required",
  }),
});

const listCategoriesSchema = Joi.object({
  page: Joi.number().integer().positive().optional().default(1),
  limit: Joi.number().integer().positive().max(100).optional().default(50),
});

class CategoryValidator {
  static validateCreateCategory(data) {
    return createCategorySchema.validate(data);
  }
  static validateUpdateCategory(data) {
    return updateCategorySchema.validate(data);
  }
  static validateGetCategory(data) {
    return getCategorySchema.validate(data);
  }
  static validateDeleteCategory(data) {
    return deleteCategorySchema.validate(data);
  }
  static validateListCategories(data) {
    return listCategoriesSchema.validate(data);
  }
}

module.exports = {
  CategoryValidator,
  schemas: {
    createCategorySchema,
    updateCategorySchema,
    getCategorySchema,
    deleteCategorySchema,
    listCategoriesSchema,
  },
};
