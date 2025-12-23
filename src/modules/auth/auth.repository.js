// src/modules/auth/auth.repository.js
const db = require("../../database/connection");

class AuthRepository {
  // ========================= OTP MANAGEMENT =========================
  async saveOTP(otpData) {
    try {
      await db.executeSP(
        `CALL sp_manage_otp(?, ?, ?, ?, ?, ?, ?, @p_success, @p_id, @p_expires_at, @p_error_code, @p_error_message)`,
        [
          1, // action: 1=Create
          otpData.targetIdentifier,
          otpData.otpCodeHash,
          otpData.otp_type_id,
          otpData.expiryMinutes || 10,
          otpData.ipAddress || null,
          otpData.createdBy || "system",
        ]
      );

      const output = await db.executeSelect(`
        SELECT @p_success AS success, @p_id AS id, @p_expires_at AS expires_at,
               @p_error_code AS error_code, @p_error_message AS error_message
      `);

      if (!(output.success == 1)) {
        throw new Error(`${output.error_code}: ${output.error_message}`);
      }

      return {
        success: true,
        id: output.id,
        expiresAt: output.expires_at,
      };
    } catch (error) {
      throw new Error(`Failed to save OTP: ${error.message}`);
    }
  }

  async verifyOTP(email, otpCodeHash, otp_type_id) {
    try {
      await db.executeSP(
        `CALL sp_action_verify_otp(?, ?, ?, @p_success, @p_otp_id, @p_error_code, @p_error_message)`,
        [email, otpCodeHash, otp_type_id]
      );

      const output = await db.executeSelect(`
        SELECT @p_success AS success, @p_otp_id AS otp_id, 
               @p_error_code AS error_code, @p_error_message AS error_message
      `);

      if (!(output.success == 1)) {
        throw new Error(`${output.error_code}: ${output.error_message}`);
      }

      return { success: true, otpId: output.otp_id };
    } catch (error) {
      throw new Error(`Failed to verify OTP: ${error.message}`);
    }
  }

  // ========================= REGISTRATION =========================
  async registerBusinessWithOwner(registrationData) {
    try {
      await db.executeSP(
        `CALL sp_action_register_business_branch_owner(?, ?, ?, ?, ?, ?, ?, ?, 
         @p_success, @p_business_id, @p_branch_id, @p_owner_id, @p_error_code, @p_error_message)`,
        [
          registrationData.businessName,
          registrationData.businessEmail,
          registrationData.ownerName,
          registrationData.ownerContactNumber,
          registrationData.ownerName,
          registrationData.ownerEmail,
          registrationData.ownerContactNumber,
          registrationData.ownerName,
        ]
      );

      const output = await db.executeSelect(`
        SELECT @p_success AS success, @p_business_id AS business_id, 
               @p_branch_id AS branch_id, @p_owner_id AS owner_id,
               @p_error_code AS error_code, @p_error_message AS error_message
      `);

      if (!(output.success == 1)) {
        throw new Error(`${output.error_code}: ${output.error_message}`);
      }

      return {
        success: true,
        businessId: output.business_id,
        branchId: output.branch_id,
        ownerId: output.owner_id,
      };
    } catch (error) {
      throw new Error(`Failed to register business: ${error.message}`);
    }
  }

  // ========================= LOGIN =========================
  async loginWithOTP(email, otpHash, ipAddress = null) {
    try {
      await db.executeSP(
        `CALL sp_action_login_with_otp(?, ?, ?, 
         @p_user_id, @p_business_id, @p_branch_id, @p_role_id, @p_contact_number, 
         @p_user_name, @p_business_name, @p_branch_name, @p_role_name, @p_is_owner, 
         @p_error_code, @p_error_message)`,
        [email, otpHash, ipAddress]
      );

      const output = await db.executeSelect(`
        SELECT @p_user_id AS user_id, @p_business_id AS business_id,
               @p_branch_id AS branch_id, @p_role_id AS role_id,
               @p_contact_number AS contact_number, @p_user_name AS user_name,
               @p_business_name AS business_name, @p_branch_name AS branch_name,
               @p_role_name AS role_name, @p_is_owner AS is_owner,
               @p_error_code AS error_code, @p_error_message AS error_message
      `);

      if (!output.user_id) {
        throw new Error(output.error_message || "Login failed");
      }

      return {
        user_id: output.user_id,
        business_id: output.business_id,
        branch_id: output.branch_id,
        role_id: output.role_id,
        email: email,
        contact_number: output.contact_number,
        user_name: output.user_name,
        business_name: output.business_name,
        branch_name: output.branch_name,
        role_name: output.role_name,
        is_owner: !!output.is_owner,
      };
    } catch (error) {
      throw new Error(`Failed to login: ${error.message}`);
    }
  }

