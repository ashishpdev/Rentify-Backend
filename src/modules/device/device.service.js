const logger = require("../../config/logger.config");
const {
    requestFromDevice,
    getOnlineDevices,
} = require("../../ws/ws.connection");

class DeviceService {
    // ================= ACCESS CHECK =================
    validateAccess(deviceId, userData) {
        const device = getOnlineDevices().find(
            (d) => d.deviceId === deviceId
        );

        if (!device) {
            return { success: false, message: "Device is offline or not connected" };
        }

        if (
            String(device.businessId) !== String(userData.business_id) ||
            String(device.branchId) !== String(userData.branch_id)
        ) {
            return {
                success: false,
                message: "Access denied: Device belongs to another business or branch",
            };
        }

        return { success: true };
    }

    // ================= SYSTEM INFO =================
    async getSystemInfo(data, userData) {
        try {
            const access = this.validateAccess(data.device_id, userData);
            if (!access.success) return access;

            const response = await requestFromDevice(
                {
                    businessId: userData.business_id,
                    branchId: userData.branch_id,
                    deviceId: data.device_id,
                },
                { type: "GET_SYSTEM_INFO" }
            );

            return {
                success: true,
                message: "System information fetched successfully",
                data: response.payload,
            };
        } catch (error) {
            logger.error("DeviceService.getSystemInfo error", {
                error: error.message,
            });
            return { success: false, message: error.message };
        }
    }

    // ================= LOCATION =================
    async getLocation(data, userData) {
        try {
            const access = this.validateAccess(data.device_id, userData);
            if (!access.success) return access;

            const response = await requestFromDevice(
                {
                    businessId: userData.business_id,
                    branchId: userData.branch_id,
                    deviceId: data.device_id,
                },
                { type: "GET_LOCATION" }
            );

            return {
                success: true,
                message: "Location fetched successfully",
                data: response.payload,
            };
        } catch (error) {
            logger.error("DeviceService.getLocation error", {
                error: error.message,
            });
            return { success: false, message: error.message };
        }
    }

    // ================= FULL REPORT =================
    async getFullReport(data, userData) {
        try {
            const access = this.validateAccess(data.device_id, userData);
            if (!access.success) return access;

            const response = await requestFromDevice(
                {
                    businessId: userData.business_id,
                    branchId: userData.branch_id,
                    deviceId: data.device_id,
                },
                { type: "GET_FULL_REPORT" }
            );

            return {
                success: true,
                message: "Full device report fetched successfully",
                data: response.payload,
            };
        } catch (error) {
            logger.error("DeviceService.getFullReport error", {
                error: error.message,
            });
            return { success: false, message: error.message };
        }
    }
}

module.exports = new DeviceService();
