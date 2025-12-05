const db = require("../../database/connection");
const logger = require("../../config/logger.config");

class CustomerRepository {
  async manageCustomer(params) {
    try {
      // Stored Procedure call
      await db.executeSP(
        `CALL sp_manage_customer(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 
          @p_success, @p_id, @p_data, @p_error_code, @p_error_message)`,
        [
          params.action,
          params.customerId,
          params.businessId,
          params.branchId,
          params.firstName,
          params.lastName,
          params.email,
          params.contactNumber,
          params.addressLine,
          params.city,
          params.state,
          params.country,
          params.pincode,
          params.userId,
          params.userId
        ]
      );

      // Fetch OUT parameters
      const output = await db.executeSelect(
        `SELECT 
          @p_success AS success,
          @p_id AS customer_id,
          @p_data AS data,
          @p_error_code AS error_code,
          @p_error_message AS error_message`
      );

      const success = (output.success == 1);

      // Parse JSON response if provided
      let parsedData = null;
      if (output.data) {
        try {
          parsedData = typeof output.data === "string" ? JSON.parse(output.data) : output.data;
        } catch (err) {
          logger.warn("Failed to parse customer data JSON", { error: err.message });
          parsedData = [];
        }
      }

      if (!success) {
        logger.warn("Stored procedure returned error", {
          action: params.action,
          errorCode: output.error_code,
          errorMessage: output.error_message
        });
      }

      return {
        success,
        customerId: output.customer_id,
        data: parsedData,
        errorCode: output.error_code,
        message: output.error_message || "Operation completed"
      };

    } catch (err) {
      logger.error("CustomerRepository.manageCustomer error", {
        action: params.action,
        error: err.message
      });

      return {
        success: false,
        customerId: null,
        data: null,
        errorCode: "ERR_DATABASE_ERROR",
        message: err.message || "Unexpected database error occurred."
      };
    }
  }
}

module.exports = new CustomerRepository();
