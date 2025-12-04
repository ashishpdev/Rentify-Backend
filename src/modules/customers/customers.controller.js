//  src/modules/customers/customers.controller.js
const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");
const { CustomerValidator } = require("./customers.validator");
const customersService = require("./customers.service");

class CustomerController {
  // ======================== CREATE CUSTOMER ========================
  async createCustomer(req, res, next) {
    try {
      const { error, value } = CustomerValidator.validateCreateCustomer(
        req.body
      );
      if (error) {
        logger.warn("Customer creation validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await customersService.createCustomer(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.created(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "createCustomer" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to create customer"
      );
    }
  }

  // ======================== UPDATE CUSTOMER ========================
  async updateCustomer(req, res, next) {
    try {
      const { error, value } = CustomerValidator.validateUpdateCustomer(
        req.body
      );
      if (error) {
        logger.warn("Customer update validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await customersService.updateCustomer(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "updateCustomer" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to update customer"
      );
    }
  }

  // ======================== GET CUSTOMER ========================
  async getCustomer(req, res, next) {
    try {
      const { error, value } = CustomerValidator.validateGetCustomer(req.body);
      if (error) {
        logger.warn("Get customer validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await customersService.getCustomer(
        value.customer_id,
        userData
      );

      if (!result.success) {
        return ResponseUtil.notFound(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "getCustomer" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to get customer"
      );
    }
  }

  // ======================== LIST CUSTOMERS ========================
  async listCustomers(req, res, next) {
    try {
      const { error, value } = CustomerValidator.validateListCustomers(
        req.body
      );
      if (error) {
        logger.warn("List customers validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const paginationParams = {
        page: value.page,
        limit: value.limit,
      };
      const result = await customersService.listCustomers(userData, paginationParams);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "listCustomers" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to list customers"
      );
    }
  }

  // ======================== DELETE CUSTOMER ========================
  async deleteCustomer(req, res, next) {
    try {
      const { error, value } = CustomerValidator.validateDeleteCustomer(
        req.body
      );
      if (error) {
        logger.warn("Delete customer validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await customersService.deleteCustomer(
        value.customer_id,
        userData
      );

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "deleteCustomer" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to delete customer"
      );
    }
  }
}

module.exports = new CustomerController();
