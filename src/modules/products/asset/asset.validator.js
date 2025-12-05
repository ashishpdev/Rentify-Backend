// src/modules/products/asset/asset.validator.js
const Joi = require("joi");

const createAssetSchema = Joi.object({
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
  product_model_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product model ID must be a number",
    "number.positive": "Product model ID must be positive",
    "any.required": "Product model ID is required",
  }),
  serial_number: Joi.string().min(1).max(200).required().messages({
    "string.base": "Serial number must be text",
    "string.min": "Serial number must be at least 1 character",
    "string.max": "Serial number must be at most 200 characters",
    "any.required": "Serial number is required",
  }),
  product_images: Joi.any().allow(null).optional(),
  product_status_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product status ID must be a number",
    "number.positive": "Product status ID must be positive",
    "any.required": "Product status ID is required",
  }),
  product_condition_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product condition ID must be a number",
    "number.positive": "Product condition ID must be positive",
    "any.required": "Product condition ID is required",
  }),
  product_rental_status_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product rental status ID must be a number",
    "number.positive": "Product rental status ID must be positive",
    "any.required": "Product rental status ID is required",
  }),
  purchase_price: Joi.number().precision(2).min(0).allow(null).optional().messages({
    "number.base": "Purchase price must be a number",
    "number.min": "Purchase price must be at least 0",
  }),
  purchase_date: Joi.date().allow(null).optional().messages({
    "date.base": "Purchase date must be a valid date",
  }),
  current_value: Joi.number().precision(2).min(0).allow(null).optional().messages({
    "number.base": "Current value must be a number",
    "number.min": "Current value must be at least 0",
  }),
  rent_price: Joi.number().precision(2).min(0).allow(null).optional().messages({
    "number.base": "Rent price must be a number",
    "number.min": "Rent price must be at least 0",
  }),
  deposit_amount: Joi.number().precision(2).min(0).allow(null).optional().messages({
    "number.base": "Deposit amount must be a number",
    "number.min": "Deposit amount must be at least 0",
  }),
  source_type_id: Joi.number().integer().positive().required().messages({
    "number.base": "Source type ID must be a number",
    "number.positive": "Source type ID must be positive",
    "any.required": "Source type ID is required",
  }),
  borrowed_from_business_name: Joi.string().max(255).allow(null, "").optional().messages({
    "string.base": "Borrowed from business name must be text",
    "string.max": "Borrowed from business name must be at most 255 characters",
  }),
  borrowed_from_branch_name: Joi.string().max(255).allow(null, "").optional().messages({
    "string.base": "Borrowed from branch name must be text",
    "string.max": "Borrowed from branch name must be at most 255 characters",
  }),
  purchase_bill_url: Joi.string().max(1024).allow(null, "").optional().messages({
    "string.base": "Purchase bill URL must be text",
    "string.max": "Purchase bill URL must be at most 1024 characters",
  }),
});

const updateAssetSchema = Joi.object({
  asset_id: Joi.number().integer().positive().required().messages({
    "number.base": "Asset ID must be a number",
    "number.positive": "Asset ID must be positive",
    "any.required": "Asset ID is required",
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
  product_model_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product model ID must be a number",
    "number.positive": "Product model ID must be positive",
    "any.required": "Product model ID is required",
  }),
  serial_number: Joi.string().min(1).max(200).required().messages({
    "string.base": "Serial number must be text",
    "string.min": "Serial number must be at least 1 character",
    "string.max": "Serial number must be at most 200 characters",
    "any.required": "Serial number is required",
  }),
  product_images: Joi.any().allow(null).optional(),
  product_status_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product status ID must be a number",
    "number.positive": "Product status ID must be positive",
    "any.required": "Product status ID is required",
  }),
  product_condition_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product condition ID must be a number",
    "number.positive": "Product condition ID must be positive",
    "any.required": "Product condition ID is required",
  }),
  product_rental_status_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product rental status ID must be a number",
    "number.positive": "Product rental status ID must be positive",
    "any.required": "Product rental status ID is required",
  }),
  purchase_price: Joi.number().precision(2).min(0).allow(null).optional().messages({
    "number.base": "Purchase price must be a number",
    "number.min": "Purchase price must be at least 0",
  }),
  purchase_date: Joi.date().allow(null).optional().messages({
    "date.base": "Purchase date must be a valid date",
  }),
  current_value: Joi.number().precision(2).min(0).allow(null).optional().messages({
    "number.base": "Current value must be a number",
    "number.min": "Current value must be at least 0",
  }),
  rent_price: Joi.number().precision(2).min(0).allow(null).optional().messages({
    "number.base": "Rent price must be a number",
    "number.min": "Rent price must be at least 0",
  }),
  deposit_amount: Joi.number().precision(2).min(0).allow(null).optional().messages({
    "number.base": "Deposit amount must be a number",
    "number.min": "Deposit amount must be at least 0",
  }),
  source_type_id: Joi.number().integer().positive().required().messages({
    "number.base": "Source type ID must be a number",
    "number.positive": "Source type ID must be positive",
    "any.required": "Source type ID is required",
  }),
  borrowed_from_business_name: Joi.string().max(255).allow(null, "").optional().messages({
    "string.base": "Borrowed from business name must be text",
    "string.max": "Borrowed from business name must be at most 255 characters",
  }),
  borrowed_from_branch_name: Joi.string().max(255).allow(null, "").optional().messages({
    "string.base": "Borrowed from branch name must be text",
    "string.max": "Borrowed from branch name must be at most 255 characters",
  }),
  purchase_bill_url: Joi.string().max(1024).allow(null, "").optional().messages({
    "string.base": "Purchase bill URL must be text",
    "string.max": "Purchase bill URL must be at most 1024 characters",
  }),
});

const getAssetSchema = Joi.object({
  asset_id: Joi.number().integer().positive().required().messages({
    "number.base": "Asset ID must be a number",
    "number.positive": "Asset ID must be positive",
    "any.required": "Asset ID is required",
  }),
});

const deleteAssetSchema = Joi.object({
  asset_id: Joi.number().integer().positive().required().messages({
    "number.base": "Asset ID must be a number",
    "number.positive": "Asset ID must be positive",
    "any.required": "Asset ID is required",
  }),
});

const listAssetsSchema = Joi.object({
  // Optional filters for listing
  page: Joi.number().integer().positive().optional().default(1),
  limit: Joi.number().integer().positive().max(100).optional().default(50),
});

class AssetValidator {
  static validateCreateAsset(data) {
    return createAssetSchema.validate(data);
  }

  static validateUpdateAsset(data) {
    return updateAssetSchema.validate(data);
  }

  static validateGetAsset(data) {
    return getAssetSchema.validate(data);
  }

  static validateDeleteAsset(data) {
    return deleteAssetSchema.validate(data);
  }

  static validateListAssets(data) {
    return listAssetsSchema.validate(data);
  }
}

module.exports = {
  AssetValidator,
  schemas: {
    createAssetSchema,
    updateAssetSchema,
    getAssetSchema,
    deleteAssetSchema,
    listAssetsSchema,
  },
};