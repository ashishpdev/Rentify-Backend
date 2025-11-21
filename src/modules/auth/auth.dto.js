// Authentication Data Transfer Objects

/**
 * Send OTP Request DTO
 */
class SendOTPDTO {
  constructor(email, otpType) {
    this.email = email;
    this.otpType = otpType;
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
    this.website = data.website;
    this.contactPerson = data.contactPerson;
    this.contactNumber = data.contactNumber;
    this.addressLine = data.addressLine;
    this.city = data.city;
    this.state = data.state;
    this.country = data.country || "India";
    this.pincode = data.pincode;
    this.subscriptionType = data.subscriptionType || "TRIAL";
    this.billingCycle = data.billingCycle || "MONTHLY";
    this.ownerName = data.ownerName;
    this.ownerEmail = data.ownerEmail;
    this.ownerContactNumber = data.ownerContactNumber;
    this.ownerRole = data.ownerRole || "OWNER";
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