  /**
   * FIXED: Get user credentials using stored procedure
   */
  async getUserCredentials(email) {
    try {
      await db.executeSP(
        `CALL sp_get_user_credentials(?, 
         @p_user_id, @p_business_id, @p_branch_id, @p_role_id, @p_hash_password,
         @p_contact_number, @p_user_name, @p_locked_until, @p_user_active, @p_is_owner,
         @p_business_name, @p_business_active, @p_branch_name, @p_role_name,
         @p_error_code, @p_error_message)`,
        [email]
      );

      const output = await db.executeSelect(`
        SELECT @p_user_id AS user_id, @p_business_id AS business_id,
               @p_branch_id AS branch_id, @p_role_id AS role_id,
               @p_hash_password AS hash_password, @p_contact_number AS contact_number,
               @p_user_name AS user_name, @p_locked_until AS locked_until,
               @p_user_active AS user_active, @p_is_owner AS is_owner,
               @p_business_name AS business_name, @p_business_active AS business_active,
               @p_branch_name AS branch_name, @p_role_name AS role_name,
               @p_error_code AS error_code, @p_error_message AS error_message
      `);

      if (!output.user_id) {
        return null;
      }

      return {
        user_id: output.user_id,
        business_id: output.business_id,
        branch_id: output.branch_id,
        role_id: output.role_id,
        email: email,
        hash_password: output.hash_password,
        contact_number: output.contact_number,
        user_name: output.user_name,
        locked_until: output.locked_until,
        user_active: !!output.user_active,
        is_owner: !!output.is_owner,
        business_name: output.business_name,
        business_active: !!output.business_active,
        branch_name: output.branch_name,
        role_name: output.role_name,
      };
    } catch (error) {
      throw new Error(`Failed to get user credentials: ${error.message}`);
    }
  }

  /**
   * FIXED: Update last login using stored procedure
   */
  async updateLastLogin(userId, ipAddress = null) {
    try {
      await db.executeSP(
        `CALL sp_update_last_login(?, ?, @p_success, @p_error_code, @p_error_message)`,
        [userId, ipAddress]
      );

      const output = await db.executeSelect(`
        SELECT @p_success AS success, @p_error_code AS error_code,
               @p_error_message AS error_message
      `);

      if (!(output.success == 1)) {
        throw new Error(`${output.error_code}: ${output.error_message}`);
      }

      return { success: true };
    } catch (error) {
      throw new Error(`Failed to update last login: ${error.message}`);
    }
  }

  // ========================= SESSION MANAGEMENT =========================
  async createSession(
    userId,
    sessionToken,
    expiryAt,
    ipAddress = null,
    deviceId = null,
    deviceName = null,
    deviceTypeId = 1
  ) {
    try {
      await db.executeSP(
        `CALL sp_manage_session(?, ?, ?, ?, ?, ?, ?, ?, 
         @p_success, @p_session_id, @p_error_code, @p_error_message)`,
        [
          1, // action: 1=Create
          userId,
          sessionToken,
          deviceId,
          deviceName,
          deviceTypeId,
          ipAddress,
          expiryAt,
        ]
      );

      const output = await db.executeSelect(`
        SELECT @p_success AS success, @p_session_id AS session_id,
               @p_error_code AS error_code, @p_error_message AS error_message
      `);

      return {
        isSuccess: output.success == 1,
        sessionId: output.session_id,
        sessionToken: sessionToken,
        expiryAt: expiryAt,
        errorCode: output.error_code,
        errorMessage: output.error_message,
      };
    } catch (error) {
      throw new Error(`Failed to create session: ${error.message}`);
    }
  }

