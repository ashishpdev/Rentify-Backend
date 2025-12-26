// src/modules/products/asset/asset.service.js
const assetRepository = require("./asset.repository");
const logger = require("../../../config/logger.config");

class AssetService {
  // ======================== CREATE ASSET ========================
  async createAsset(assetData, userData) {
    try {
      const result = await assetRepository.manageAsset({
        action: 1,
        assetId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productModelId: assetData.product_model_id,
        serialNumber: assetData.serial_number,
        assetTag: assetData.asset_tag || null,
        productStatusId: assetData.product_status_id,
        productConditionId: assetData.product_condition_id,
        rentPrice: assetData.rent_price || null,
        sellPrice: assetData.sell_price || null,
        sourceTypeId: assetData.source_type_id,
        borrowedFromBusinessName: assetData.borrowed_from_business_name || null,
        borrowedFromBranchName: assetData.borrowed_from_branch_name || null,
        purchaseDate: assetData.purchase_date || null,
        purchasePrice: assetData.purchase_price || null,
        currentValue: assetData.current_value || null,
        // Asset-specific fields
        upperBodyMeasurement: assetData.upper_body_measurement || null,
        lowerBodyMeasurement: assetData.lower_body_measurement || null,
        sizeRange: assetData.size_range || null,
        colorName: assetData.color_name || null,
        fabricType: assetData.fabric_type || null,
        movementCategory: assetData.movement_category || null,
        manufacturingDate: assetData.manufacturing_date || null,
        manufacturingCost: assetData.manufacturing_cost || null,
        // Measurements
        chestCm: assetData.chest_cm || null,
        waistCm: assetData.waist_cm || null,
        hipCm: assetData.hip_cm || null,
        shoulderCm: assetData.shoulder_cm || null,
        sleeveLengthCm: assetData.sleeve_length_cm || null,
        lengthCm: assetData.length_cm || null,
        inseamCm: assetData.inseam_cm || null,
        neckCm: assetData.neck_cm || null,
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
        action: 2,
        assetId: assetData.asset_id,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productModelId: assetData.product_model_id,
        serialNumber: assetData.serial_number,
        assetTag: assetData.asset_tag || null,
        productStatusId: assetData.product_status_id,
        productConditionId: assetData.product_condition_id,
        rentPrice: assetData.rent_price || null,
        sellPrice: assetData.sell_price || null,
        sourceTypeId: assetData.source_type_id,
        borrowedFromBusinessName: assetData.borrowed_from_business_name || null,
        borrowedFromBranchName: assetData.borrowed_from_branch_name || null,
        purchaseDate: assetData.purchase_date || null,
        purchasePrice: assetData.purchase_price || null,
        currentValue: assetData.current_value || null,
        // Asset-specific fields
        upperBodyMeasurement: assetData.upper_body_measurement || null,
        lowerBodyMeasurement: assetData.lower_body_measurement || null,
        sizeRange: assetData.size_range || null,
        colorName: assetData.color_name || null,
        fabricType: assetData.fabric_type || null,
        movementCategory: assetData.movement_category || null,
        manufacturingDate: assetData.manufacturing_date || null,
        manufacturingCost: assetData.manufacturing_cost || null,
        // Measurements
        chestCm: assetData.chest_cm || null,
        waistCm: assetData.waist_cm || null,
        hipCm: assetData.hip_cm || null,
        shoulderCm: assetData.shoulder_cm || null,
        sleeveLengthCm: assetData.sleeve_length_cm || null,
        lengthCm: assetData.length_cm || null,
        inseamCm: assetData.inseam_cm || null,
        neckCm: assetData.neck_cm || null,
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
        action: 4,
        assetId: assetId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productModelId: null,
        serialNumber: null,
        assetTag: null,
        productStatusId: null,
        productConditionId: null,
        rentPrice: null,
        sellPrice: null,
        sourceTypeId: null,
        borrowedFromBusinessName: null,
        borrowedFromBranchName: null,
        purchaseDate: null,
        purchasePrice: null,
        currentValue: null,
        upperBodyMeasurement: null,
        lowerBodyMeasurement: null,
        sizeRange: null,
        colorName: null,
        fabricType: null,
        movementCategory: null,
        manufacturingDate: null,
        manufacturingCost: null,
        chestCm: null,
        waistCm: null,
        hipCm: null,
        shoulderCm: null,
        sleeveLengthCm: null,
        lengthCm: null,
        inseamCm: null,
        neckCm: null,
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
        action: 5,
        assetId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productModelId: null,
        serialNumber: null,
        assetTag: null,
        productStatusId: null,
        productConditionId: null,
        rentPrice: null,
        sellPrice: null,
        sourceTypeId: null,
        borrowedFromBusinessName: null,
        borrowedFromBranchName: null,
        purchaseDate: null,
        purchasePrice: null,
        currentValue: null,
        upperBodyMeasurement: null,
        lowerBodyMeasurement: null,
        sizeRange: null,
        colorName: null,
        fabricType: null,
        movementCategory: null,
        manufacturingDate: null,
        manufacturingCost: null,
        chestCm: null,
        waistCm: null,
        hipCm: null,
        shoulderCm: null,
        sleeveLengthCm: null,
        lengthCm: null,
        inseamCm: null,
        neckCm: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      // Apply pagination
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
        action: 3,
        assetId: assetId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productModelId: null,
        serialNumber: null,
        assetTag: null,
        productStatusId: null,
        productConditionId: null,
        rentPrice: null,
        sellPrice: null,
        sourceTypeId: null,
        borrowedFromBusinessName: null,
        borrowedFromBranchName: null,
        purchaseDate: null,
        purchasePrice: null,
        currentValue: null,
        upperBodyMeasurement: null,
        lowerBodyMeasurement: null,
        sizeRange: null,
        colorName: null,
        fabricType: null,
        movementCategory: null,
        manufacturingDate: null,
        manufacturingCost: null,
        chestCm: null,
        waistCm: null,
        hipCm: null,
        shoulderCm: null,
        sleeveLengthCm: null,
        lengthCm: null,
        inseamCm: null,
        neckCm: null,
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