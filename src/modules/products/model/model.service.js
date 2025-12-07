// src/modules/products/model/model.service.js
const modelRepository = require("./model.repository");
const logger = require("../../../config/logger.config");

class ModelService {
  // ======================== CREATE MODEL ========================
  async createModel(modelData, userData) {
    try {
      const result = await modelRepository.manageProductModel({
        action: 1, // Create
        productModelId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: modelData.product_segment_id,
        productCategoryId: modelData.product_category_id,
        modelName: modelData.model_name,
        description: modelData.description || null,
        productModelImages: modelData.product_model_images || null, // Changed from productImages
        defaultRent: modelData.default_rent,
        defaultDeposit: modelData.default_deposit,
        defaultWarrantyDays: modelData.default_warranty_days || null,
        totalQuantity: modelData.total_quantity || 0,
        availableQuantity: modelData.available_quantity || 0,
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
    } catch (error) {
      logger.error("ModelService.createModel error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== UPDATE MODEL ========================
  async updateModel(modelData, userData) {
    try {
      const result = await modelRepository.manageProductModel({
        action: 2, // Update
        productModelId: modelData.product_model_id,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: modelData.product_segment_id,
        productCategoryId: modelData.product_category_id,
        modelName: modelData.model_name,
        description: modelData.description || null,
        productModelImages: modelData.product_model_images || null, // Changed from productImages
        defaultRent: modelData.default_rent,
        defaultDeposit: modelData.default_deposit,
        defaultWarrantyDays: modelData.default_warranty_days || null,
        totalQuantity: modelData.total_quantity || 0,
        availableQuantity: modelData.available_quantity || 0,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success
          ? { product_model_id: modelData.product_model_id }
          : null,
      };
    } catch (error) {
      logger.error("ModelService.updateModel error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== GET MODEL ========================
  async getModel(productModelId, userData) {
    try {
      const result = await modelRepository.manageProductModel({
        action: 4, // Get Single
        productModelId: productModelId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        productCategoryId: null,
        modelName: null,
        description: null,
        productImages: null,
        defaultRent: null,
        defaultDeposit: null,
        defaultWarrantyDays: null,
        totalQuantity: null,
        availableQuantity: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      if (!result.success || !result.data) {
        return {
          success: false,
          message: "Product model not found",
          data: null,
        };
      }

      return {
        success: true,
        message: "Product model retrieved successfully",
        data: { model: result.data },
      };
    } catch (error) {
      logger.error("ModelService.getModel error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== LIST MODELS ========================
  async listModels(userData, paginationParams = {}) {
    try {
      const result = await modelRepository.manageProductModel({
        action: 5, // Get List
        productModelId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        productCategoryId: null,
        modelName: null,
        description: null,
        productImages: null,
        defaultRent: null,
        defaultDeposit: null,
        defaultWarrantyDays: null,
        totalQuantity: null,
        availableQuantity: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      // Apply pagination on the result
      const allModels = result.data || [];
      const total = allModels.length;
      const page = paginationParams.page || 1;
      const limit = paginationParams.limit || 50;
      const totalPages = Math.ceil(total / limit);
      const startIndex = (page - 1) * limit;
      const endIndex = startIndex + limit;
      const paginatedModels = allModels.slice(startIndex, endIndex);

      return {
        success: result.success,
        message: result.message,
        data: {
          models: paginatedModels,
          pagination: {
            page: page,
            limit: limit,
            total: total,
            total_pages: totalPages,
            has_next: page < totalPages,
            has_prev: page > 1,
          },
        },
      };
    } catch (error) {
      logger.error("ModelService.listModels error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== DELETE MODEL ========================
  async deleteModel(productModelId, userData) {
    try {
      const result = await modelRepository.manageProductModel({
        action: 3, // Delete
        productModelId: productModelId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        productCategoryId: null,
        modelName: null,
        description: null,
        productImages: null,
        defaultRent: null,
        defaultDeposit: null,
        defaultWarrantyDays: null,
        totalQuantity: null,
        availableQuantity: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { product_model_id: productModelId } : null,
      };
    } catch (error) {
      logger.error("ModelService.deleteModel error", {
        error: error.message,
      });
      throw error;
    }
  }
}

module.exports = new ModelService();
