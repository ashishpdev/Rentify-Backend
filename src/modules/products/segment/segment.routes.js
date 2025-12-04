const express = require("express");
const SegmentController = require("./segment.controller");
const {
  requireBothTokens,
} = require("../../../middlewares/token-validation.middleware");

const router = express.Router();

// Segment Routes - All data from request body
router.post("/create", requireBothTokens, SegmentController.createSegment);
router.post("/update", requireBothTokens, SegmentController.updateSegment);
router.post("/get", requireBothTokens, SegmentController.getSegment);
router.post("/list", requireBothTokens, SegmentController.listSegments);
router.post("/delete", requireBothTokens, SegmentController.deleteSegment);

module.exports = router;
