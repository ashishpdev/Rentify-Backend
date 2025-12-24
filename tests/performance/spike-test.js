// tests/performance/spike-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '30s', target: 200 },
    { duration: '1m', target: 200 },
    { duration: '10s', target: 10 },
  ],
  
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    'http_req_failed': ['rate<0.05'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000/api';

export default function() {
  const headers = {
    'Content-Type': 'application/json',
  };

  const otpRes = http.post(
    `${BASE_URL}/auth/send-otp`,
    JSON.stringify({
      email: `spike_${Date.now()}_${__VU}@test.com`,
      otp_type_id: 2,
    }),
    { headers }
  );

  check(otpRes, {
    'status is 200': (r) => r.status === 200,
    'response time OK during spike': (r) => r.timings.duration < 1000,
  });

  sleep(0.5);
}