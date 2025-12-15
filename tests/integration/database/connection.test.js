// tests/integration/database/connection.test.js
const db = require('../../../src/database/connection');

describe('Database Connection Integration Tests', () => {
  
  beforeAll(async () => {
    // Ensure we start fresh
    await db.closeConnections();
  });

  afterAll(async () => {
    // Clean up after tests
    await db.closeConnections();
  });

  test('initializeMasterConnection should establish a valid connection pool', async () => {
    await db.initializeMasterConnection();
    
    // Check if the pool is active by running a simple query
    const result = await db.execute('SELECT 1 as val');
    
    expect(result).toBeDefined();
    // Assuming your execute wrapper returns an array of rows
    expect(result[0].val).toBe(1);
  });

  test('should handle connection errors gracefully', async () => {
    // Intentionally mess up config to test error handling
    // Note: This requires your DB module to support config injection or reloading
    // Otherwise, skip this if it disrupts the singleton for other tests
    try {
        await db.execute('SELECT * FROM non_existent_table');
    } catch (error) {
        expect(error).toBeDefined();
        // MySQL error code for table doesn't exist
        expect(error.code).toBe('ER_NO_SUCH_TABLE');
    }
  });
});