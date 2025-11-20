// Authentication service layer
const authRepository = require("./auth.repository");
// const emailService = require("../../services/email.service");

class AuthService {
  /**
   * Generate a random 6-digit OTP
   * @returns {string} - 6-digit OTP
   */
  generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  /**
   * Send OTP to user email
   * @param {string} email - User email
   * @param {string} otpType - OTP type (REGISTER, VERIFY_EMAIL, etc)
   * @param {Object} options - Additional options
   * @returns {Promise<Object>} - OTP record
   */
  async sendOTP(email, otpType, options = {}) {
    const { ipAddress = null } = options;

    try {
      // Check if OTP already exists for this email/type
      const existingOTP = await authRepository.getPendingOTP(email, otpType);

      if (existingOTP) {
        // Check if we should resend (allow resend after 30 seconds)
        const createdAt = new Date(existingOTP.created_at);
        const now = new Date();
        const secondsElapsed = (now - createdAt) / 1000;

        if (secondsElapsed < 30) {
          throw new Error(
            "Please wait before requesting a new OTP. Try again in 30 seconds."
          );
        }
      }

      // Generate OTP
      const otpCode = this.generateOTP();

      // Save OTP to database
      const otpRecord = await authRepository.saveOTP({
        targetIdentifier: email,
        otpCode,
        otpType,
        expiryMinutes: 10, // 10 minutes validity
        ipAddress,
      });

      // Send OTP via email
      // TODO: EMAIL FUNCTIONALITY IS NOT AVAILABLE YET
      //   await emailService.sendOTP(email, otpCode, otpType);
      // Temporarily logging OTP for testing purposes
      console.log(
        `[OTP] Email: ${email}, Type: ${otpType}, Code: ${otpCode}, ID: ${otpRecord.id}`
      );

      return {
        otpId: otpRecord.id,
        message: `OTP sent successfully to ${email}`,
        expiresAt: otpRecord.expiresAt,
      };
    } catch (error) {
      throw new Error(`Failed to send OTP: ${error.message}`);
    }
  }

  /**
   * Verify OTP code
   * @param {string} otpId - OTP ID
   * @param {string} otpCode - OTP code provided by user
   * @returns {Promise<boolean>} - True if verification successful
   */
  async verifyOTP(otpId, otpCode) {
    try {
      const isValid = await authRepository.verifyOTP(otpId, otpCode);

      if (!isValid) {
        throw new Error("Invalid or expired OTP");
      }

      return true;
    } catch (error) {
      throw new Error(`Failed to verify OTP: ${error.message}`);
    }
  }

  /**
   * Complete registration by creating business and owner
   * @param {Object} registrationData - Registration data
   * @returns {Promise<Object>} - Success response with IDs
   */
  async completeRegistration(registrationData) {
    try {
      // Check if business email already exists
      const businessExists = await authRepository.emailExists(
        registrationData.businessEmail
      );

      if (businessExists) {
        throw new Error("Business email already registered");
      }

      // Check if owner email already exists
      const ownerExists = await authRepository.emailExists(
        registrationData.ownerEmail
      );

      if (ownerExists) {
        throw new Error("Owner email already registered");
      }

      // Register business with owner via stored procedure
      const result = await authRepository.registerBusinessWithOwner(
        registrationData
      );

      return {
        businessId: result.businessId,
        branchId: result.branchId,
        userId: result.userId,
        message: "Business registered successfully",
      };
    } catch (error) {
      throw new Error(`Failed to complete registration: ${error.message}`);
    }
  }
}

module.exports = new AuthService();