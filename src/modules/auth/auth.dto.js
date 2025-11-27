// Authentication Data Transfer Objects

/**
 * Send OTP Request DTO
 */
class SendOTPDTO {
  constructor(email, otp_type_id) {
    this.email = email;
    this.otp_type_id = otp_type_id;
  }
}

/**
 * Verify OTP Request DTO
 */
class VerifyOTPDTO {
  constructor(otpId, otpCode) {
    this.otpId = otpId;
    this.otpCode = otpCode;
  }
}

/**
 * Complete Registration Request DTO
 */
class CompleteRegistrationDTO {
  constructor(data) {
    this.businessName = data.businessName;
    this.businessEmail = data.businessEmail;
    this.contactPerson = data.ownerName; // Map ownerName to contactPerson
    this.contactNumber = data.ownerContactNumber; // Map ownerContactNumber to contactNumber
    this.ownerName = data.ownerName;
    this.ownerEmail = data.ownerEmail;
    this.ownerContactNumber = data.ownerContactNumber;
  }
}

/**
 * Send OTP Response DTO
 */
class SendOTPResponseDTO {
  constructor(otpId, email, expiresAt) {
    this.otpId = otpId;
    this.email = email;
    this.expiresAt = expiresAt;
    this.message = `OTP sent successfully to ${email}`;
  }
}

/**
 * Verify OTP Response DTO
 */
class VerifyOTPResponseDTO {
  constructor(verified = true) {
    this.verified = verified;
    this.message = "OTP verified successfully";
  }
}

/**
 * Registration Success Response DTO
 */
class RegistrationSuccessDTO {
  constructor(ownerId, businessId, branchId) {
    this.ownerId = ownerId;
    this.businessId = businessId;
    this.branchId = branchId;
    this.message = "Business registered successfully";
  }
}

module.exports = {
  SendOTPDTO,
  VerifyOTPDTO,
  CompleteRegistrationDTO,
  SendOTPResponseDTO,
  VerifyOTPResponseDTO,
  RegistrationSuccessDTO,
};