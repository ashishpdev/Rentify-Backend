// tests/helpers/test-utils.js
const AccessTokenUtil = require('../../src/utils/access_token.util');
const SessionTokenUtil = require('../../src/utils/session_token.util');

/**
 * Generate test authentication tokens
 * @param {number} businessId - Business ID for token
 * @param {number} roleId - Role ID for token
 * @returns {Object} - Object containing accessToken and sessionToken
 */
function generateTestTokens(businessId = 1, roleId = 1) {
  const mockData = {
    user_id: 1,
    business_id: businessId,
    branch_id: 1,
    role_id: roleId,
    email: 'test@example.com',
    contact_number: '1234567890',
    user_name: 'Test User',
    business_name: `Test Business ${businessId}`,
    branch_name: 'Main Branch',
    role_name: roleId === 1 ? 'Owner' : 'Manager',
    is_owner: roleId === 1
  };

  const { accessToken } = AccessTokenUtil.generateAccessToken(mockData);
  const { sessionToken } = SessionTokenUtil.generateSessionToken({
    ...mockData,
    device_id: `test_device_${Date.now()}`,
    ip_address: '127.0.0.1'
  });

  return { accessToken, sessionToken };
}

/**
 * Generate unique test email
 * @returns {string} - Unique email address
 */
function generateTestEmail() {
  return `test_${Date.now()}_${Math.random().toString(36).substring(7)}@example.com`;
}

/**
 * Wait for specified milliseconds
 * @param {number} ms - Milliseconds to wait
 * @returns {Promise}
 */
function wait(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Create test customer data
 * @returns {Object} - Customer data object
 */
function createTestCustomerData() {
  return {
    first_name: 'Test',
    last_name: 'Customer',
    email: generateTestEmail(),
    contact_number: '1234567890',
    address_line: '123 Test Street',
    city: 'Test City',
    state: 'Test State',
    country: 'Test Country',
    pincode: '123456'
  };
}

/**
 * Create test segment data
 * @returns {Object} - Segment data object
 */
function createTestSegmentData() {
  return {
    code: `TEST_SEG_${Date.now()}`,
    name: 'Test Segment',
    description: 'Test segment description'
  };
}

module.exports = {
  generateTestTokens,
  generateTestEmail,
  wait,
  createTestCustomerData,
  createTestSegmentData
};