const db = require('../../../database/connection');
const logger = require('../../../config/logger.config');

class ModelRepository {
  async manageProductModel(params) {
    try {
      // Execute Stored Procedure - need to convert JSON array to string
      const productImagesJson = params.productModelImages
        ? JSON.stringify(params.productModelImages)
        : null;

      await db.executeSP(
        'CALL sp_action_manage_product_model(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, @p_success, @p_id, @p_data, @p_error_code, @p_error_message)',
        [
          params.action,
          params.productModelId,
          params.businessId,
          params.branchId,
          params.productSegmentId,
          params.productCategoryId,
          params.modelName,
          params.description,
          productImagesJson,
          params.defaultRent,
          params.defaultDeposit,
          params.defaultWarrantyDays,
          params.totalQuantity,
          params.availableQuantity,
          params.userId,
          params.roleId,
        ],
      );

      // Read OUT parameters
      const output = await db.executeSelect(
        `SELECT 
          @p_success AS success,
          @p_id AS product_model_id,
          @p_data AS data,
          @p_error_code AS error_code,
          @p_error_message AS error_message`,
      );

      const success = output.success == 1;

      // JSON parsing if data returned
      let parsedData = null;
      if (output.data) {
        try {
          parsedData =
            typeof output.data === 'string'
              ? JSON.parse(output.data)
              : output.data;
        } catch (err) {
          logger.warn('Failed to parse product model JSON', {
            error: err.message,
          });
          parsedData = [];
        }
      }

      if (!success) {
        logger.warn('Stored procedure returned error', {
          action: params.action,
          errorCode: output.error_code,
          errorMessage: output.error_message,
        });
      }

      return {
        success,
        productModelId: output.product_model_id,
        data: parsedData,
        errorCode: output.error_code,
        message: output.error_message || 'Operation completed',
      };
    } catch (error) {
      logger.error('ModelRepository.manageProductModel error', {
        action: params.action,
        error: error.message,
      });

      return {
        success: false,
        productModelId: null,
        data: null,
        errorCode: 'ERR_DATABASE_ERROR',
        message: error.message || 'Unexpected database error occurred.',
      };
    }
  }
}

module.exports = new ModelRepository();
