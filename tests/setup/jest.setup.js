// tests/setup/jest.setup.js

// Increase timeout for Integration tests involving DB (default is 5000ms)
jest.setTimeout(30000);

// Global mocks (Optional: Silence logs during tests to keep output clean)
// global.console.log = jest.fn(); 
// global.console.error = jest.fn();