  async extendSession(userId, oldSessionToken, newSessionToken, newExpiryAt) {
    try {
      await db.executeSP(
        `CALL sp_manage_session(?, ?, ?, ?, ?, ?, ?, ?, 
         @p_success, @p_session_id, @p_error_code, @p_error_message)`,
        [
          2, // action: 2=Update
          userId,
          newSessionToken,
          null,
          null,
          null,
          null,
          newExpiryAt,
        ]
      );

      const output = await db.executeSelect(`
        SELECT @p_success AS success, @p_session_id AS session_id,
               @p_error_code AS error_code, @p_error_message AS error_message
      `);

      if (!(output.success == 1)) {
        throw new Error(`${output.error_code}: ${output.error_message}`);
      }

      return {
        isSuccess: true,
        sessionId: output.session_id,
        sessionToken: newSessionToken,
        expiryAt: newExpiryAt,
      };
    } catch (error) {
      throw new Error(`Failed to extend session: ${error.message}`);
    }
  }

  async deleteSession(userId, sessionToken = null) {
    try {
      await db.executeSP(
        `CALL sp_manage_session(?, ?, ?, ?, ?, ?, ?, ?, 
         @p_success, @p_session_id, @p_error_code, @p_error_message)`,
        [
          3, // action: 3=Delete
          userId,
          sessionToken,
          null,
          null,
          null,
          null,
          null,
        ]
      );

      const output = await db.executeSelect(`
        SELECT @p_success AS success, @p_error_code AS error_code, 
               @p_error_message AS error_message
      `);

      if (!(output.success == 1)) {
        throw new Error(`${output.error_code}: ${output.error_message}`);
      }

      return { success: true };
    } catch (error) {
      throw new Error(`Failed to delete session: ${error.message}`);
    }
  }

  async logout(userId) {
    return this.deleteSession(userId, null);
  }

  // ========================= PASSWORD MANAGEMENT =========================
  
  /**
   * FIXED: Get stored password hash using stored procedure
   */
  async getStoredPasswordHash(userId) {
    try {
      await db.executeSP(
        `CALL sp_get_password_hash(?, @p_hash_password, @p_is_active, @p_error_code, @p_error_message)`,
        [userId]
      );

      const output = await db.executeSelect(`
        SELECT @p_hash_password AS hash_password, @p_is_active AS is_active,
               @p_error_code AS error_code, @p_error_message AS error_message
      `);

      if (!output.hash_password) {
        return null;
      }

      return {
        hash_password: output.hash_password,
        is_active: !!output.is_active,
      };
    } catch (error) {
      throw new Error(`Failed to get password hash: ${error.message}`);
    }
  }

  /**
   * FIXED: Update password hash using stored procedure
   */
  async updatePasswordHash(userId, newPasswordHash, updatedBy) {
    try {
      await db.executeSP(
        `CALL sp_update_password_hash(?, ?, ?, @p_success, @p_error_code, @p_error_message)`,
        [userId, newPasswordHash, updatedBy]
      );

      const output = await db.executeSelect(`
        SELECT @p_success AS success, @p_error_code AS error_code,
               @p_error_message AS error_message
      `);

      if (!(output.success == 1)) {
        throw new Error(`${output.error_code}: ${output.error_message}`);
      }

      return { success: true };
    } catch (error) {
      throw new Error(`Failed to update password: ${error.message}`);
    }
  }

  /**
   * FIXED: Reset password with OTP using stored procedures
   */
  async resetPasswordWithOTP(email, newPasswordHash, updatedBy) {
    try {
      // Step 1: Get user by email
      await db.executeSP(
        `CALL sp_get_user_by_email(?, @p_user_id, @p_is_active, @p_error_code, @p_error_message)`,
        [email]
      );

      const userOutput = await db.executeSelect(`
        SELECT @p_user_id AS user_id, @p_is_active AS is_active,
               @p_error_code AS error_code, @p_error_message AS error_message
      `);

      if (!userOutput.user_id) {
        throw new Error(userOutput.error_message || 'User not found');
      }

      if (!userOutput.is_active) {
        throw new Error('Account is inactive');
      }

      // Step 2: Update password
      await db.executeSP(
        `CALL sp_update_password_hash(?, ?, ?, @p_success, @p_error_code, @p_error_message)`,
        [userOutput.user_id, newPasswordHash, updatedBy]
      );

      const updateOutput = await db.executeSelect(`
        SELECT @p_success AS success, @p_error_code AS error_code,
               @p_error_message AS error_message
      `);

      if (!(updateOutput.success == 1)) {
        throw new Error(`${updateOutput.error_code}: ${updateOutput.error_message}`);
      }

      return { success: true, userId: userOutput.user_id };
    } catch (error) {
      throw new Error(`Failed to reset password: ${error.message}`);
    }
  }
}

module.exports = new AuthRepository();