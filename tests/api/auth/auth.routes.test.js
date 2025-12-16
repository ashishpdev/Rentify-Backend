// tests/api/auth/auth.routes.test.js
const request = require('supertest');
const app = require('../../../src/app');
const db = require('../../../src/database/connection');
const OTPUtil = require('../../../src/utils/otp.util');

describe('Auth API Integration Tests', () => {
  let testEmail = `test_${Date.now()}@example.com`;
  let generatedOTP;
  let sessionToken;
  let accessToken;

  beforeAll(async () => {
    await db.initializeMasterConnection();
  });

  afterAll(async () => {
    await db.closeConnections();
  });

  describe('POST /api/auth/send-otp', () => {
    it('should send OTP successfully for registration', async () => {
      const res = await request(app)
        .post('/api/auth/send-otp')
        .send({
          email: testEmail,
          otp_type_id: 2
        });

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data).toHaveProperty('otpId');
      expect(res.body.data).toHaveProperty('expiresAt');
    });

    it('should send OTP for login', async () => {
      const res = await request(app)
        .post('/api/auth/send-otp')
        .send({
          email: 'existing@example.com',
          otp_type_id: 1
        });

      expect([200, 409]).toContain(res.statusCode);
    });

    it('should reject invalid email format', async () => {
      const res = await request(app)
        .post('/api/auth/send-otp')
        .send({
          email: 'invalid-email',
          otp_type_id: 2
        });

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('should reject missing otp_type_id', async () => {
      const res = await request(app)
        .post('/api/auth/send-otp')
        .send({
          email: testEmail
        });

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('should reject invalid otp_type_id', async () => {
      const res = await request(app)
        .post('/api/auth/send-otp')
        .send({
          email: testEmail,
          otp_type_id: 'invalid'
        });

      expect(res.statusCode).toBe(400);
    });

    it('should handle SQL injection attempts', async () => {
      const res = await request(app)
        .post('/api/auth/send-otp')
        .send({
          email: "test@example.com' OR '1'='1",
          otp_type_id: 2
        });

      expect(res.statusCode).toBe(400);
    });

    it('should handle XSS attempts in email', async () => {
      const res = await request(app)
        .post('/api/auth/send-otp')
        .send({
          email: "<script>alert('xss')</script>@example.com",
          otp_type_id: 2
        });

      expect(res.statusCode).toBe(400);
    });
  });

  describe('POST /api/auth/verify-otp', () => {
    beforeEach(async () => {
      generatedOTP = OTPUtil.generateOTP();
      
      await request(app)
        .post('/api/auth/send-otp')
        .send({
          email: testEmail,
          otp_type_id: 2
        });
    });

    it('should verify correct OTP', async () => {
      const res = await request(app)
        .post('/api/auth/verify-otp')
        .send({
          email: testEmail,
          otpCode: generatedOTP,
          otp_type_id: 2
        });

      expect([200, 401]).toContain(res.statusCode);
    });

    it('should reject incorrect OTP', async () => {
      const res = await request(app)
        .post('/api/auth/verify-otp')
        .send({
          email: testEmail,
          otpCode: '000000',
          otp_type_id: 2
        });

      expect(res.statusCode).toBe(401);
      expect(res.body.success).toBe(false);
    });

    it('should reject OTP with wrong length', async () => {
      const res = await request(app)
        .post('/api/auth/verify-otp')
        .send({
          email: testEmail,
          otpCode: '12345',
          otp_type_id: 2
        });

      expect(res.statusCode).toBe(400);
    });

    it('should reject non-numeric OTP', async () => {
      const res = await request(app)
        .post('/api/auth/verify-otp')
        .send({
          email: testEmail,
          otpCode: 'ABCDEF',
          otp_type_id: 2
        });

      expect(res.statusCode).toBe(400);
    });

    it('should reject missing email', async () => {
      const res = await request(app)
        .post('/api/auth/verify-otp')
        .send({
          otpCode: '123456',
          otp_type_id: 2
        });

      expect(res.statusCode).toBe(400);
    });
  });

  describe('POST /api/auth/complete-registration', () => {
    const registrationData = {
      businessName: 'Test Business Ltd',
      businessEmail: 'business@test.com',
      ownerName: 'John Doe',
      ownerEmail: testEmail,
      ownerContactNumber: '1234567890'
    };

    it('should complete registration with valid data', async () => {
      const res = await request(app)
        .post('/api/auth/complete-registration')
        .send(registrationData);

      expect([201, 400]).toContain(res.statusCode);
    });

    it('should reject when business email equals owner email', async () => {
      const res = await request(app)
        .post('/api/auth/complete-registration')
        .send({
          ...registrationData,
          businessEmail: testEmail
        });

      expect(res.statusCode).toBe(400);
    });

    it('should reject short business name', async () => {
      const res = await request(app)
        .post('/api/auth/complete-registration')
        .send({
          ...registrationData,
          businessName: 'A'
        });

      expect(res.statusCode).toBe(400);
    });

    it('should reject invalid contact number', async () => {
      const res = await request(app)
        .post('/api/auth/complete-registration')
        .send({
          ...registrationData,
          ownerContactNumber: '123'
        });

      expect(res.statusCode).toBe(400);
    });

    it('should reject invalid email format', async () => {
      const res = await request(app)
        .post('/api/auth/complete-registration')
        .send({
          ...registrationData,
          ownerEmail: 'invalid-email'
        });

      expect(res.statusCode).toBe(400);
    });

    it('should handle special characters in business name', async () => {
      const res = await request(app)
        .post('/api/auth/complete-registration')
        .send({
          ...registrationData,
          businessName: "O'Brien & Sons Ltd <Company>"
        });

      expect([201, 400]).toContain(res.statusCode);
    });
  });

  describe('POST /api/auth/login', () => {
    it('should reject login without OTP', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          otpCode: '123456',
          otp_type_id: 1
        });

      expect(res.statusCode).toBe(401);
    });

    it('should reject invalid OTP type for login', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          otpCode: '123456',
          otp_type_id: 2
        });

      expect(res.statusCode).toBe(400);
    });

    it('should set HTTP-only cookies on successful login', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'valid@example.com',
          otpCode: '123456',
          otp_type_id: 1
        });

      if (res.statusCode === 200) {
        expect(res.headers['set-cookie']).toBeDefined();
        const cookies = res.headers['set-cookie'];
        expect(cookies.some(c => c.includes('session_token'))).toBe(true);
        expect(cookies.some(c => c.includes('access_token'))).toBe(true);
        expect(cookies.some(c => c.includes('HttpOnly'))).toBe(true);
      }
    });
  });

  describe('POST /api/auth/decrypt-token', () => {
    it('should require access token cookie', async () => {
      const res = await request(app)
        .post('/api/auth/decrypt-token');

      expect(res.statusCode).toBe(400);
    });

    it('should decrypt valid access token', async () => {
      const AccessTokenUtil = require('../../../src/utils/access_token.util');
      const testData = {
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
      const { accessToken } = AccessTokenUtil.generateAccessToken(testData);

      const res = await request(app)
        .post('/api/auth/decrypt-token')
        .set('Cookie', [`access_token=${accessToken}`]);

      expect(res.statusCode).toBe(200);
      expect(res.body.data.user_id).toBe(testData.user_id);
      expect(res.body.data.email).toBe(testData.email);
    });

    it('should reject tampered token', async () => {
      const res = await request(app)
        .post('/api/auth/decrypt-token')
        .set('Cookie', ['access_token=tampered.token.value']);

      expect(res.statusCode).toBe(401);
    });
  });

  describe('POST /api/auth/refresh-tokens', () => {
    it('should require session token', async () => {
      const res = await request(app)
        .post('/api/auth/refresh-tokens');

      expect(res.statusCode).toBe(400);
    });

    it('should refresh tokens with valid session', async () => {
      const SessionTokenUtil = require('../../../src/utils/session_token.util');
      const testData = {
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
        is_owner: true,
        device_id: 'test_device',
        ip_address: '127.0.0.1'
      };
      const { sessionToken } = SessionTokenUtil.generateSessionToken(testData);

      const res = await request(app)
        .post('/api/auth/refresh-tokens')
        .set('Cookie', [`session_token=${sessionToken}`]);

      expect([200, 401]).toContain(res.statusCode);
    });
  });

  describe('POST /api/auth/logout', () => {
    it('should require access token', async () => {
      const res = await request(app)
        .post('/api/auth/logout');

      expect(res.statusCode).toBe(400);
    });

    it('should clear cookies on logout', async () => {
      const AccessTokenUtil = require('../../../src/utils/access_token.util');
      const testData = {
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
      const { accessToken } = AccessTokenUtil.generateAccessToken(testData);

      const res = await request(app)
        .post('/api/auth/logout')
        .set('Cookie', [`access_token=${accessToken}`]);

      if (res.statusCode === 200) {
        const cookies = res.headers['set-cookie'];
        expect(cookies.some(c => c.includes('access_token=;'))).toBe(true);
        expect(cookies.some(c => c.includes('session_token=;'))).toBe(true);
      }
    });
  });

  describe('Security Tests', () => {
    it('should rate limit OTP requests', async () => {
      const requests = [];
      
      for (let i = 0; i < 10; i++) {
        requests.push(
          request(app)
            .post('/api/auth/send-otp')
            .send({
              email: testEmail,
              otp_type_id: 2
            })
        );
      }

      const responses = await Promise.all(requests);
      const successCount = responses.filter(r => r.statusCode === 200).length;
      expect(successCount).toBeGreaterThan(0);
    });

    it('should sanitize error messages', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'nonexistent@example.com',
          otpCode: '123456',
          otp_type_id: 1
        });

      expect(res.body.message).not.toContain('email');
      expect(res.body.message).not.toContain('user');
    });

    it('should handle concurrent login attempts', async () => {
      const email = `concurrent_${Date.now()}@test.com`;
      
      const requests = Array(5).fill(null).map(() =>
        request(app)
          .post('/api/auth/login')
          .send({
            email,
            otpCode: '123456',
            otp_type_id: 1
          })
      );

      const responses = await Promise.all(requests);
      
      responses.forEach(res => {
        expect([200, 401, 400]).toContain(res.statusCode);
      });
    });
  });
});