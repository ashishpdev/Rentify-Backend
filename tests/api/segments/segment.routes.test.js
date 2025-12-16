const request = require('supertest');
const app = require('../../../src/app'); [cite_start]// [cite: 2675] Exports app
const db = require('../../../src/database/connection');

// We can mock the auth middleware if we don't want to generate real tokens for every test
jest.mock('../../../src/middlewares/token-validation.middleware', () => ({
  requireBothTokens: (req, res, next) => {
    req.user = { user_id: 1, business_id: 1, role_id: 1 }; // Fake user
    next();
  }
}));

describe('Segment API Routes', () => {
  beforeAll(async () => {
    await db.initializeMasterConnection();
  });

  afterAll(async () => {
    await db.closeConnections();
  });

  test('POST /api/segments/create - should create a segment', async () => {
    const res = await request(app)
      .post('/api/segments/create') // Adjust path based on your routes definition
      .send({
        code: 'API_TEST',
        name: 'API Test Segment',
        description: 'Testing via Supertest'
      });

    expect(res.statusCode).toBeOneOf([201, 200]); // Depending on your ResponseUtil
    expect(res.body.success).toBe(true);
    expect(res.body.data).toBeDefined();
  });

  test('POST /api/segments/create - should fail validation on missing fields', async () => {
    const res = await request(app)
      .post('/api/segments/create')
      .send({
        // Missing code and name
        description: 'Invalid Payload'
      });

    expect(res.statusCode).toBe(400); // ResponseUtil.badRequest
  });
});