// Authentication repository layer - Database operations
const crypto = require("crypto");
const dbConnection = require("../../database/connection");

class AuthRepository {
  /**
   * Generate OTP hash
   * @param {string} otp - The OTP code
   * @returns {string} - Hashed OTP
   */
  generateOTPHash(otp) {
    return crypto.createHash("sha256").update(otp).digest("hex");
  }

  /**
   * Save OTP to database using stored procedure
   * @param {Object} otpData - OTP data
   * @param {string} otpData.targetIdentifier - Email
   * @param {string} otpData.otpCodeHash - Hashed OTP code
   * @param {string} otpData.otpType - OTP type (REGISTER, VERIFY_EMAIL, etc)
   * @param {number} otpData.expiryMinutes - OTP expiry in minutes
   * @param {string} otpData.ipAddress - IP address of requester
   * @returns {Object} - OTP record with id and expiry
   */
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
            otpData.otpType,
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

  /**
   * Verify OTP code using stored procedure
   * @param {string} email - Email address
   * @param {string} otpCodeHash - Hashed OTP code
   * @param {string} otpType - OTP type code
   * @returns {Object} - { verified: boolean, otpId: string }
   */
  async verifyOTP(email, otpCodeHash, otpType) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        // Call stored procedure to verify OTP
        await connection.query(
          `CALL sp_verify_otp(?, ?, ?, @p_verified, @p_otp_id, @p_error_message)`,
          [email, otpCodeHash, otpType]
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

  /**
   * Check if email is already verified in system
   * @param {string} email - Email to check
   * @returns {boolean} - True if email exists
   */
  async emailExists(email) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        const [rows] = await connection.query(
          "SELECT master_user_id FROM master_user WHERE email = ? AND is_deleted = 0 LIMIT 1",
          [email]
        );

        return rows.length > 0;
      } finally {
        connection.release();
      }
    } catch (error) {
      throw new Error(`Failed to check email existence: ${error.message}`);
    }
  }

  /**
   * Execute stored procedure to register business with owner
   * @param {Object} registrationData - Registration data
   * @returns {Object} - Response with business_id, branch_id, owner_id
   */
  async registerBusinessWithOwner(registrationData) {
    let connection;
    try {
      const pool = dbConnection.getMasterPool();
      connection = await pool.getConnection();

      try {
        // Call stored procedure with proper parameter mapping
        await connection.query(
          `CALL sp_register_business_with_owner(
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, @p_business_id, @p_branch_id, @p_owner_id, @p_error_message
          )`,
          [
            registrationData.businessName,
            registrationData.businessEmail,
            registrationData.website || null,
            registrationData.contactPerson,
            registrationData.contactNumber,
            registrationData.addressLine,
            registrationData.city,
            registrationData.state,
            registrationData.country || "India",
            registrationData.pincode,
            registrationData.subscriptionType || "TRIAL",
            registrationData.billingCycle || "MONTHLY",
            registrationData.ownerName,
            registrationData.ownerEmail,
            registrationData.ownerContactNumber,
            registrationData.ownerRole || "OWNER",
            registrationData.contactPerson, // p_created_by
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
}

module.exports = new AuthRepository();