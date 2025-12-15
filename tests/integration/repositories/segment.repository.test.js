const SegmentRepository = require('../../../src/modules/products/segment/segment.repository');
const db = require('../../../src/database/connection');

describe('SegmentRepository Integration Tests', () => {
  
  // Setup: Connect to Test DB
  beforeAll(async () => {
    await db.initializeMasterConnection(); 
  });

  // Teardown: Close Connection
  afterAll(async () => {
    await db.closeConnections();
  });

  test('manageProductSegment should execute SP and return data', async () => {
    // This assumes your Test DB has the Stored Procedures loaded
    const params = {
      action: 1, // Create
      productSegmentId: null,
      businessId: 1,
      branchId: 1,
      code: 'INT_TEST',
      name: 'Integration Test Segment',
      description: 'Created by Jest',
      userId: 1,
      roleId: 1
    };

    const result = await SegmentRepository.manageProductSegment(params);

    expect(result).toBeDefined();
    // Verify specific SP output structure from your code
    [cite_start]// "success" is mapped from "@p_success" in your repo code [cite: 2411]
    if (result.success) {
      expect(result.product_segment_id).not.toBeNull();
    } else {
      // If it fails (e.g., duplicate code), ensure it handled the error gracefully
      expect(result.error_code).toBeDefined();
    }
  });
});