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
   * Save OTP to database
   * @param {Object} otpData - OTP data
   * @param {string} otpData.targetIdentifier - Email or phone
   * @param {string} otpData.otpCode - Raw OTP code
   * @param {string} otpData.otpType - OTP type (REGISTER, VERIFY_EMAIL, etc)
   * @param {number} otpData.expiryMinutes - OTP expiry in minutes
   * @param {string} otpData.ipAddress - IP address of requester
   * @returns {Object} - OTP record with id
   */
  async saveOTP(otpData) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        const otpId = crypto.randomUUID();
        const otpCodeHash = this.generateOTPHash(otpData.otpCode);
        const expiresAt = new Date(Date.now() + otpData.expiryMinutes * 60000);

        // Get OTP type ID
        const [otpTypeRows] = await connection.query(
          "SELECT master_otp_type_id FROM master_otp_type WHERE code = ? AND is_deleted = 0",
          [otpData.otpType]
        );

        if (otpTypeRows.length === 0) {
          throw new Error(`Invalid OTP type: ${otpData.otpType}`);
        }

        const otpTypeId = otpTypeRows[0].master_otp_type_id;

        // Insert OTP record
        await connection.query(
          `INSERT INTO master_otp 
          (id, target_identifier, otp_code_hash, otp_type_id, expires_at, ip_address, created_by)
          VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [
            otpId,
            otpData.targetIdentifier,
            otpCodeHash,
            otpTypeId,
            expiresAt,
            otpData.ipAddress || null,
            "system",
          ]
        );

        return {
          id: otpId,
          targetIdentifier: otpData.targetIdentifier,
          expiresAt,
        };
      } finally {
        connection.release();
      }
    } catch (error) {
      throw new Error(`Failed to save OTP: ${error.message}`);
    }
  }

  /**
   * Get pending OTP by email and type
   * @param {string} email - Email address
   * @param {string} otpType - OTP type code
   * @returns {Object|null} - OTP record or null
   */
  async getPendingOTP(email, otpType) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        const [rows] = await connection.query(
          `SELECT mo.* FROM master_otp mo
          JOIN master_otp_type mot ON mo.otp_type_id = mot.master_otp_type_id
          WHERE mo.target_identifier = ? 
          AND mot.code = ?
          AND mo.verified_at IS NULL
          AND mo.expires_at > NOW()
          AND mo.attempts < mo.max_attempts
          ORDER BY mo.created_at DESC
          LIMIT 1`,
          [email, otpType]
        );

        return rows.length > 0 ? rows[0] : null;
      } finally {
        connection.release();
      }
    } catch (error) {
      throw new Error(`Failed to get pending OTP: ${error.message}`);
    }
  }

  /**
   * Verify OTP code
   * @param {string} otpId - OTP record ID
   * @param {string} otpCode - Raw OTP code to verify
   * @returns {boolean} - True if OTP is valid
   */
  async verifyOTP(otpId, otpCode) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        const otpCodeHash = this.generateOTPHash(otpCode);

        // Get OTP record
        const [rows] = await connection.query(
          `SELECT * FROM master_otp 
          WHERE id = ? 
          AND expires_at > NOW()
          AND verified_at IS NULL
          AND attempts < max_attempts`,
          [otpId]
        );

        if (rows.length === 0) {
          return false;
        }

        const otpRecord = rows[0];

        // Verify hash
        if (otpRecord.otp_code_hash !== otpCodeHash) {
          // Increment attempts
          await connection.query(
            "UPDATE master_otp SET attempts = attempts + 1 WHERE id = ?",
            [otpId]
          );
          return false;
        }

        // Mark as verified
        await connection.query(
          "UPDATE master_otp SET verified_at = NOW(), updated_at = NOW() WHERE id = ?",
          [otpId]
        );

        return true;
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
   * @returns {Object} - Response with business_id, branch_id, user_id
   */
  async registerBusinessWithOwner(registrationData) {
    try {
      const pool = dbConnection.getMasterPool();
      const connection = await pool.getConnection();

      try {
        // Call stored procedure
        const [result] = await connection.query(
          `CALL sp_register_business_with_owner(
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, @p_business_id, @p_branch_id, @p_user_id, @p_error_message
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
            "system",
          ]
        );

        // Get output variables
        const [outputRows] = await connection.query(
          "SELECT @p_business_id as business_id, @p_branch_id as branch_id, @p_user_id as user_id, @p_error_message as error_message"
        );

        if (outputRows.length > 0) {
          const output = outputRows[0];

          if (!output.business_id || !output.user_id || !output.branch_id) {
            throw new Error(output.error_message || "Failed to create business");
          }

          return {
            businessId: output.business_id,
            branchId: output.branch_id,
            userId: output.user_id,
          };
        }

        throw new Error("Failed to retrieve stored procedure output");
      } finally {
        connection.release();
      }
    } catch (error) {
      throw new Error(`Failed to register business: ${error.message}`);
    }
  }
}

module.exports = new AuthRepository();