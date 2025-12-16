// tests/setup/jest.setup.js
jest.setTimeout(30000);

// Custom matcher
expect.extend({
  toBeOneOf(received, expected) {
    const pass = expected.includes(received);
    return {
      pass,
      message: () => `expected ${received} to be one of ${expected}`,
    };
  },
});

// Suppress logs in tests (optional)
if (process.env.SILENT_TESTS === 'true') {
  global.console.log = jest.fn();
  global.console.error = jest.fn();
}