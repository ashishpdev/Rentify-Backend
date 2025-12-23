// src/modules/products/model/model.service.js
const modelRepository = require("./model.repository");
const driveService = require("../../google-drive/drive.service");
const logger = require("../../../config/logger.config");

class ModelService {
  // ======================== CREATE MODEL ========================
  async createModel(modelData, userData) {
    try {
      logger.info("ModelService.createModel called", {
        hasImages: !!modelData.product_model_images,
        imageCount: modelData.product_model_images?.length || 0,
      });

      const result = await modelRepository.manageProductModel({
        action: 1,
        productModelId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: modelData.product_segment_id,
        productCategoryId: modelData.product_category_id,
        modelName: modelData.model_name,
        description: modelData.description || null,
        productModelImages: modelData.product_model_images || null,
        defaultRent: modelData.default_rent,
        defaultDeposit: modelData.default_deposit,
        defaultSell: modelData.default_sell || null,
        defaultWarrantyDays: modelData.default_warranty_days || null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success
          ? { product_model_id: result.productModelId }
          : null,
      };
    } catch (err) {
      logger.error("ModelService.createModel error", { error: err.message });
      throw err;
    }
  }

  // ======================== UPDATE MODEL ========================
  async updateModel(modelData, userData, opts = {}) {
    try {
      const result = await modelRepository.manageProductModel({
        action: 2,
        productModelId: modelData.product_model_id,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: modelData.product_segment_id,
        productCategoryId: modelData.product_category_id,
        modelName: modelData.model_name,
        description: modelData.description || null,
        productModelImages: modelData.product_model_images || null,
        defaultRent: modelData.default_rent,
        defaultDeposit: modelData.default_deposit,
        defaultSell: modelData.default_sell || null,
        defaultWarrantyDays: modelData.default_warranty_days || null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      // If images were marked for deletion in the payload, opts.fileIdsMarkedForDelete contains drive IDs parsed at controller
      if (
        result.success &&
        Array.isArray(opts.fileIdsMarkedForDelete) &&
        opts.fileIdsMarkedForDelete.length
      ) {
        await Promise.allSettled(
          opts.fileIdsMarkedForDelete.map((id) => driveService.deleteImage(id))
        );
      }

      return {
        success: result.success,
        message: result.message,
        data: result.success
          ? { product_model_id: modelData.product_model_id }
          : null,
      };
    } catch (err) {
      logger.error("ModelService.updateModel error", { error: err.message });
      throw err;
    }
  }

  // ======================== GET MODEL ========================
  async getModel(productModelId, userData) {
    try {
      const result = await modelRepository.manageProductModel({
        action: 4,
        productModelId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        productCategoryId: null,
        modelName: null,
        description: null,
        productModelImages: null,
        defaultRent: null,
        defaultDeposit: null,
        defaultSell: null,
        defaultWarrantyDays: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      if (!result.success || !result.data)
        return {
          success: false,
          message: "Product model not found",
          data: null,
        };
      return {
        success: true,
        message: "Product model retrieved",
        data: { model: result.data },
      };
    } catch (err) {
      logger.error("ModelService.getModel error", { error: err.message });
      throw err;
    }
  }

  // ======================== LIST MODELS ========================
  async listModels(userData, paginationParams = {}) {
    try {
      const result = await modelRepository.manageProductModel({
        action: 5,
        productModelId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        productCategoryId: null,
        modelName: null,
        description: null,
        productModelImages: null,
        defaultRent: null,
        defaultDeposit: null,
        defaultSell: null,
        defaultWarrantyDays: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      const all = result.data || [];
      const total = all.length;
      const page = paginationParams.page || 1;
      const limit = paginationParams.limit || 50;
      const totalPages = Math.max(1, Math.ceil(total / limit));
      const start = (page - 1) * limit;
      const models = all.slice(start, start + limit);

      return {
        success: result.success,
        message: result.message,
        data: {
          models,
          pagination: {
            page,
            limit,
            total,
            total_pages: totalPages,
            has_next: page < totalPages,
            has_prev: page > 1,
          },
        },
      };
    } catch (err) {
      logger.error("ModelService.listModels error", { error: err.message });
      throw err;
    }
  }

  // ======================== DELETE MODEL ========================
  async deleteModel(productModelId, userData) {
    try {
      const result = await modelRepository.manageProductModel({
        action: 3,
        productModelId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        productCategoryId: null,
        modelName: null,
        description: null,
        productModelImages: null,
        defaultRent: null,
        defaultDeposit: null,
        defaultSell: null,
        defaultWarrantyDays: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      if (result.success && result.data) {
        // result.data contains images JSON returned by SP; try to extract drive file ids and delete them (best-effort)
        const imgs = result.data;
        let urls = [];
        if (Array.isArray(imgs))
          urls = imgs.map((i) => (i && i.url ? i.url : null)).filter(Boolean);
        else if (imgs && imgs.product_model_images)
          urls = imgs.product_model_images.map((i) => i.url).filter(Boolean);

        const fileIds = urls
          .map((u) => driveService.extractDriveFileId(u))
          .filter(Boolean);
        if (fileIds.length)
          await Promise.allSettled(
            fileIds.map((id) => driveService.deleteImage(id))
          );
      }

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { product_model_id: productModelId } : null,
      };
    } catch (err) {
      logger.error("ModelService.deleteModel error", { error: err.message });
      throw err;
    }
  }
}

module.exports = new ModelService();
