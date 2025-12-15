// jest.config.js
module.exports = {
  // Test environment
  testEnvironment: 'node',
  
  // Coverage configuration
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html', 'json-summary'],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/server.js', // Exclude server entry point
    '!src/database/schema/**',
    '!src/database/store_procedures/**',
    '!src/templates/**',
  ],
  
  // Coverage thresholds (enforce quality)
  coverageThresholds: {
    global: {
      branches: 70,
      functions: 75,
      lines: 80,
      statements: 80,
    },
    './src/utils/': {
      branches: 90,
      functions: 95,
      lines: 95,
      statements: 95,
    },
    './src/modules/**/': {
      branches: 75,
      functions: 80,
      lines: 85,
      statements: 85,
    },
  },
  
  // Test match patterns
  testMatch: [
    '**/tests/**/*.test.js',
    '**/tests/**/*.spec.js',
  ],
  
  // Setup files
  setupFilesAfterEnv: ['<rootDir>/tests/setup/jest.setup.js'],
  globalSetup: '<rootDir>/tests/setup/global-setup.js',
  globalTeardown: '<rootDir>/tests/setup/global-teardown.js',
  
  // Module paths
  moduleDirectories: ['node_modules', 'src'],
  
  // Timeout
  testTimeout: 30000,
  
  // Test organization
  projects: [
    {
      displayName: 'unit',
      testMatch: ['**/tests/unit/**/*.test.js'],
      testTimeout: 10000,
    },
    {
      displayName: 'integration',
      testMatch: ['**/tests/integration/**/*.test.js'],
      testTimeout: 30000,
    },
    {
      displayName: 'api',
      testMatch: ['**/tests/api/**/*.test.js'],
      testTimeout: 30000,
    },
    {
      displayName: 'e2e',
      testMatch: ['**/tests/e2e/**/*.test.js'],
      testTimeout: 60000,
    },
    {
      displayName: 'security',
      testMatch: ['**/tests/security/**/*.test.js'],
      testTimeout: 30000,
    },
  ],
  
  // Verbose output
  verbose: true,
  
  // Clear mocks between tests
  clearMocks: true,
  resetMocks: true,
  restoreMocks: true,
  
  // Error handling
  bail: false, // Continue running tests after failure
  
  // Transform
  transform: {},
  
  // Module name mapper for absolute imports
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1',
    '^@config/(.*)$': '<rootDir>/src/config/$1',
    '^@utils/(.*)$': '<rootDir>/src/utils/$1',
    '^@modules/(.*)$': '<rootDir>/src/modules/$1',
  },
};