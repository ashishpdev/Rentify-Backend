// src/modules/rentals/rentals.controller.js
const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");
const { RentalValidator } = require("./rentals.validator");
const rentalService = require("./rentals.service");

class RentalController {
  /**
   * Issue a new rental
   * @route POST /api/v1/rentals/issue
   */
  async issueRental(req, res, next) {
    try {
      const { error, value } = RentalValidator.validateIssueRental(req.body);
      if (error) {
        logger.warn("Issue rental validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await rentalService.issueRental(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.created(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "issueRental" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to issue rental"
      );
    }
  }

  /**
   * Get rental details by ID
   * @route POST /api/v1/rentals/get
   */
  async getRental(req, res, next) {
    try {
      const { error, value } = RentalValidator.validateGetRental(req.body);
      if (error) {
        logger.warn("Get rental validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await rentalService.getRental(value.rental_id, userData);

      if (!result.success) {
        return ResponseUtil.notFound(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "getRental" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to get rental"
      );
    }
  }

  /**
   * List rentals with filters
   * @route POST /api/v1/rentals/list
   */
  async listRentals(req, res, next) {
    try {
      const { error, value } = RentalValidator.validateListRentals(req.body);
      if (error) {
        logger.warn("List rentals validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const filters = {
        customer_id: value.customer_id,
        product_rental_status_id: value.product_rental_status_id,
        is_overdue: value.is_overdue,
        start_date_from: value.start_date_from,
        start_date_to: value.start_date_to,
      };
      const paginationParams = {
        page: value.page,
        limit: value.limit,
      };

      const result = await rentalService.listRentals(
        userData,
        filters,
        paginationParams
      );

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "listRentals" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to list rentals"
      );
    }
  }

  /**
   * Update rental details
   * @route POST /api/v1/rentals/update
   */
  async updateRental(req, res, next) {
    try {
      const { error, value } = RentalValidator.validateUpdateRental(req.body);
      if (error) {
        logger.warn("Update rental validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await rentalService.updateRental(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "updateRental" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to update rental"
      );
    }
  }

  /**
   * Return rental items
   * @route POST /api/v1/rentals/return
   */
  async returnRental(req, res, next) {
    try {
      const { error, value } = RentalValidator.validateReturnRental(req.body);
      if (error) {
        logger.warn("Return rental validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await rentalService.returnRental(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "returnRental" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to return rental"
      );
    }
  }

  /**
   * Record a payment for rental
   * @route POST /api/v1/rentals/record-payment
   */
  async recordPayment(req, res, next) {
    try {
      const { error, value } = RentalValidator.validateRecordPayment(req.body);
      if (error) {
        logger.warn("Record payment validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await rentalService.recordPayment(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.created(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "recordPayment" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to record payment"
      );
    }
  }

  /**
   * Get payments for a rental
   * @route POST /api/v1/rentals/get-payments
   */
  async getRentalPayments(req, res, next) {
    try {
      const { error, value } = RentalValidator.validateGetRentalPayments(
        req.body
      );
      if (error) {
        logger.warn("Get rental payments validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await rentalService.getRentalPayments(
        value.rental_id,
        userData
      );

      if (!result.success) {
        return ResponseUtil.notFound(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "getRentalPayments" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to get rental payments"
      );
    }
  }
}

module.exports = new RentalController();
