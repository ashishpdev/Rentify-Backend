// tests/performance/load-test-segments.js
import http from 'k6/http';
import { check, sleep } from 'k6';

// Test Configuration
export const options = {
  stages: [
    { duration: '30s', target: 20 }, // Ramp up to 20 users
    { duration: '1m', target: 20 },  // Stay at 20 users
    { duration: '10s', target: 0 },  // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must be faster than 500ms
    http_req_failed: ['rate<0.01'],   // Error rate must be < 1%
  },
};

const BASE_URL = 'http://localhost:3000/api'; // Change to your local or staging URL

export default function () {
  // 1. Login (if needed) or use a static token for testing
  // const headers = { 'Authorization': 'Bearer ...' };
  
  const headers = { 'Content-Type': 'application/json' };

  // 2. Perform the Action (Create Segment)
  const payload = JSON.stringify({
    code: `LOAD_${__VU}_${__ITER}`, // Unique code per Virtual User/Iteration
    name: 'Load Test Segment',
    description: 'Created by k6'
  });

  const res = http.post(`${BASE_URL}/segments/create`, payload, { headers });

  // 3. Assertions
  check(res, {
    'is status 200/201': (r) => r.status === 200 || r.status === 201,
    'transaction time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1); // Think time: simulate user pause
}