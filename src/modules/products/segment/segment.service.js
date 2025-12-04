// src/modules/products/segment/segment.service.js
const segmentRepository = require("./segment.repository");
const logger = require("../../../config/logger.config");

class SegmentService {
  // ======================== CREATE SEGMENT ========================
  async createSegment(segmentData, userData) {
    try {
      const result = await segmentRepository.manageProductSegment({
        action: 1, // Create
        productSegmentId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        code: segmentData.code,
        name: segmentData.name,
        description: segmentData.description || null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success
          ? { product_segment_id: result.productSegmentId }
          : null,
      };
    } catch (error) {
      logger.error("SegmentService.createSegment error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== UPDATE SEGMENT ========================
  async updateSegment(segmentData, userData) {
    try {
      const result = await segmentRepository.manageProductSegment({
        action: 2, // Update
        productSegmentId: segmentData.product_segment_id,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        code: segmentData.code,
        name: segmentData.name,
        description: segmentData.description || null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success
          ? { product_segment_id: segmentData.product_segment_id }
          : null,
      };
    } catch (error) {
      logger.error("SegmentService.updateSegment error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== GET SEGMENT ========================
  async getSegment(productSegmentId, userData) {
    try {
      const result = await segmentRepository.manageProductSegment({
        action: 4, // Get Single
        productSegmentId: productSegmentId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        code: null,
        name: null,
        description: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      if (!result.success || !result.data) {
        return {
          success: false,
          message: "Product segment not found",
          data: null,
        };
      }

      return {
        success: true,
        message: "Product segment retrieved successfully",
        data: { segment: result.data },
      };
    } catch (error) {
      logger.error("SegmentService.getSegment error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== LIST SEGMENTS ========================
  async listSegments(userData, paginationParams = {}) {
    try {
      const result = await segmentRepository.manageProductSegment({
        action: 5, // Get List
        productSegmentId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        code: null,
        name: null,
        description: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      // Apply pagination on the result
      const allSegments = result.data || [];
      const total = allSegments.length;
      const page = paginationParams.page || 1;
      const limit = paginationParams.limit || 50;
      const totalPages = Math.ceil(total / limit);
      const startIndex = (page - 1) * limit;
      const endIndex = startIndex + limit;
      const paginatedSegments = allSegments.slice(startIndex, endIndex);

      return {
        success: result.success,
        message: result.message,
        data: {
          segments: paginatedSegments,
          pagination: {
            page: page,
            limit: limit,
            total: total,
            total_pages: totalPages,
            has_next: page < totalPages,
            has_prev: page > 1,
          },
        },
      };
    } catch (error) {
      logger.error("SegmentService.listSegments error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== DELETE SEGMENT ========================
  async deleteSegment(productSegmentId, userData) {
    try {
      const result = await segmentRepository.manageProductSegment({
        action: 3, // Delete
        productSegmentId: productSegmentId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        code: null,
        name: null,
        description: null,
        userId: userData.user_id,
        roleId: userData.role_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { product_segment_id: productSegmentId } : null,
      };
    } catch (error) {
      logger.error("SegmentService.deleteSegment error", {
        error: error.message,
      });
      throw error;
    }
  }
}

module.exports = new SegmentService();
