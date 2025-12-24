const db = require("../../../database/connection");
const logger = require("../../../config/logger.config");

class SegmentRepository {
  async manageProductSegment(params) {
    try {
      // Execute Stored Procedure
      await db.executeSP(
        `CALL sp_manage_product_segment(?, ?, ?, ?, ?, ?, ?, ?, ?, 
          @p_success, @p_id, @p_data, @p_error_code, @p_error_message)`,
        [
          params.action,
          params.productSegmentId,
          params.businessId,
          params.branchId,
          params.code,
          params.name,
          params.description,
          params.userId,
          params.roleId
        ]
      );

      // Read OUT params
      const output = await db.executeSelect(
        `SELECT 
          @p_success AS success,
          @p_id AS product_segment_id,
          @p_data AS data,
          @p_error_code AS error_code,
          @p_error_message AS error_message`
      );

      const success = (output.success == 1);

      // Parse JSON response
      let parsedData = null;
      if (output.data) {
        try {
          parsedData = typeof output.data === "string"
            ? JSON.parse(output.data)
            : output.data;
        } catch (err) {
          logger.warn("Failed to parse product segment JSON", { error: err.message });
          parsedData = null;
        }
      }

      if (!success) {
        logger.warn("Stored procedure returned error", {
          action: params.action,
          errorCode: output.error_code,
          errorMessage: output.error_message,
        });
      }

      return {
        success,
        productSegmentId: output.product_segment_id || null,
        data: parsedData,
        errorCode: output.error_code || null,
        message: output.error_message || null
      };

    } catch (error) {
      logger.error("SegmentRepository.manageProductSegment error", {
        action: params.action,
        error: error.message
      });

      return {
        success: false,
        productSegmentId: null,
        data: null,
        errorCode: "ERR_DATABASE_ERROR",
        message: error.message || "Unexpected database error occurred."
      };
    }
  }
}

module.exports = new SegmentRepository();
