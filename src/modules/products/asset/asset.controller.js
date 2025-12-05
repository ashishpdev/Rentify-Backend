// src/modules/products/asset/asset.controller.js
const ResponseUtil = require("../../../utils/response.util");
const logger = require("../../../config/logger.config");
const { AssetValidator } = require("./asset.validator");
const assetService = require("./asset.service");

class AssetController {
  // ======================== CREATE ASSET ========================
  async createAsset(req, res, next) {
    try {
      const { error, value } = AssetValidator.validateCreateAsset(req.body);
      if (error) {
        logger.warn("Asset creation validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await assetService.createAsset(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.created(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "createAsset" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to create asset"
      );
    }
  }

  // ======================== UPDATE ASSET ========================
  async updateAsset(req, res, next) {
    try {
      const { error, value } = AssetValidator.validateUpdateAsset(req.body);
      if (error) {
        logger.warn("Asset update validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await assetService.updateAsset(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "updateAsset" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to update asset"
      );
    }
  }

  // ======================== GET ASSET ========================
  async getAsset(req, res, next) {
    try {
      const { error, value } = AssetValidator.validateGetAsset(req.body);
      if (error) {
        logger.warn("Get asset validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await assetService.getAsset(value.asset_id, userData);

      if (!result.success) {
        return ResponseUtil.notFound(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "getAsset" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to get asset"
      );
    }
  }

  // ======================== LIST ASSETS ========================
  async listAssets(req, res, next) {
    try {
      const { error, value } = AssetValidator.validateListAssets(req.body);
      if (error) {
        logger.warn("List assets validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const paginationParams = {
        page: value.page,
        limit: value.limit,
      };
      const result = await assetService.listAssets(userData, paginationParams);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "listAssets" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to list assets"
      );
    }
  }

  // ======================== DELETE ASSET ========================
  async deleteAsset(req, res, next) {
    try {
      const { error, value } = AssetValidator.validateDeleteAsset(req.body);
      if (error) {
        logger.warn("Delete asset validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await assetService.deleteAsset(value.asset_id, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "deleteAsset" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to delete asset"
      );
    }
  }
}

module.exports = new AssetController();