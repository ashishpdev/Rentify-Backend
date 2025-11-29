// Repository layer - Database operations
const crypto = require("crypto");
const dbConnection = require("../../database/connection");

class AuthRepository {
  // ========================= SAVE OTP OPERATIONS ==================
  async saveOTP(otpData) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        // Call stored procedure to send OTP
        await connection.query(
          `CALL sp_send_otp(?, ?, ?, ?, ?, @p_otp_id, @p_expires_at, @p_error_message)`,
          [
            otpData.targetIdentifier,
            otpData.otpCodeHash,
            otpData.otp_type_id,
            otpData.expiryMinutes,
            otpData.ipAddress || null,
          ]
        );

        // Get output variables
        const [outputRows] = await connection.query(
          "SELECT @p_otp_id as otp_id, @p_expires_at as expires_at, @p_error_message as error_message"
        );

        if (outputRows.length > 0) {
          const output = outputRows[0];

          if (!output.otp_id || output.error_message !== "Success") {
            throw new Error(output.error_message || "Failed to save OTP");
          }

          return {
            id: output.otp_id,
            targetIdentifier: otpData.targetIdentifier,
            expiresAt: output.expires_at,
          };
        }

        throw new Error("Failed to retrieve stored procedure output");
      } finally {
        connection.release();
      }
    } catch (error) {
      throw new Error(`Failed to save OTP: ${error.message}`);
    }
  }

  // ======================== VERIFY OTP OPERATION ===================
  async verifyOTP(email, otpCodeHash, otp_type_id) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        // Call stored procedure to verify OTP
        await connection.query(
          `CALL sp_verify_otp(?, ?, ?, @p_verified, @p_otp_id, @p_error_message)`,
          [email, otpCodeHash, otp_type_id]
        );

        // Get output variables
        const [outputRows] = await connection.query(
          "SELECT @p_verified as verified, @p_otp_id as otp_id, @p_error_message as error_message"
        );

        if (outputRows.length > 0) {
          const output = outputRows[0];

          if (!output.verified) {
            throw new Error(output.error_message || "OTP verification failed");
          }

          return {
            verified: output.verified === 1 || output.verified === true,
            otpId: output.otp_id,
          };
        }

        throw new Error("Failed to retrieve stored procedure output");
      } finally {
        connection.release();
      }
    } catch (error) {
      throw new Error(`Failed to verify OTP: ${error.message}`);
    }
  }

  // // ==================== COMPLETE REGISTRATION =====================
  // async emailExists(email) {
  //   try {
  //     const pool = dbConnection.getMasterPool();
  //     const connection = await pool.getConnection();

  //     try {
  //       const [rows] = await connection.query(
  //         "SELECT master_user_id FROM master_user WHERE email = ? AND is_deleted = 0 LIMIT 1",
  //         [email]
  //       );

  //       return rows.length > 0;
  //     } finally {
  //       connection.release();
  //     }
  //   } catch (error) {
  //     throw new Error(`Failed to check email existence: ${error.message}`);
  //   }
  // }

  // ================ REGISTER BUSINESS WITH OWNER ==================
  async registerBusinessWithOwner(registrationData) {
    let connection;
    try {
      const pool = dbConnection.getMasterPool();
      connection = await pool.getConnection();

      try {
        // Call stored procedure with proper parameter mapping
        await connection.query(
          `CALL sp_register_business_branch_owner(
            ?, ?, ?, ?, ?, ?, ?, ?, @p_business_id, @p_branch_id, @p_owner_id, @p_error_message
          )`,
          [
            registrationData.businessName,
            registrationData.businessEmail,
            registrationData.ownerName,
            registrationData.ownerContactNumber,
            registrationData.ownerName,
            registrationData.ownerEmail,
            registrationData.ownerContactNumber,
            registrationData.ownerName, // p_created_by
          ]
        );

        // Get output variables from the stored procedure
        const [outputRows] = await connection.query(
          "SELECT @p_business_id as business_id, @p_branch_id as branch_id, @p_owner_id as owner_id, @p_error_message as error_message"
        );

        if (!outputRows || outputRows.length === 0) {
          throw new Error("Failed to retrieve stored procedure output");
        }

        const output = outputRows[0];
        console.log("[SP Output]", output);

        // Validate error message from SP
        if (!output.error_message) {
          throw new Error("No error message returned from stored procedure");
        }

        if (output.error_message !== "Success") {
          throw new Error(output.error_message);
        }

        // Validate that all IDs were returned and are valid
        const businessId = output.business_id;
        const branchId = output.branch_id;
        const ownerId = output.owner_id;

        if (!businessId || businessId <= 0) {
          throw new Error("Invalid business ID returned from procedure");
        }

        if (!branchId || branchId <= 0) {
          throw new Error("Invalid branch ID returned from procedure");
        }

        if (!ownerId || ownerId <= 0) {
          throw new Error("Invalid owner ID returned from procedure");
        }

        return {
          businessId: businessId,
          branchId: branchId,
          ownerId: ownerId,
        };
      } finally {
        connection.release();
      }
    } catch (error) {
      throw new Error(`Failed to register business: ${error.message}`);
    }
  }

  // ======================== LOGIN WITH OTP ========================
  async loginWithOTP(email, ipAddress = null, userAgent = null) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        // Call stored procedure with IP and User Agent
        await connection.query(
          `CALL sp_login_with_otp(?, ?, ?, @p_user_id, @p_business_id, @p_branch_id, @p_role_id, @p_is_owner, @p_user_name, @p_contact_number, @p_business_name, @p_session_token, @p_error_message)`,
          [email, ipAddress || null, userAgent || null]
        );

        // Get output variables - ADD session_token here
        const [outputRows] = await connection.query(
          "SELECT @p_user_id as user_id, @p_business_id as business_id, @p_branch_id as branch_id, @p_role_id as role_id, @p_is_owner as is_owner, @p_user_name as user_name, @p_contact_number as contact_number, @p_business_name as business_name, @p_session_token as session_token, @p_error_message as error_message"
        );

        if (outputRows.length > 0) {
          const output = outputRows[0];

          if (!output.user_id || output.error_message !== "Login successful") {
            throw new Error(
              output.error_message || "Failed to login: User not found"
            );
          }

          return {
            user_id: output.user_id,
            business_id: output.business_id,
            branch_id: output.branch_id,
            role_id: output.role_id,
            is_owner: output.is_owner === 1 || output.is_owner === true,
            user_name: output.user_name,
            contact_number: output.contact_number,
            business_name: output.business_name,
            session_token: output.session_token, // ADD THIS
          };
        }

        throw new Error("Failed to retrieve login data from database");
      } finally {
        connection.release();
      }
    } catch (error) {
      throw new Error(`Failed to login: ${error.message}`);
    }
  }
}

module.exports = new AuthRepository();
