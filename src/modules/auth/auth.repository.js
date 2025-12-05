// src/repository/auth.repository.js
const db = require("../../database/connection");

class AuthRepository {

  // ========================= SAVE OTP =========================
  async saveOTP(otpData) {
    try {
      await db.executeSP(
        `CALL sp_manage_otp(?, ?, ?, ?, ?, ?, ?, @p_success, @p_id, @p_expires_at, @p_otp_code_hash_out, @p_error_code, @p_error_message)`,
        [
          1,
          otpData.targetIdentifier,
          otpData.otpCodeHash,
          otpData.otp_type_id,
          otpData.expiryMinutes || null,
          otpData.ipAddress || null,
          otpData.createdBy || "system",
        ]
      );

      const out = await db.executeSelect(`
        SELECT @p_success p_success, @p_id p_id, @p_expires_at p_expires_at,
               @p_error_code p_error_code, @p_error_message p_error_message
      `);

      if (!(out.p_success == 1)) throw new Error(`${out.p_error_code}: ${out.p_error_message}`);

      return {
        success: true,
        id: out.p_id,
        expiresAt: out.p_expires_at
      };
    } catch (err) { throw new Error(`Failed to save OTP: ${err.message}`); }
  }

  // ======================== VERIFY OTP ========================
  async verifyOTP(email, otpCodeHash, otp_type_id) {
    try {
      await db.executeSP(
        `CALL sp_action_verify_otp(?, ?, ?, @p_success, @p_otp_id, @p_error_code, @p_error_message)`,
        [email, otpCodeHash, otp_type_id]
      );

      const out = await db.executeSelect(`
        SELECT @p_success success, @p_otp_id otp_id, @p_error_code error_code, @p_error_message error_message
      `);

      if (!(out.success == 1)) throw new Error(`${out.error_code}: ${out.error_message}`);

      return { success: true, otpId: out.otp_id };
    } catch (e) { throw new Error(`Failed to verify OTP: ${e.message}`); }
  }

  // ============ REGISTER BUSINESS + BRANCH + OWNER ============
  async registerBusinessWithOwner(d) {
    try {
      await db.executeSP(
        `CALL sp_action_register_business_branch_owner(
          ?, ?, ?, ?, ?, ?, ?, ?, @p_success, @p_business_id, @p_branch_id, @p_owner_id, @p_error_code, @p_error_message
        )`,
        [
          d.businessName, d.businessEmail, d.ownerName, d.ownerContactNumber,
          d.ownerName, d.ownerEmail, d.ownerContactNumber, d.ownerName,
        ]
      );

      const out = await db.executeSelect(`
        SELECT @p_success success, @p_business_id business_id, @p_branch_id branch_id,
               @p_owner_id owner_id, @p_error_code error_code, @p_error_message error_message
      `);

      if (!(out.success == 1)) throw new Error(`${out.error_code}: ${out.error_message}`);

      return { success: true, businessId: out.business_id, branchId: out.branch_id, ownerId: out.owner_id };
    } catch (e) { throw new Error(`Failed to register business: ${e.message}`); }
  }

  // ======================== LOGIN WITH OTP ========================
  async loginWithOTP(email, otpHash, ip = null) {
    try {
      await db.executeSP(
        `CALL sp_action_login_with_otp(?, ?, ?, @p_user_id, @p_business_id, @p_branch_id, @p_role_id, @p_is_owner, @p_user_name, @p_contact_number, @p_business_name, @p_error_message)`,
        [email, otpHash, ip]
      );

      const out = await db.executeSelect(`
        SELECT @p_user_id user_id, @p_business_id business_id,
               @p_branch_id branch_id, @p_role_id role_id, @p_is_owner is_owner,
               @p_user_name user_name, @p_contact_number contact_number,
               @p_business_name business_name, @p_error_message error_message
      `);

      if (!out.user_id) throw new Error(out.error_message || "Login failed");

      return {
        user_id: out.user_id,
        business_id: out.business_id,
        branch_id: out.branch_id,
        role_id: out.role_id,
        is_owner: !!out.is_owner,
        user_name: out.user_name,
        contact_number: out.contact_number,
        business_name: out.business_name
      };
    } catch (e) { throw new Error(`Failed to login: ${e.message}`); }
  }

  // ======================== CREATE SESSION ========================
  async createSession(userId, token, expiry, ip = null) {
    try {
      await db.executeSP(
        `CALL sp_manage_session(1, ?, ?, ?, ?, ?, @p_success, @p_session_token_out, @p_expiry_at, @p_error_code, @p_error_message)`,
        [userId, token, ip, expiry, null]
      );

      const out = await db.executeSelect(`
        SELECT @p_success success, @p_session_token_out session_token,
               @p_expiry_at expiry_at, @p_error_code error_code, @p_error_message error_message
      `);

      return { isSuccess: out.success == 1, sessionToken: out.session_token, expiryAt: out.expiry_at };
    } catch (e) { throw new Error(`Failed to create session: ${e.message}`); }
  }

  // ======================== EXTEND SESSION ========================
  async extendSession(userId, oldToken, newToken, newExpiry) {
    try {
      await db.executeSP(
        `CALL sp_manage_session(2, ?, ?, ?, ?, ?, @p_success, @p_session_token_out, @p_expiry_at, @p_error_code, @p_error_message)`,
        [userId, newToken, null, newExpiry, oldToken]
      );

      const out = await db.executeSelect(`
        SELECT @p_success success, @p_session_token_out session_token,
               @p_expiry_at expiry_at, @p_error_code error_code, @p_error_message error_message
      `);

      if (!(out.success == 1)) throw new Error(out.error_message);

      return { isSuccess: true, sessionToken: out.session_token, expiryAt: out.expiry_at };
    } catch (e) { throw new Error(`Failed to extend session: ${e.message}`); }
  }

  // ======================== LOGOUT ========================
  async logout(userId) {
    try {
      await db.executeSP(
        `CALL sp_manage_session(3, ?, ?, ?, ?, ?, @p_success, @p_session_token_out, @p_expiry_at, @p_error_code, @p_error_message)`,
        [userId, null, null, null, null]
      );

      const out = await db.executeSelect(`
        SELECT @p_success success, @p_error_code error_code, @p_error_message error_message
      `);

      if (!(out.success == 1)) throw new Error(`${out.error_code}: ${out.error_message}`);

      return { success: true };
    } catch (e) { throw new Error(`Failed to logout: ${e.message}`); }
  }
}

module.exports = new AuthRepository();
