// src/modules/products/model/model.repository.js
const dbConnection = require("../../../database/connection");
const logger = require("../../../config/logger.config");

class ModelRepository {
  async manageProductModel(params) {
    const pool = dbConnection.getMasterPool();
    const connection = await pool.getConnection();

    try {
      // Call stored procedure with OUT parameters
      await connection.query(
        `CALL sp_manage_product_model(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, @p_success, @p_id, @p_data, @p_error_code, @p_error_message)`,
        [
          params.action,
          params.productModelId,
          params.businessId,
          params.branchId,
          params.productSegmentId,
          params.productCategoryId,
          params.modelName,
          params.description,
          params.productImages,
          params.defaultRent,
          params.defaultDeposit,
          params.defaultWarrantyDays,
          params.totalQuantity,
          params.availableQuantity,
          params.userId,
          params.roleId,
        ]
      );

      // Get output variables
      const [outputRows] = await connection.query(
        `SELECT 
          @p_success AS success,
          @p_id AS product_model_id,
          @p_data AS data,
          @p_error_code AS error_code,
          @p_error_message AS error_message`
      );

      const output = outputRows && outputRows[0] ? outputRows[0] : {};

      const success =
        output.success === 1 ||
        output.success === "1" ||
        output.success === true;

      // Parse JSON data if present (for GET actions)
      let parsedData = null;
      if (output.data) {
        try {
          parsedData =
            typeof output.data === "string"
              ? JSON.parse(output.data)
              : output.data;
        } catch (parseError) {
          logger.warn("Failed to parse product model data JSON", {
            error: parseError.message,
          });
          parsedData = [];
        }
      }

      // Log the stored procedure response for debugging
      if (!success) {
        logger.warn("Stored procedure returned error", {
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
        message: output.error_message || "Operation completed",
      };
    } catch (error) {
      logger.error("ModelRepository.manageProductModel error", {
        action: params.action,
        error: error.message,
        stack: error.stack,
      });
      // Return error in consistent format instead of throwing
      return {
        success: false,
        productModelId: null,
        data: null,
        errorCode: "ERR_DATABASE_ERROR",
        message: error.message || "Unexpected database error occurred.",
      };
    } finally {
      if (connection) connection.release();
    }
  }
}

module.exports = new ModelRepository();
