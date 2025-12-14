const Joi = require("joi");

/* ================= SYSTEM INFO ================= */
const getSystemInfoSchema = Joi.object({
    device_id: Joi.string().min(3).max(100).required().messages({
        "string.base": "Device ID must be text",
        "string.min": "Device ID must be at least 3 characters",
        "string.max": "Device ID must be at most 100 characters",
        "any.required": "Device ID is required",
    }),
});

/* ================= LOCATION ================= */
const getLocationSchema = Joi.object({
    device_id: Joi.string().min(3).max(100).required().messages({
        "string.base": "Device ID must be text",
        "string.min": "Device ID must be at least 3 characters",
        "string.max": "Device ID must be at most 100 characters",
        "any.required": "Device ID is required",
    }),
});

/* ================= FULL REPORT ================= */
const getFullReportSchema = Joi.object({
    device_id: Joi.string().min(3).max(100).required().messages({
        "string.base": "Device ID must be text",
        "string.min": "Device ID must be at least 3 characters",
        "string.max": "Device ID must be at most 100 characters",
        "any.required": "Device ID is required",
    }),
});

class DeviceValidator {
    static validateGetSystemInfo(data) {
        return getSystemInfoSchema.validate(data);
    }

    static validateGetLocation(data) {
        return getLocationSchema.validate(data);
    }

    static validateGetFullReport(data) {
        return getFullReportSchema.validate(data);
    }
}

module.exports = {
    DeviceValidator,
    schemas: {
        getSystemInfoSchema,
        getLocationSchema,
        getFullReportSchema,
    },
};
