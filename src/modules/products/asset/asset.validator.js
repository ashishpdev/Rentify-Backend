// src/modules/products/asset/asset.validator.js
const Joi = require("joi");

const createAssetSchema = Joi.object({
  product_model_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product model ID must be a number",
    "number.positive": "Product model ID must be positive",
    "any.required": "Product model ID is required",
  }),
  serial_number: Joi.string().min(1).max(100).required().messages({
    "string.base": "Serial number must be text",
    "string.min": "Serial number must be at least 1 character",
    "string.max": "Serial number must be at most 100 characters",
    "any.required": "Serial number is required",
  }),
  asset_tag: Joi.string().max(100).allow(null, "").optional(),
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
  rent_price: Joi.number().precision(2).min(0).allow(null).optional(),
  sell_price: Joi.number().precision(2).min(0).allow(null).optional(),
  source_type_id: Joi.number().integer().positive().required().messages({
    "number.base": "Source type ID must be a number",
    "number.positive": "Source type ID must be positive",
    "any.required": "Source type ID is required",
  }),
  borrowed_from_business_name: Joi.string().max(200).allow(null, "").optional(),
  borrowed_from_branch_name: Joi.string().max(200).allow(null, "").optional(),
  purchase_date: Joi.date().allow(null).optional(),
  purchase_price: Joi.number().precision(2).min(0).allow(null).optional(),
  current_value: Joi.number().precision(2).min(0).allow(null).optional(),
  // Asset-specific fields
  upper_body_measurement: Joi.string().max(50).allow(null, "").optional(),
  lower_body_measurement: Joi.string().max(50).allow(null, "").optional(),
  size_range: Joi.string().max(50).allow(null, "").optional(),
  color_name: Joi.string().max(100).allow(null, "").optional(),
  fabric_type: Joi.string().max(100).allow(null, "").optional(),
  movement_category: Joi.string().max(20).valid('NORMAL', 'FAST', 'SLOW').allow(null, "").optional(),
  manufacturing_date: Joi.date().allow(null).optional(),
  manufacturing_cost: Joi.number().precision(2).min(0).allow(null).optional(),
  // Optional detailed measurements
  chest_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  waist_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  hip_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  shoulder_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  sleeve_length_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  length_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  inseam_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  neck_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
});

const updateAssetSchema = Joi.object({
  asset_id: Joi.number().integer().positive().required().messages({
    "number.base": "Asset ID must be a number",
    "number.positive": "Asset ID must be positive",
    "any.required": "Asset ID is required",
  }),
  product_model_id: Joi.number().integer().positive().required().messages({
    "number.base": "Product model ID must be a number",
    "number.positive": "Product model ID must be positive",
    "any.required": "Product model ID is required",
  }),
  serial_number: Joi.string().min(1).max(100).required().messages({
    "string.base": "Serial number must be text",
    "string.min": "Serial number must be at least 1 character",
    "string.max": "Serial number must be at most 100 characters",
    "any.required": "Serial number is required",
  }),
  asset_tag: Joi.string().max(100).allow(null, "").optional(),
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
  rent_price: Joi.number().precision(2).min(0).allow(null).optional(),
  sell_price: Joi.number().precision(2).min(0).allow(null).optional(),
  source_type_id: Joi.number().integer().positive().required().messages({
    "number.base": "Source type ID must be a number",
    "number.positive": "Source type ID must be positive",
    "any.required": "Source type ID is required",
  }),
  borrowed_from_business_name: Joi.string().max(200).allow(null, "").optional(),
  borrowed_from_branch_name: Joi.string().max(200).allow(null, "").optional(),
  purchase_date: Joi.date().allow(null).optional(),
  purchase_price: Joi.number().precision(2).min(0).allow(null).optional(),
  current_value: Joi.number().precision(2).min(0).allow(null).optional(),
  // Asset-specific fields
  upper_body_measurement: Joi.string().max(50).allow(null, "").optional(),
  lower_body_measurement: Joi.string().max(50).allow(null, "").optional(),
  size_range: Joi.string().max(50).allow(null, "").optional(),
  color_name: Joi.string().max(100).allow(null, "").optional(),
  fabric_type: Joi.string().max(100).allow(null, "").optional(),
  movement_category: Joi.string().max(20).valid('NORMAL', 'FAST', 'SLOW').allow(null, "").optional(),
  manufacturing_date: Joi.date().allow(null).optional(),
  manufacturing_cost: Joi.number().precision(2).min(0).allow(null).optional(),
  // Optional detailed measurements
  chest_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  waist_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  hip_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  shoulder_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  sleeve_length_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  length_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  inseam_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
  neck_cm: Joi.number().precision(2).min(0).max(999.99).allow(null).optional(),
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