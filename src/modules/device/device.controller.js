const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");
const { DeviceValidator } = require("./device.validator");
const deviceService = require("./device.service");

class DeviceController {
    // ================= SYSTEM INFO =================
    async getSystemInfo(req, res) {
        try {
            const { error, value } =
                DeviceValidator.validateGetSystemInfo(req.body);

            if (error) {
                return ResponseUtil.badRequest(res, error.details[0].message);
            }

            const result = await deviceService.getSystemInfo(value, req.user);

            if (!result.success) {
                return ResponseUtil.forbidden(res, result.message);
            }

            return ResponseUtil.success(res, result.data, result.message);
        } catch (error) {
            logger.logError(error, req, { operation: "getSystemInfo" });
            return ResponseUtil.serverError(res, "Failed to fetch system info");
        }
    }

    // ================= LOCATION =================
    async getLocation(req, res) {
        try {
            const { error, value } =
                DeviceValidator.validateGetLocation(req.body);

            if (error) {
                return ResponseUtil.badRequest(res, error.details[0].message);
            }

            const result = await deviceService.getLocation(value, req.user);

            if (!result.success) {
                return ResponseUtil.forbidden(res, result.message);
            }

            return ResponseUtil.success(res, result.data, result.message);
        } catch (error) {
            logger.logError(error, req, { operation: "getLocation" });
            return ResponseUtil.serverError(res, "Failed to fetch location");
        }
    }

    // ================= FULL REPORT =================
    async getFullReport(req, res) {
        try {
            const { error, value } =
                DeviceValidator.validateGetFullReport(req.body);

            if (error) {
                return ResponseUtil.badRequest(res, error.details[0].message);
            }

            const result = await deviceService.getFullReport(value, req.user);

            if (!result.success) {
                return ResponseUtil.forbidden(res, result.message);
            }

            return ResponseUtil.success(res, result.data, result.message);
        } catch (error) {
            logger.logError(error, req, { operation: "getFullReport" });
            return ResponseUtil.serverError(res, "Failed to fetch device report");
        }
    }
}

module.exports = new DeviceController();
