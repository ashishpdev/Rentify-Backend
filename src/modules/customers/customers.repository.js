// src/modules/customers/customers.repository.js
const dbConnection = require("../../database/connection");
const logger = require("../../config/logger.config");

class CustomerRepository {
  async manageCustomer(params) {
    const pool = dbConnection.getMasterPool();
    const connection = await pool.getConnection();

    try {
      // Call stored procedure with OUT parameters
      await connection.query(
        `CALL sp_manage_customer(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, @p_success, @p_id, @p_data, @p_error_code, @p_error_message)`,
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
          params.userId, // p_role_user same as p_user
        ]
      );

      // Get output variables
      const [outputRows] = await connection.query(
        `SELECT 
          @p_success AS success,
          @p_id AS customer_id,
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
          logger.warn("Failed to parse customer data JSON", {
            error: parseError.message,
          });
          parsedData = [];
        }
      }

      return {
        success,
        customerId: output.customer_id,
        data: parsedData,
        errorCode: output.error_code,
        message: output.error_message || "Operation completed",
      };
    } catch (error) {
      logger.error("CustomerRepository.manageCustomer error", {
        action: params.action,
        error: error.message,
      });
      throw error;
    } finally {
      if (connection) connection.release();
    }
  }
}

module.exports = new CustomerRepository();