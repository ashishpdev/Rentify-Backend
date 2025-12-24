const ResponseUtil = require("../../../utils/response.util");
const logger = require("../../../config/logger.config");
const { ModelValidator } = require("./model.validator");
const modelService = require("./model.service");
const driveService = require("../../google-drive/drive.service");

class ModelController {
  constructor() {
    this.createModel = this.createModel.bind(this);
    this.updateModel = this.updateModel.bind(this);
    this.getModel = this.getModel.bind(this);
    this.listModels = this.listModels.bind(this);
    this.deleteModel = this.deleteModel.bind(this);
  }

  // ======================== CREATE MODEL ========================
  async createModel(req, res) {
    try {
      // Validate incoming JSON body
      const { error, value } = ModelValidator.validateCreateModel(req.body);
      if (error) {
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      // Map drive API response format to database format if needed
      if (value.product_model_images && value.product_model_images.length > 0) {
        value.product_model_images = value.product_model_images.map(
          (img, idx) => ({
            file_id: img.file_id,
            file_name: img.file_name,
            url: img.url,
            original_file_name: img.original_file_name,
            file_size: img.file_size,
            thumbnail_url: img.thumbnail_url || null,
            is_primary: idx === 0, // First image is primary by default
            image_order: idx,
            product_model_image_category_id:
              img.product_model_image_category_id || 0,
          })
        );
      }

      const userData = req.user;
      const result = await modelService.createModel(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.created(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "createModel" });
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to create model"
      );
    }
  }

  // ======================== UPDATE MODEL ========================
  async updateModel(req, res) {
    try {
      // Validate incoming JSON body
      const { error, value } = ModelValidator.validateUpdateModel(req.body);
      if (error) {
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;

      // Extract file IDs marked for deletion
      const fileIdsMarkedForDelete = (value.product_model_images || [])
        .filter((img) => img.is_deleted && img.file_id)
        .map((img) => img.file_id);

      const result = await modelService.updateModel(value, userData, {
        fileIdsMarkedForDelete,
      });

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "updateModel" });
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to update model"
      );
    }
  }

  // ======================== GET MODEL ========================
  async getModel(req, res) {
    try {
      const { error, value } = ModelValidator.validateGetModel(req.body);
      if (error) return ResponseUtil.badRequest(res, error.details[0].message);

      const userData = req.user;
      const result = await modelService.getModel(
        value.product_model_id,
        userData
      );

      if (!result.success) return ResponseUtil.notFound(res, result.message);

      return ResponseUtil.success(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "getModel" });
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to get model"
      );
    }
  }

  // ======================== LIST MODELS ========================
  async listModels(req, res) {
    try {
      const { error, value } = ModelValidator.validateListModels(req.body);
      if (error) return ResponseUtil.badRequest(res, error.details[0].message);

      const userData = req.user;
      const pagination = { page: value.page, limit: value.limit };
      const result = await modelService.listModels(userData, pagination);

      if (!result.success) return ResponseUtil.badRequest(res, result.message);

      return ResponseUtil.success(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "listModels" });
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to list models"
      );
    }
  }

  // ======================== DELETE MODEL ========================
  async deleteModel(req, res) {
    try {
      const { error, value } = ModelValidator.validateDeleteModel(req.body);
      if (error) return ResponseUtil.badRequest(res, error.details[0].message);

      const userData = req.user;
      const result = await modelService.deleteModel(
        value.product_model_id,
        userData
      );

      if (!result.success) return ResponseUtil.badRequest(res, result.message);

      return ResponseUtil.success(res, result.data, result.message);
    } catch (err) {
      logger.logError(err, req, { operation: "deleteModel" });
      return ResponseUtil.serverError(
        res,
        err.message || "Failed to delete model"
      );
    }
  }
}

module.exports = new ModelController();