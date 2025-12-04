// src/modules/products/segment/segment.controller.js
const ResponseUtil = require("../../../utils/response.util");
const logger = require("../../../config/logger.config");
const { SegmentValidator } = require("./segment.validator");
const segmentService = require("./segment.service");

class SegmentController {
  // ======================== CREATE SEGMENT ========================
  async createSegment(req, res, next) {
    try {
      const { error, value } = SegmentValidator.validateCreateSegment(req.body);
      if (error) {
        logger.warn("Segment creation validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await segmentService.createSegment(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.created(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "createSegment" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to create segment"
      );
    }
  }

  // ======================== UPDATE SEGMENT ========================
  async updateSegment(req, res, next) {
    try {
      const { error, value } = SegmentValidator.validateUpdateSegment(req.body);
      if (error) {
        logger.warn("Segment update validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await segmentService.updateSegment(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "updateSegment" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to update segment"
      );
    }
  }

  // ======================== GET SEGMENT ========================
  async getSegment(req, res, next) {
    try {
      const { error, value } = SegmentValidator.validateGetSegment(req.body);
      if (error) {
        logger.warn("Get segment validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await segmentService.getSegment(
        value.product_segment_id,
        userData
      );

      if (!result.success) {
        return ResponseUtil.notFound(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "getSegment" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to get segment"
      );
    }
  }

  // ======================== LIST SEGMENTS ========================
  async listSegments(req, res, next) {
    try {
      const { error, value } = SegmentValidator.validateListSegments(req.body);
      if (error) {
        logger.warn("List segments validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const paginationParams = {
        page: value.page,
        limit: value.limit,
      };
      const result = await segmentService.listSegments(
        userData,
        paginationParams
      );

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "listSegments" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to list segments"
      );
    }
  }

  // ======================== DELETE SEGMENT ========================
  async deleteSegment(req, res, next) {
    try {
      const { error, value } = SegmentValidator.validateDeleteSegment(req.body);
      if (error) {
        logger.warn("Delete segment validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await segmentService.deleteSegment(
        value.product_segment_id,
        userData
      );

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "deleteSegment" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to delete segment"
      );
    }
  }
}

module.exports = new SegmentController();
