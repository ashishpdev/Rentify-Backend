// src/modules/products/model/model.controller.js
const ResponseUtil = require("../../../utils/response.util");
const logger = require("../../../config/logger.config");
const { ModelValidator } = require("./model.validator");
const modelService = require("./model.service");

class ModelController {
  // ======================== CREATE MODEL ========================
  async createModel(req, res, next) {
    try {
      const { error, value } = ModelValidator.validateCreateModel(req.body);
      if (error) {
        logger.warn("Model creation validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await modelService.createModel(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.created(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "createModel" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to create model"
      );
    }
  }

  // ======================== UPDATE MODEL ========================
  async updateModel(req, res, next) {
    try {
      const { error, value } = ModelValidator.validateUpdateModel(req.body);
      if (error) {
        logger.warn("Model update validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await modelService.updateModel(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "updateModel" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to update model"
      );
    }
  }

  // ======================== GET MODEL ========================
  async getModel(req, res, next) {
    try {
      const { error, value } = ModelValidator.validateGetModel(req.body);
      if (error) {
        logger.warn("Get model validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await modelService.getModel(
        value.product_model_id,
        userData
      );

      if (!result.success) {
        return ResponseUtil.notFound(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "getModel" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to get model"
      );
    }
  }

  // ======================== LIST MODELS ========================
  async listModels(req, res, next) {
    try {
      const { error, value } = ModelValidator.validateListModels(req.body);
      if (error) {
        logger.warn("List models validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const paginationParams = {
        page: value.page,
        limit: value.limit,
      };
      const result = await modelService.listModels(userData, paginationParams);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "listModels" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to list models"
      );
    }
  }

  // ======================== DELETE MODEL ========================
  async deleteModel(req, res, next) {
    try {
      const { error, value } = ModelValidator.validateDeleteModel(req.body);
      if (error) {
        logger.warn("Delete model validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await modelService.deleteModel(
        value.product_model_id,
        userData
      );

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "deleteModel" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to delete model"
      );
    }
  }
}

module.exports = new ModelController();
