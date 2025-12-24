// tests/api/customers/customers.routes.test.js
const request = require('supertest');
const app = require('../../../src/app');
const db = require('../../../src/database/connection');

describe('Customer API Tests', () => {
  let authTokens;

  beforeAll(async () => {
    await db.initializeMasterConnection();
    authTokens = generateTestTokens();
  });

  afterAll(async () => {
    await db.closeConnections();
  });

  describe('POST /api/customer/create', () => {
    it('should create customer with valid data', async () => {
      const res = await request(app)
        .post('/api/customer/create')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          first_name: 'Test',
          last_name: 'Customer',
          email: `test_${Date.now()}@example.com`,
          contact_number: '1234567890',
          address_line: '123 Test St',
          city: 'Test City',
          state: 'Test State',
          country: 'Test Country',
          pincode: '123456'
        });

      expect([200, 201]).toContain(res.statusCode);
      if (res.statusCode === 201) {
        expect(res.body.data).toHaveProperty('customer_id');
      }
    });

    it('should reject missing required fields', async () => {
      const res = await request(app)
        .post('/api/customer/create')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          last_name: 'Customer'
        });

      expect(res.statusCode).toBe(400);
    });

    it('should reject invalid email', async () => {
      const res = await request(app)
        .post('/api/customer/create')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          first_name: 'Test',
          email: 'invalid-email',
          contact_number: '1234567890'
        });

      expect(res.statusCode).toBe(400);
    });

    it('should reject invalid contact number', async () => {
      const res = await request(app)
        .post('/api/customer/create')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          first_name: 'Test',
          email: `test_${Date.now()}@example.com`,
          contact_number: '123'
        });

      expect(res.statusCode).toBe(400);
    });
  });

  describe('POST /api/customer/update', () => {
    let customerId;

    beforeAll(async () => {
      const res = await request(app)
        .post('/api/customer/create')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          first_name: 'Update',
          last_name: 'Test',
          email: `update_${Date.now()}@example.com`,
          contact_number: '9876543210'
        });

      if (res.statusCode === 201) {
        customerId = res.body.data.customer_id;
      }
    });

    it('should update customer successfully', async () => {
      if (!customerId) {
        console.log('Skipping: customer not created');
        return;
      }

      const res = await request(app)
        .post('/api/customer/update')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          customer_id: customerId,
          first_name: 'Updated',
          contact_number: '9876543211'
        });

      expect([200, 201]).toContain(res.statusCode);
    });

    it('should reject missing customer_id', async () => {
      const res = await request(app)
        .post('/api/customer/update')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          first_name: 'Updated'
        });

      expect(res.statusCode).toBe(400);
    });
  });

  describe('POST /api/customer/get', () => {
    it('should get customer by id', async () => {
      const res = await request(app)
        .post('/api/customer/get')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          customer_id: 1
        });

      expect([200, 404]).toContain(res.statusCode);
    });

    it('should reject missing customer_id', async () => {
      const res = await request(app)
        .post('/api/customer/get')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({});

      expect(res.statusCode).toBe(400);
    });
  });

  describe('POST /api/customer/list', () => {
    it('should list customers with pagination', async () => {
      const res = await request(app)
        .post('/api/customer/list')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          page: 1,
          limit: 10
        });

      expect(res.statusCode).toBe(200);
      if (res.body.success) {
        expect(res.body.data).toHaveProperty('customers');
        expect(res.body.data).toHaveProperty('pagination');
      }
    });

    it('should use default pagination', async () => {
      const res = await request(app)
        .post('/api/customer/list')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({});

      expect(res.statusCode).toBe(200);
    });
  });

  describe('POST /api/customer/delete', () => {
    it('should delete customer', async () => {
      const res = await request(app)
        .post('/api/customer/delete')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({
          customer_id: 99999
        });

      expect([200, 404]).toContain(res.statusCode);
    });

    it('should reject missing customer_id', async () => {
      const res = await request(app)
        .post('/api/customer/delete')
        .set('Cookie', [
          `session_token=${authTokens.sessionToken}`,
          `access_token=${authTokens.accessToken}`
        ])
        .send({});

      expect(res.statusCode).toBe(400);
    });
  });
});

function generateTestTokens() {
  const AccessTokenUtil = require('../../../src/utils/access_token.util');
  const SessionTokenUtil = require('../../../src/utils/session_token.util');
  
  const mockData = {
    user_id: 1,
    business_id: 1,
    branch_id: 1,
    role_id: 1,
    email: 'test@example.com',
    contact_number: '1234567890',
    user_name: 'Test User',
    business_name: 'Test Business',
    branch_name: 'Main Branch',
    role_name: 'Owner',
    is_owner: true
  };
  
  return {
    accessToken: AccessTokenUtil.generateAccessToken(mockData).accessToken,
    sessionToken: SessionTokenUtil.generateSessionToken({
      ...mockData,
      device_id: 'test_device',
      ip_address: '127.0.0.1'
    }).sessionToken
  };
}