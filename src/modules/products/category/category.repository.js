// src/modules/products/category/category.repository.js
const db = require("../../../database/connection");
const logger = require("../../../config/logger.config");

class CategoryRepository {
  async manageProductCategory(params) {
    try {
      // Execute Stored Procedure with OUT variables
      await db.executeSP(
        `CALL sp_manage_product_category(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 
          @p_success, @p_id, @p_data, @p_error_code, @p_error_message)`,
        [
          params.action,
          params.productCategoryId,
          params.businessId,
          params.branchId,
          params.productSegmentId,
          params.code,
          params.name,
          params.description,
          params.userId,
          params.roleId,
        ]
      );

      // Fetch output variables
      const outputRows = await db.executeSelect(
        `SELECT 
          @p_success AS success,
          @p_id AS product_category_id,
          @p_data AS data,
          @p_error_code AS error_code,
          @p_error_message AS error_message`
      );

      // outputRows is expected to be a single-row result object
      const output =
        Array.isArray(outputRows) && outputRows.length
          ? outputRows[0]
          : outputRows;

      const success =
        output && (output.success == 1 || output.success === true);

      // JSON parse if data exists
      let parsedData = null;
      if (output && output.data) {
        try {
          parsedData =
            typeof output.data === "string"
              ? JSON.parse(output.data)
              : output.data;
        } catch (err) {
          logger.warn("Failed to parse product category JSON", {
            error: err.message,
          });
          parsedData = null;
        }
      }

      if (!success) {
        logger.warn("Stored procedure returned error", {
          action: params.action,
          errorCode: output ? output.error_code : null,
          errorMessage: output ? output.error_message : null,
        });
      }

      return {
        success,
        productCategoryId: output ? output.product_category_id : null,
        data: parsedData,
        errorCode: output ? output.error_code : null,
        message: output ? output.error_message : null,
      };
    } catch (error) {
      logger.error("CategoryRepository.manageProductCategory error", {
        action: params.action,
        error: error.message,
      });

      return {
        success: false,
        productCategoryId: null,
        data: null,
        errorCode: "ERR_DATABASE_ERROR",
        message: error.message || "Unexpected database error occurred.",
      };
    }
  }
}

module.exports = new CategoryRepository();
