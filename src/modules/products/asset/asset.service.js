// src/modules/products/asset/asset.service.js
const assetRepository = require("./asset.repository");
const logger = require("../../../config/logger.config");

class AssetService {
  // ======================== CREATE ASSET ========================
  async createAsset(assetData, userData) {
    try {
      const result = await assetRepository.manageAsset({
        action: 1, // Create
        assetId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: assetData.product_segment_id,
        productCategoryId: assetData.product_category_id,
        productModelId: assetData.product_model_id,
        serialNumber: assetData.serial_number,
        productImages: assetData.product_images || null,
        productStatusId: assetData.product_status_id,
        productConditionId: assetData.product_condition_id,
        productRentalStatusId: assetData.product_rental_status_id,
        purchasePrice: assetData.purchase_price || null,
        purchaseDate: assetData.purchase_date || null,
        currentValue: assetData.current_value || null,
        rentPrice: assetData.rent_price || null,
        depositAmount: assetData.deposit_amount || null,
        sourceTypeId: assetData.source_type_id,
        borrowedFromBusinessName: assetData.borrowed_from_business_name || null,
        borrowedFromBranchName: assetData.borrowed_from_branch_name || null,
        purchaseBillUrl: assetData.purchase_bill_url || null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { asset_id: result.assetId } : null,
      };
    } catch (error) {
      logger.error("AssetService.createAsset error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== UPDATE ASSET ========================
  async updateAsset(assetData, userData) {
    try {
      const result = await assetRepository.manageAsset({
        action: 2, // Update
        assetId: assetData.asset_id,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: assetData.product_segment_id,
        productCategoryId: assetData.product_category_id,
        productModelId: assetData.product_model_id,
        serialNumber: assetData.serial_number,
        productImages: assetData.product_images || null,
        productStatusId: assetData.product_status_id,
        productConditionId: assetData.product_condition_id,
        productRentalStatusId: assetData.product_rental_status_id,
        purchasePrice: assetData.purchase_price || null,
        purchaseDate: assetData.purchase_date || null,
        currentValue: assetData.current_value || null,
        rentPrice: assetData.rent_price || null,
        depositAmount: assetData.deposit_amount || null,
        sourceTypeId: assetData.source_type_id,
        borrowedFromBusinessName: assetData.borrowed_from_business_name || null,
        borrowedFromBranchName: assetData.borrowed_from_branch_name || null,
        purchaseBillUrl: assetData.purchase_bill_url || null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { asset_id: assetData.asset_id } : null,
      };
    } catch (error) {
      logger.error("AssetService.updateAsset error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== GET ASSET ========================
  async getAsset(assetId, userData) {
    try {
      const result = await assetRepository.manageAsset({
        action: 4, // Get Single
        assetId: assetId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        productCategoryId: null,
        productModelId: null,
        serialNumber: null,
        productImages: null,
        productStatusId: null,
        productConditionId: null,
        productRentalStatusId: null,
        purchasePrice: null,
        purchaseDate: null,
        currentValue: null,
        rentPrice: null,
        depositAmount: null,
        sourceTypeId: null,
        borrowedFromBusinessName: null,
        borrowedFromBranchName: null,
        purchaseBillUrl: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      if (!result.success || !result.data) {
        return {
          success: false,
          message: "Asset not found",
          data: null,
        };
      }

      return {
        success: true,
        message: "Asset retrieved successfully",
        data: { asset: result.data },
      };
    } catch (error) {
      logger.error("AssetService.getAsset error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== LIST ASSETS ========================
  async listAssets(userData, paginationParams = {}) {
    try {
      const result = await assetRepository.manageAsset({
        action: 5, // Get List
        assetId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        productCategoryId: null,
        productModelId: null,
        serialNumber: null,
        productImages: null,
        productStatusId: null,
        productConditionId: null,
        productRentalStatusId: null,
        purchasePrice: null,
        purchaseDate: null,
        currentValue: null,
        rentPrice: null,
        depositAmount: null,
        sourceTypeId: null,
        borrowedFromBusinessName: null,
        borrowedFromBranchName: null,
        purchaseBillUrl: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      // Apply pagination on the result
      const allAssets = result.data || [];
      const total = allAssets.length;
      const page = paginationParams.page || 1;
      const limit = paginationParams.limit || 50;
      const totalPages = Math.ceil(total / limit);
      const startIndex = (page - 1) * limit;
      const endIndex = startIndex + limit;
      const paginatedAssets = allAssets.slice(startIndex, endIndex);

      return {
        success: result.success,
        message: result.message,
        data: {
          assets: paginatedAssets,
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
      logger.error("AssetService.listAssets error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== DELETE ASSET ========================
  async deleteAsset(assetId, userData) {
    try {
      const result = await assetRepository.manageAsset({
        action: 3, // Delete
        assetId: assetId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        productCategoryId: null,
        productModelId: null,
        serialNumber: null,
        productImages: null,
        productStatusId: null,
        productConditionId: null,
        productRentalStatusId: null,
        purchasePrice: null,
        purchaseDate: null,
        currentValue: null,
        rentPrice: null,
        depositAmount: null,
        sourceTypeId: null,
        borrowedFromBusinessName: null,
        borrowedFromBranchName: null,
        purchaseBillUrl: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { asset_id: assetId } : null,
      };
    } catch (error) {
      logger.error("AssetService.deleteAsset error", {
        error: error.message,
      });
      throw error;
    }
  }
}

module.exports = new AssetService();