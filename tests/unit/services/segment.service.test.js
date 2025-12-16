const SegmentService = require('../../../src/modules/products/segment/segment.service');
const SegmentRepository = require('../../../src/modules/products/segment/segment.repository');

// Mock the repository to prevent real DB calls
jest.mock('../../../src/modules/products/segment/segment.repository');

describe('SegmentService Unit Tests', () => {
  const mockUser = { business_id: 1, branch_id: 1, user_id: 101, role_id: 2 };
  
  afterEach(() => {
    jest.clearAllMocks();
  });

  test('createSegment should return success when repository succeeds', async () => {
    // Arrange
    const inputData = { code: 'SEG01', name: 'Test Segment' };
    const mockDbResponse = { success: true, message: 'Created', data: { id: 1 } };
    
    // Tell the mock what to return
    SegmentRepository.manageProductSegment.mockResolvedValue(mockDbResponse);

    // Act
    const result = await SegmentService.createSegment(inputData, mockUser);

    // Assert
    expect(result.success).toBe(true);
    expect(SegmentRepository.manageProductSegment).toHaveBeenCalledWith(expect.objectContaining({
      action: 1, // Ensure the service passes the correct "Create" action ID
      code: 'SEG01',
      businessId: 1
    }));
  });

  test('createSegment should throw error if repository fails', async () => {
    // Arrange
    SegmentRepository.manageProductSegment.mockRejectedValue(new Error('DB Error'));

    // Act & Assert
    await expect(SegmentService.createSegment({}, mockUser))
      .rejects
      .toThrow('DB Error');
  });
});