// tests/api/health/health.routes.test.js
const request = require('supertest');
const app = require('../../../src/app'); 

describe('Health Check API', () => {
  
  test('GET /health should return 200 OK and uptime', async () => {
    const res = await request(app).get('/health'); // Adjust path if it's /api/health

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual(expect.objectContaining({
      status: 'UP',
      timestamp: expect.any(String)
    }));
    
    // Optional: Check if DB status is reported in health check
    if (res.body.services) {
        expect(res.body.services.database).toBe('connected');
    }
  });
});