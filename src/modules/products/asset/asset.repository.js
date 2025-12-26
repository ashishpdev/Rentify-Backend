const db = require("../../../database/connection");
const logger = require("../../../config/logger.config");

class AssetRepository {
  async manageAsset(params) {
    try {
      // Call Stored Procedure - Exactly 35 IN parameters
      await db.executeSP(
        `CALL sp_manage_asset(
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
          ?, ?, ?, ?, ?,
          @p_success, @p_id, @p_data, @p_error_code, @p_error_message
        )`,
        [
          // 1-5: Core identifiers
          params.action,
          params.assetId,
          params.businessId,
          params.branchId,
          params.productModelId,
          
          // 6-9: Basic asset info
          params.serialNumber,
          params.assetTag,
          params.productStatusId,
          params.productConditionId,
          
          // 10-17: Pricing and source
          params.rentPrice,
          params.sellPrice,
          params.sourceTypeId,
          params.borrowedFromBusinessName,
          params.borrowedFromBranchName,
          params.purchaseDate,
          params.purchasePrice,
          params.currentValue,
          
          // 18-25: Asset-specific fields
          params.upperBodyMeasurement,
          params.lowerBodyMeasurement,
          params.sizeRange,
          params.colorName,
          params.fabricType,
          params.movementCategory,
          params.manufacturingDate,
          params.manufacturingCost,
          
          // 26-33: Detailed measurements
          params.chestCm,
          params.waistCm,
          params.hipCm,
          params.shoulderCm,
          params.sleeveLengthCm,
          params.lengthCm,
          params.inseamCm,
          params.neckCm,
          
          // 34-35: User context
          params.userId,
          params.roleId,
        ]
      );

      // Get OUT Params Response
      const output = await db.executeSelect(
        `SELECT 
          @p_success AS success,
          @p_id AS asset_id,
          @p_data AS data,
          @p_error_code AS error_code,
          @p_error_message AS error_message`
      );

      const success = output.success == 1;

      // Convert JSON if exists
      let parsedData = null;
      if (output.data) {
        try {
          parsedData =
            typeof output.data === "string"
              ? JSON.parse(output.data)
              : output.data;
        } catch (err) {
          logger.warn("Failed to parse asset JSON", { error: err.message });
          parsedData = [];
        }
      }

      // Log error condition
      if (!success) {
        logger.warn("Stored procedure returned error", {
          action: params.action,
          errorCode: output.error_code,
          errorMessage: output.error_message,
        });
      }

      return {
        success,
        assetId: output.asset_id,
        data: parsedData,
        errorCode: output.error_code,
        message: output.error_message || "Operation completed",
      };
    } catch (error) {
      logger.error("AssetRepository.manageAsset error", {
        action: params.action,
        error: error.message,
      });

      return {
        success: false,
        assetId: null,
        data: null,
        errorCode: "ERR_DATABASE_ERROR",
        message: error.message || "Unexpected database error occurred.",
      };
    }
  }
}

module.exports = new AssetRepository();