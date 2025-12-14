const express = require("express");
const DeviceController = require("./device.controller");
const {
    requireBothTokens,
} = require("../../middlewares/token-validation.middleware");

const router = express.Router();

router.post(
    "/system-info",
    requireBothTokens,
    DeviceController.getSystemInfo
);

router.post(
    "/location",
    requireBothTokens,
    DeviceController.getLocation
);

router.post(
    "/full-report",
    requireBothTokens,
    DeviceController.getFullReport
);

module.exports = router;
