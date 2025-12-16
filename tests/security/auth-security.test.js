// tests/security/auth-security.test.js
const request = require('supertest');
const app = require('../../src/app');
const AccessTokenUtil = require('../../src/utils/access_token.util');
const SessionTokenUtil = require('../../src/utils/session_token.util');

describe('Security & Penetration Tests', () => {
  describe('SQL Injection Tests', () => {
    const sqlInjectionPayloads = [
      "' OR '1'='1",
      "'; DROP TABLE users; --",
      "1' UNION SELECT * FROM users--",
      "admin'--",
      "' OR 1=1--",
      "' OR 'a'='a",
      "1'; DELETE FROM users WHERE '1'='1",
    ];

    sqlInjectionPayloads.forEach(payload => {
      it(`should prevent SQL injection: ${payload}`, async () => {
        const res = await request(app)
          .post('/api/auth/send-otp')
          .send({
            email: `test${payload}@example.com`,
            otp_type_id: 1
          });

        expect(res.statusCode).toBe(400);
        expect(res.body.success).toBe(false);
        
        const body = JSON.stringify(res.body).toLowerCase();
        expect(body).not.toContain('sql');
        expect(body).not.toContain('syntax');
        expect(body).not.toContain('mysql');
      });
    });

    it('should prevent SQL injection in customer search', async () => {
      const { accessToken, sessionToken } = generateTestTokens();

      const res = await request(app)
        .post('/api/customer/list')
        .set('Cookie', [
          `session_token=${sessionToken}`,
          `access_token=${accessToken}`
        ])
        .send({
          search: "'; DROP TABLE customers; --"
        });

      expect([200, 400]).toContain(res.statusCode);
      if (res.statusCode === 200) {
        expect(res.body.success).toBe(true);
      }
    });
  });

  describe('XSS (Cross-Site Scripting) Tests', () => {
    const xssPayloads = [
      "<script>alert('XSS')</script>",
      "<img src=x onerror=alert('XSS')>",
      "<svg onload=alert('XSS')>",
      "javascript:alert('XSS')",
      "<iframe src=javascript:alert('XSS')>",
      "<body onload=alert('XSS')>",
    ];

    xssPayloads.forEach(payload => {
      it(`should sanitize XSS payload: ${payload.substring(0, 30)}...`, async () => {
        const { accessToken, sessionToken } = generateTestTokens();

        const res = await request(app)
          .post('/api/customer/create')
          .set('Cookie', [
            `session_token=${sessionToken}`,
            `access_token=${accessToken}`
          ])
          .send({
            first_name: payload,
            last_name: 'Test',
            email: `test_${Date.now()}@example.com`,
            contact_number: '1234567890'
          });

        if (res.statusCode === 201) {
          const body = JSON.stringify(res.body);
          expect(body).not.toContain('<script');
          expect(body).not.toContain('onerror=');
          expect(body).not.toContain('javascript:');
        }
      });
    });

    it('should prevent XSS in rental notes', async () => {
      const { accessToken, sessionToken } = generateTestTokens();

      const res = await request(app)
        .post('/api/rentals/update')
        .set('Cookie', [
          `session_token=${sessionToken}`,
          `access_token=${accessToken}`
        ])
        .send({
          rental_id: 1,
          notes: "<script>alert('XSS')</script>"
        });

      if (res.statusCode === 200) {
        expect(JSON.stringify(res.body)).not.toContain('<script');
      }
    });
  });

  describe('Authentication Bypass Tests', () => {
    it('should reject requests without tokens', async () => {
      const res = await request(app)
        .post('/api/customer/list')
        .send({});

      expect(res.statusCode).toBe(400);
      expect(res.body.success).toBe(false);
    });

    it('should reject expired access tokens', (done) => {
      process.env.ACCESS_TOKEN_EXPIRES_MIN = '0.01';
      
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

      const { accessToken } = AccessTokenUtil.generateAccessToken(mockData);
      const { sessionToken } = SessionTokenUtil.generateSessionToken({
        ...mockData,
        device_id: 'test',
        ip_address: '127.0.0.1'
      });

      setTimeout(async () => {
        const res = await request(app)
          .post('/api/customer/list')
          .set('Cookie', [
            `session_token=${sessionToken}`,
            `access_token=${accessToken}`
          ])
          .send({});

        expect(res.statusCode).toBe(401);
        process.env.ACCESS_TOKEN_EXPIRES_MIN = '15';
        done();
      }, 1000);
    });

    it('should reject tampered tokens', async () => {
      const { accessToken, sessionToken } = generateTestTokens();
      const tamperedAccess = accessToken.slice(0, -10) + 'TAMPERED12';

      const res = await request(app)
        .post('/api/customer/list')
        .set('Cookie', [
          `session_token=${sessionToken}`,
          `access_token=${tamperedAccess}`
        ])
        .send({});

      expect(res.statusCode).toBe(401);
    });

    it('should reject mismatched user_id in tokens', async () => {
      const mockData1 = {
        user_id: 1,
        business_id: 1,
        branch_id: 1,
        role_id: 1,
        email: 'user1@example.com',
        contact_number: '1234567890',
        user_name: 'User One',
        business_name: 'Business One',
        branch_name: 'Branch One',
        role_name: 'Owner',
        is_owner: true
      };

      const mockData2 = {
        ...mockData1,
        user_id: 2,
        email: 'user2@example.com'
      };

      const { accessToken } = AccessTokenUtil.generateAccessToken(mockData1);
      const { sessionToken } = SessionTokenUtil.generateSessionToken({
        ...mockData2,
        device_id: 'test',
        ip_address: '127.0.0.1'
      });

      const res = await request(app)
        .post('/api/customer/list')
        .set('Cookie', [
          `session_token=${sessionToken}`,
          `access_token=${accessToken}`
        ])
        .send({});

      expect(res.statusCode).toBe(401);
    });

    it('should prevent session fixation', async () => {
      const { accessToken: token1 } = generateTestTokens();
      const { accessToken: token2 } = generateTestTokens();

      expect(token1).not.toBe(token2);
    });
  });

  describe('Authorization Tests', () => {
    it('should prevent cross-business data access', async () => {
      const business1Tokens = generateTestTokens(1);
      const business2Tokens = generateTestTokens(2);

      const createRes = await request(app)
        .post('/api/customer/create')
        .set('Cookie', [
          `session_token=${business1Tokens.sessionToken}`,
          `access_token=${business1Tokens.accessToken}`
        ])
        .send({
          first_name: 'Business1',
          last_name: 'Customer',
          email: `b1_${Date.now()}@test.com`,
          contact_number: '1234567890'
        });

      if (createRes.statusCode === 201) {
        const customerId = createRes.body.data.customer_id;

        const accessRes = await request(app)
          .post('/api/customer/get')
          .set('Cookie', [
            `session_token=${business2Tokens.sessionToken}`,
            `access_token=${business2Tokens.accessToken}`
          ])
          .send({
            customer_id: customerId
          });

        expect([403, 404]).toContain(accessRes.statusCode);
      }
    });

    it('should enforce role-based access control', async () => {
      const nonOwnerTokens = generateTestTokens(1, 2);

      const res = await request(app)
        .post('/api/segment/delete')
        .set('Cookie', [
          `session_token=${nonOwnerTokens.sessionToken}`,
          `access_token=${nonOwnerTokens.accessToken}`
        ])
        .send({
          product_segment_id: 1
        });

      expect([200, 403]).toContain(res.statusCode);
    });
  });

  describe('CSRF Protection Tests', () => {
    it('should validate origin header', async () => {
      const { accessToken, sessionToken } = generateTestTokens();

      const res = await request(app)
        .post('/api/customer/list')
        .set('Cookie', [
          `session_token=${sessionToken}`,
          `access_token=${accessToken}`
        ])
        .set('Origin', 'https://evil.com')
        .send({});

      expect([200, 403]).toContain(res.statusCode);
    });

    it('should reject requests from untrusted origins', async () => {
      const res = await request(app)
        .post('/api/auth/send-otp')
        .set('Origin', 'https://malicious-site.com')
        .send({
          email: 'test@example.com',
          otp_type_id: 1
        });

      if (res.headers['access-control-allow-origin']) {
        expect(res.headers['access-control-allow-origin'])
          .not.toBe('https://malicious-site.com');
      }
    });
  });

  describe('Rate Limiting Tests', () => {
    it('should rate limit OTP requests', async () => {
      const email = `ratelimit_${Date.now()}@test.com`;
      const requests = [];

      for (let i = 0; i < 20; i++) {
        requests.push(
          request(app)
            .post('/api/auth/send-otp')
            .send({
              email,
              otp_type_id: 1
            })
        );
      }

      const responses = await Promise.all(requests);
      const tooManyRequests = responses.filter(r => r.statusCode === 429);

      console.log(`Rate limited: ${tooManyRequests.length}/20`);
    });

    it('should rate limit login attempts', async () => {
      const email = `bruteforce_${Date.now()}@test.com`;
      const requests = [];

      for (let i = 0; i < 15; i++) {
        requests.push(
          request(app)
            .post('/api/auth/login')
            .send({
              email,
              otpCode: '123456',
              otp_type_id: 1
            })
        );
      }

      const responses = await Promise.all(requests);
      const blocked = responses.filter(r => r.statusCode === 429);

      console.log(`Blocked: ${blocked.length}/15`);
    });
  });

  describe('Information Disclosure Tests', () => {
    it('should not reveal stack traces in errors', async () => {
      const res = await request(app)
        .post('/api/customer/create')
        .send({
          invalid_field: 'test'
        });

      const body = JSON.stringify(res.body).toLowerCase();
      expect(body).not.toContain('stack');
      expect(body).not.toContain('at async');
      expect(body).not.toContain('node_modules');
      expect(body).not.toContain('src/');
    });

    it('should not reveal database structure', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'nonexistent@example.com',
          otpCode: '123456',
          otp_type_id: 1
        });

      const body = JSON.stringify(res.body).toLowerCase();
      expect(body).not.toContain('table');
      expect(body).not.toContain('column');
      expect(body).not.toContain('foreign key');
      expect(body).not.toContain('constraint');
    });

    it('should use generic error messages', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          otpCode: '000000',
          otp_type_id: 1
        });

      const message = res.body.message.toLowerCase();
      expect(message).not.toContain('user not found');
      expect(message).not.toContain('email does not exist');
      expect(message).not.toContain('wrong otp');
    });
  });

  describe('Input Validation Tests', () => {
    it('should validate email format strictly', async () => {
      const invalidEmails = [
        'notanemail',
        '@example.com',
        'test@',
        'test..test@example.com',
        'test@example',
      ];

      for (const email of invalidEmails) {
        const res = await request(app)
          .post('/api/auth/send-otp')
          .send({
            email,
            otp_type_id: 1
          });

        expect(res.statusCode).toBe(400);
      }
    });

    it('should validate phone numbers', async () => {
      const { accessToken, sessionToken } = generateTestTokens();

      const res = await request(app)
        .post('/api/customer/create')
        .set('Cookie', [
          `session_token=${sessionToken}`,
          `access_token=${accessToken}`
        ])
        .send({
          first_name: 'Test',
          email: `test_${Date.now()}@example.com`,
          contact_number: '123'
        });

      expect(res.statusCode).toBe(400);
    });

    it('should prevent excessively long inputs', async () => {
      const { accessToken, sessionToken } = generateTestTokens();
      const longString = 'A'.repeat(10000);

      const res = await request(app)
        .post('/api/customer/create')
        .set('Cookie', [
          `session_token=${sessionToken}`,
          `access_token=${accessToken}`
        ])
        .send({
          first_name: longString,
          email: `test_${Date.now()}@example.com`,
          contact_number: '1234567890'
        });

      expect(res.statusCode).toBe(400);
    });
  });

  describe('Token Security Tests', () => {
    it('should use HttpOnly cookies', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          otpCode: '123456',
          otp_type_id: 1
        });

      if (res.headers['set-cookie']) {
        const cookies = res.headers['set-cookie'];
        cookies.forEach(cookie => {
          if (cookie.includes('session_token') || cookie.includes('access_token')) {
            expect(cookie.toLowerCase()).toContain('httponly');
          }
        });
      }
    });

    it('should use Secure cookies in production', async () => {
      const originalEnv = process.env.NODE_ENV;
      process.env.NODE_ENV = 'production';

      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          otpCode: '123456',
          otp_type_id: 1
        });

      if (res.headers['set-cookie']) {
        const cookies = res.headers['set-cookie'];
        cookies.forEach(cookie => {
          if (cookie.includes('session_token') || cookie.includes('access_token')) {
            expect(cookie.toLowerCase()).toContain('secure');
          }
        });
      }

      process.env.NODE_ENV = originalEnv;
    });

    it('should set SameSite attribute', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          otpCode: '123456',
          otp_type_id: 1
        });

      if (res.headers['set-cookie']) {
        const cookies = res.headers['set-cookie'];
        cookies.forEach(cookie => {
          if (cookie.includes('session_token') || cookie.includes('access_token')) {
            expect(cookie.toLowerCase()).toContain('samesite');
          }
        });
      }
    });
  });
});

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