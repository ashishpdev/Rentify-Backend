// tests/performance/stress-test.js
import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const errorRate = new Rate('errors');
const customTrend = new Trend('custom_response_time');
const requestCounter = new Counter('total_requests');

export const options = {
  stages: [
    { duration: '1m', target: 10 },
    { duration: '2m', target: 20 },
    { duration: '2m', target: 50 },
    { duration: '2m', target: 100 },
    { duration: '2m', target: 150 },
    { duration: '2m', target: 200 },
    { duration: '2m', target: 0 },
  ],
  
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    'http_req_failed': ['rate<0.01'],
    'errors': ['rate<0.05'],
    'http_req_waiting': ['p(95)<400'],
    'http_req_connecting': ['p(95)<100'],
  },
  
  setupTimeout: '60s',
  teardownTimeout: '60s',
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000/api';

function generateUniqueEmail() {
  return `perf_${Date.now()}_${__VU}_${__ITER}@perftest.com`;
}

export function setup() {
  console.log('🚀 Starting Stress Test');
  console.log(`Base URL: ${BASE_URL}`);
  
  return {
    timestamp: new Date().toISOString(),
  };
}

export default function(data) {
  const headers = {
    'Content-Type': 'application/json',
  };

  group('Authentication Flow', () => {
    const otpEmail = generateUniqueEmail();
    const otpRes = http.post(
      `${BASE_URL}/auth/send-otp`,
      JSON.stringify({
        email: otpEmail,
        otp_type_id: 2,
      }),
      { headers }
    );

    requestCounter.add(1);
    errorRate.add(otpRes.status !== 200);
    customTrend.add(otpRes.timings.duration);

    check(otpRes, {
      'OTP request successful': (r) => r.status === 200,
      'OTP response has otpId': (r) => {
        const body = JSON.parse(r.body || '{}');
        return body.data && body.data.otpId !== undefined;
      },
      'Response time < 500ms': (r) => r.timings.duration < 500,
    });
  });

  group('Product Operations', () => {
    const segmentRes = http.post(
      `${BASE_URL}/segment/list`,
      JSON.stringify({
        page: 1,
        limit: 10,
      }),
      { 
        headers: {
          ...headers,
          'Cookie': 'access_token=mock_token',
        }
      }
    );

    requestCounter.add(1);
    errorRate.add(segmentRes.status >= 400 && segmentRes.status !== 401);

    check(segmentRes, {
      'Segment list request handled': (r) => r.status === 200 || r.status === 401,
      'Response time acceptable': (r) => r.timings.duration < 300,
    });
  });

  group('Customer Operations', () => {
    const customerRes = http.post(
      `${BASE_URL}/customer/list`,
      JSON.stringify({
        page: 1,
        limit: 20,
      }),
      { 
        headers: {
          ...headers,
          'Cookie': 'access_token=mock_token',
        }
      }
    );

    requestCounter.add(1);
    errorRate.add(customerRes.status >= 400 && customerRes.status !== 401);

    check(customerRes, {
      'Customer list handled': (r) => r.status === 200 || r.status === 401,
      'Response under 400ms': (r) => r.timings.duration < 400,
    });
  });

  group('Rental Operations', () => {
    const rentalRes = http.post(
      `${BASE_URL}/rentals/list`,
      JSON.stringify({
        page: 1,
        limit: 15,
      }),
      { 
        headers: {
          ...headers,
          'Cookie': 'access_token=mock_token',
        }
      }
    );

    requestCounter.add(1);
    errorRate.add(rentalRes.status >= 400 && rentalRes.status !== 401);

    check(rentalRes, {
      'Rental list handled': (r) => r.status === 200 || r.status === 401,
      'Database query performant': (r) => r.timings.duration < 600,
    });
  });

  sleep(Math.random() * 2 + 1);
}

export function teardown(data) {
  console.log('🏁 Stress Test Complete');
  console.log(`Test Duration: ${data.timestamp}`);
}

export function handleSummary(data) {
  console.log('\n📊 Stress Test Summary:');
  console.log('========================');
  console.log(`Total Requests: ${data.metrics.total_requests?.values.count || 0}`);
  console.log(`Failed Requests: ${(data.metrics.http_req_failed?.values.rate || 0) * 100}%`);
  console.log(`Avg Response Time: ${data.metrics.http_req_duration?.values.avg?.toFixed(2) || 0}ms`);
  console.log(`95th Percentile: ${data.metrics.http_req_duration?.values['p(95)']?.toFixed(2) || 0}ms`);
  console.log(`99th Percentile: ${data.metrics.http_req_duration?.values['p(99)']?.toFixed(2) || 0}ms`);
  
  return {
    'stdout': JSON.stringify(data, null, 2),
    'summary.json': JSON.stringify(data),
  };
}