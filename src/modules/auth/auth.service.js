// service -- Business logic / orchestration
const authRepository = require("./auth.repository");
const EmailService = require("../../services/email.service");
const TokenUtil = require("../../utils/access_token.util");
const OTPUtil = require("../../utils/otp.util");
const dbConnection = require("../../database/connection");
const logger = require("../../config/logger.config");
const {
  DatabaseError,
  AuthenticationError,
} = require("../../utils/errors.util");
const {
  SESSION_OPERATIONS,
  TOKEN_HEADERS,
} = require("../../constants/operations");
const fs = require("fs");
const path = require("path");
const handlebars = require("handlebars");

class AuthService {
  async _renderOtpTemplate({ otpCode, email, expiryMinutes = 10 }) {
    const filePath = path.join(__dirname, "../../templates/emailOtpHtml.hbs");
    const source = fs.readFileSync(filePath, "utf8");
    const template = handlebars.compile(source);
    return template({ otpCode, email, EXPIRY_MIN: expiryMinutes });
  }

  // ======================== SEND OTP EMAIL ========================
  async sendVerificationCode(email, otp, expiryMinutes = 10) {
    const html = await this._renderOtpTemplate({
      otpCode: otp,
      email,
      expiryMinutes,
    });

    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: "Rentify - OTP Verification",
      html,
    };

    // EmailService.sendMail returns Promise
    const info = await EmailService.sendMail(mailOptions);
    return info;
  }

  // ========================= OTP SERVICES =========================
  async sendOTP(email, otp_type_id, options = {}) {
    const { ipAddress = null } = options;

    try {
      const otpCode = OTPUtil.generateOTP();
      const otpCodeHash = OTPUtil.hashOTP(otpCode);

      const otpRecord = await authRepository.saveOTP({
        targetIdentifier: email,
        otpCodeHash,
        otp_type_id,
        expiryMinutes: 10,
        ipAddress,
      });

      // send email (fire and await - if email fails we bubble up)
      await this.sendVerificationCode(email, otpCode, 10);

      console.log(
        `[OTP] Email: ${email}, Type ID: ${otp_type_id}, Code: ${otpCode}, ID: ${otpRecord.id}`
      );

      return {
        otpId: otpRecord.id,
        message: `OTP sent successfully to ${email}`,
        expiresAt: otpRecord.expiresAt,
      };
    } catch (err) {
      // Re-throw with original error message from repository/SP
      throw err;
    }
  }

  // ======================== VERIFY OTP CODE =======================
  async verifyOTP(email, otpCode, otp_type_id) {
    try {
      const hash = OTPUtil.hashOTP(otpCode);
      const result = await authRepository.verifyOTP(email, hash, otp_type_id);

      if (!result || !result.success) {
        throw new Error("Invalid or expired OTP");
      }
      return true;
    } catch (err) {
      // Re-throw the original error message without wrapping
      throw err;
    }
  }

  // ===================== COMPLETE REGISTRATION ====================
  async completeRegistration(registrationData) {
    try {
      // // Check if owner email already exists
      // const ownerExists = await authRepository.emailExists(
      //   registrationData.ownerEmail
      // );
      // if (ownerExists) {
      //   throw new Error("Owner email already registered");
      // }

      const created = await authRepository.registerBusinessWithOwner(
        registrationData
      );

      if (!created.businessId || !created.branchId || !created.ownerId) {
        throw new Error("Invalid IDs returned from registration");
      }

      return {
        businessId: created.businessId,
        branchId: created.branchId,
        ownerId: created.ownerId,
        message: "Business registered successfully",
      };
    } catch (err) {
      throw new Error(`Failed to complete registration: ${err.message}`);
    }
  }

  // ======================== LOGIN WITH OTP ========================
  async loginWithOTP(
    email,
    otpCode,
    otp_type_id,
    ipAddress = null,
    userAgent = null
  ) {
    try {
      // Hash the OTP code
      const hash = OTPUtil.hashOTP(otpCode);

      // Login with OTP - verification happens inside the stored procedure
      const user = await authRepository.loginWithOTP(
        email,
        hash,
        ipAddress,
        userAgent
      );

      if (!user || !user.user_id) {
        throw new Error("Failed to retrieve user information");
      }

      return {
        user_id: user.user_id,
        business_id: user.business_id,
        branch_id: user.branch_id,
        role_id: user.role_id,
        is_owner: user.is_owner,
        user_name: user.user_name,
        contact_number: user.contact_number,
        business_name: user.business_name,
        session_token: user.session_token,
      };
    } catch (err) {
      // Re-throw the original error message without wrapping
      throw err;
    }
  }

  // ======================== EXTEND SESSION ========================
  async extendSession(userId, sessionToken) {
    let connection;
    try {
      if (!userId || !sessionToken) {
        throw new AuthenticationError("User ID and session token are required");
      }

      connection = await dbConnection.getMasterPool().getConnection();

      await connection.query(
        `CALL sp_manage_session(?, ?, ?, NULL, NULL, @p_is_success, @p_session_token_out, @p_expiry_at, @p_error_message)`,
        [SESSION_OPERATIONS.UPDATE, userId, sessionToken]
      );

      const [outputRows] = await connection.query(
        "SELECT @p_is_success as is_success, @p_expiry_at as expiry_at, @p_error_message as error_message"
      );

      if (!outputRows || outputRows.length === 0) {
        throw new DatabaseError("Failed to retrieve extend session output");
      }

      const output = outputRows[0];

      return {
        isSuccess: output.is_success === 1 || output.is_success === true,
        expiryAt: output.expiry_at,
        errorMessage: output.error_message,
      };
    } catch (error) {
      if (error.statusCode) {
        throw error;
      }
      logger.error("AuthService.extendSession error", {
        userId,
        error: error.message,
      });
      throw new DatabaseError(
        `Failed to extend session: ${error.message}`,
        error
      );
    } finally {
      if (connection) {
        try {
          connection.release();
        } catch (releaseError) {
          logger.warn("Error releasing database connection", {
            error: releaseError.message,
          });
        }
      }
    }
  }

  // ======================== LOGOUT ========================
  async logout(userId) {
    let connection;
    try {
      if (!userId) {
        throw new AuthenticationError("User ID is required");
      }

      connection = await dbConnection.getMasterPool().getConnection();

      await connection.query(
        `CALL sp_manage_session(?, ?, ?, NULL, NULL, @p_is_success, @p_session_token_out, @p_expiry_at, @p_error_message)`,
        [SESSION_OPERATIONS.DELETE, userId, null]
      );

      const [outputRows] = await connection.query(
        "SELECT @p_is_success as is_success, @p_error_message as error_message"
      );

      if (!outputRows || outputRows.length === 0) {
        throw new DatabaseError("Failed to retrieve logout output");
      }

      const output = outputRows[0];

      return {
        isSuccess: output.is_success === 1 || output.is_success === true,
        errorMessage: output.error_message,
      };
    } catch (error) {
      if (error.statusCode) {
        throw error;
      }
      logger.error("AuthService.logout error", {
        userId,
        error: error.message,
      });
      throw new DatabaseError(`Failed to logout: ${error.message}`, error);
    } finally {
      if (connection) {
        try {
          connection.release();
        } catch (releaseError) {
          logger.warn("Error releasing database connection", {
            error: releaseError.message,
          });
        }
      }
    }
  }
}

module.exports = new AuthService();
