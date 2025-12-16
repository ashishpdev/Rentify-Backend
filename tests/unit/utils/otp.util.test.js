// tests/unit/utils/otp.util.test.js
const OtpUtil = require('../../../src/utils/otp.util'); // Adjust path to your actual file

describe('OTP Utility Unit Tests', () => {
  
  test('generateOTP should return a string of specified length', () => {
    const length = 6;
    const otp = OtpUtil.generateOTP(length);
    
    expect(typeof otp).toBe('string');
    expect(otp).toHaveLength(length);
    // Ensure it contains only digits
    expect(otp).toMatch(/^[0-9]+$/);
  });

  test('generateOTP should default to length 4 if not specified', () => {
    // Assuming your implementation has a default
    const otp = OtpUtil.generateOTP(); 
    expect(otp.length).toBeGreaterThanOrEqual(4);
  });

  test('validateOTP should return true for valid, non-expired OTP', () => {
    // Mocking a scenario where you compare input vs stored hash
    // This depends on your specific implementation (e.g., bcrypt compare)
    const isValid = OtpUtil.compareOTP('123456', '123456');
    expect(isValid).toBe(true);
  });

  test('validateOTP should return false for mismatch', () => {
    const isValid = OtpUtil.compareOTP('123456', '654321');
    expect(isValid).toBe(false);
  });
});