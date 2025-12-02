//  src/modules/customers/customers.controller.js
const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");
const { CustomerValidator } = require("./customers.validator");
const customersService = require("./customers.service");

class CustomerController {

    async createCustomer(req, res, next) {
        try {
            const { error, value } = CustomerValidator.validateCreateCustomer(req.body);
            if (error) {
                logger.warn("Customer creation validation failed", {
                    email: req.body.email,
                    error: error.details[0].message,
                });
                return ResponseUtil.badRequest(res, error.details[0].message);
            }

            const userData = req.user;
            const result = await customersService.createCustomer(value, userData);
            
            return ResponseUtil.success(res, result);
        } catch (error) {
            logger.logError(error, req, {
                operation: "createCustomer",
                email: req.body.email,
            });
            next(error);
        }
    }

    async updateCustomer(req, res, next) {
        try {
            const { customerId } = req.params;
            const { error, value } = CustomerValidator.validateUpdateCustomer(req.body);
            if (error) {
                logger.warn("Customer update validation failed", {
                    customerId,
                    error: error.details[0].message,
                });
                return ResponseUtil.badRequest(res, error.details[0].message);
            }

            const userData = req.user;
            const result = await customersService.updateCustomer(customerId, value, userData);
            
            return ResponseUtil.success(res, result);
        } catch (error) {
            logger.logError(error, req, {
                operation: "updateCustomer",
                customerId: req.params.customerId,
            });
            next(error);
        }
    }

    async getCustomer(req, res, next) {
        try {
            const { customerId } = req.params;
            const { error, value } = CustomerValidator.validateGetCustomer({ customerId: parseInt(customerId) });
            if (error) {
                logger.warn("Get customer validation failed", {
                    customerId,
                    error: error.details[0].message,
                });
                return ResponseUtil.badRequest(res, error.details[0].message);
            }

            const userData = req.user;
            const result = await customersService.getCustomer(value.customerId, userData);
            
            return ResponseUtil.success(res, result);
        } catch (error) {
            logger.logError(error, req, {
                operation: "getCustomer",
                customerId: req.params.customerId,
            });
            next(error);
        }
    }

    async getAllCustomers(req, res, next) {
        try {
            const userData = req.user;
            const result = await customersService.getAllCustomers(userData);
            
            return ResponseUtil.success(res, result);
        } catch (error) {
            logger.logError(error, req, {
                operation: "getAllCustomers",
            });
            next(error);
        }
    }

    async deleteCustomer(req, res, next) {
        try {
            const { customerId } = req.params;
            const { error, value } = CustomerValidator.validateDeleteCustomer({ customerId: parseInt(customerId) });
            if (error) {
                logger.warn("Delete customer validation failed", {
                    customerId,
                    error: error.details[0].message,
                });
                return ResponseUtil.badRequest(res, error.details[0].message);
            }

            const userData = req.user;
            const result = await customersService.deleteCustomer(value.customerId, userData);
            
            return ResponseUtil.success(res, result);
        } catch (error) {
            logger.logError(error, req, {
                operation: "deleteCustomer",
                customerId: req.params.customerId,
            });
            next(error);
        }
    }
}

module.exports = new CustomerController();
