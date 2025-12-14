// src/modules/rentals/rentals.repository.js
const db = require("../../database/connection");
const logger = require("../../config/logger.config");

class RentalRepository {
  async #execSpWithOutSelect(callSql, params, outSelectSql) {
    await db.executeSP(callSql, params);
    return db.executeSelect(outSelectSql);
  }

  #parseJsonMaybe(v, fallback) {
    if (v == null) return fallback;
    if (typeof v === "object") return v;
    try {
      return JSON.parse(v);
    } catch (_) {
      return fallback;
    }
  }

  /**
   * Issue a new rental using sp_action_issue_rental
   */
  async issueRental(params) {
    try {
      const assetIdsJson = JSON.stringify(params.assetIds);

      const output = await this.#execSpWithOutSelect(
        `CALL sp_action_issue_rental(
          ?, ?, ?, ?, ?,
          ?, ?, ?, ?, ?,
          ?,
          ?, ?, ?, ?, ?, ?, ?,
          ?, ?,
          @p_success, @p_rental_id, @p_error_code, @p_error_message
        )`,
        [
          params.businessId,
          params.branchId,
          params.customerId,
          params.userId,
          params.roleId,

          params.invoiceUrl,
          params.invoiceNo,
          params.startDate,
          params.dueDate,
          params.billingPeriodId,

          assetIdsJson,

          params.totalItems,
          params.securityDeposit,
          params.subtotalAmount,
          params.taxAmount,
          params.discountAmount,
          params.totalAmount,
          params.paidAmount,

          params.referenceNo,
          params.notes,
        ],
        `SELECT 
          @p_success AS success,
          @p_rental_id AS rental_id,
          @p_error_code AS error_code,
          @p_error_message AS error_message`
      );

      const success = output?.success == 1;

      if (!success) {
        logger.warn("Issue rental procedure returned error", {
          errorCode: output?.error_code,
          errorMessage: output?.error_message,
        });
      }

      return {
        success,
        rentalId: output?.rental_id,
        errorCode: output?.error_code,
        message: output?.error_message || "Rental issued successfully",
      };
    } catch (error) {
      logger.error("RentalRepository.issueRental error", {
        error: error.message,
      });

      return {
        success: false,
        rentalId: null,
        errorCode: "ERR_DATABASE_ERROR",
        message: error.message || "Unexpected database error occurred.",
      };
    }
  }

  /**
   * Get rental details by ID
   */
  async getRental(businessId, branchId, rentalId) {
    try {
      const output = await this.#execSpWithOutSelect(
        `CALL sp_action_get_rental(?, ?, ?, @p_success, @p_data, @p_error_code, @p_error_message)`,
        [businessId, branchId, rentalId],
        `SELECT @p_success success, @p_data data, @p_error_code error_code, @p_error_message error_message`
      );

      const success = output?.success == 1;
      const parsed = this.#parseJsonMaybe(output?.data, null);

      if (!success) {
        logger.warn("sp_action_get_rental not found", {
          businessId,
          branchId,
          rentalId,
          errorCode: output?.error_code,
          errorMessage: output?.error_message,
        });
        return {
          success: false,
          data: null,
          message: output?.error_message || "Rental not found",
        };
      }

      return {
        success: true,
        data: {
          ...(parsed?.rental || {}),
          items: parsed?.items || [],
        },
        message: output?.error_message || "Rental retrieved successfully",
      };
    } catch (error) {
      logger.error("RentalRepository.getRental error", {
        rentalId,
        error: error.message,
      });

      return {
        success: false,
        data: null,
        message: error.message || "Failed to retrieve rental",
      };
    }
  }

  /**
   * List rentals with filters
   */
  async listRentals(businessId, branchId, filters = {}) {
    try {
      const output = await this.#execSpWithOutSelect(
        `CALL sp_action_list_rentals(?, ?, ?, ?, ?, ?, ?, ?, ?, @p_success, @p_data, @p_error_code, @p_error_message)`,
        [
          businessId,
          branchId,
          filters.customerId || null,
          filters.productRentalStatusId || null,
          filters.isOverdue === undefined ? null : filters.isOverdue ? 1 : 0,
          filters.startDateFrom || null,
          filters.startDateTo || null,
          filters.page || 1,
          filters.limit || 50,
        ],
        `SELECT @p_success success, @p_data data, @p_error_code error_code, @p_error_message error_message`
      );

      const success = output?.success == 1;
      const parsed = this.#parseJsonMaybe(output?.data, {
        rentals: [],
        pagination: null,
      });

      if (!success) {
        return {
          success: false,
          data: { rentals: [], pagination: null },
          message: output?.error_message || "Failed to list rentals",
        };
      }

      return {
        success: true,
        data: parsed,
        message: output?.error_message || "Rentals retrieved successfully",
      };
    } catch (error) {
      logger.error("RentalRepository.listRentals error", {
        error: error.message,
      });

      return {
        success: false,
        data: { rentals: [], pagination: null },
        message: error.message || "Failed to list rentals",
      };
    }
  }

  /**
   * Update rental details
   */
  async updateRental(businessId, branchId, rentalId, updates, userId) {
    try {
      const output = await this.#execSpWithOutSelect(
        `CALL sp_action_update_rental(?, ?, ?, ?, ?, ?, ?, ?, @p_success, @p_error_code, @p_error_message)`,
        [
          businessId,
          branchId,
          rentalId,
          updates.dueDate ?? null,
          updates.notes ?? null,
          updates.productRentalStatusId ?? null,
          userId,
          updates.roleId ?? null,
        ],
        `SELECT @p_success success, @p_error_code error_code, @p_error_message error_message`
      );

      const success = output?.success == 1;
      return {
        success,
        message:
          output?.error_message ||
          (success ? "Rental updated successfully" : "Failed to update rental"),
        errorCode: output?.error_code,
      };
    } catch (error) {
      logger.error("RentalRepository.updateRental error", {
        rentalId,
        error: error.message,
      });

      return {
        success: false,
        message: error.message || "Failed to update rental",
      };
    }
  }

  /**
   * Return rental items and mark as returned
   */
  async returnRental(
    businessId,
    branchId,
    rentalId,
    endDate,
    notes,
    userId,
    roleId = null
  ) {
    try {
      const output = await this.#execSpWithOutSelect(
        `CALL sp_action_return_rental(?, ?, ?, ?, ?, ?, ?, @p_success, @p_error_code, @p_error_message)`,
        [businessId, branchId, rentalId, endDate, notes, userId, roleId],
        `SELECT @p_success success, @p_error_code error_code, @p_error_message error_message`
      );
      const success = output?.success == 1;
      return {
        success,
        message:
          output?.error_message ||
          (success
            ? "Rental returned successfully"
            : "Failed to return rental"),
        errorCode: output?.error_code,
      };
    } catch (error) {
      logger.error("RentalRepository.returnRental error", {
        rentalId,
        error: error.message,
      });

      return {
        success: false,
        message: error.message || "Failed to return rental",
      };
    }
  }

  /**
   * Record a payment for rental
   */
  async recordPayment(params) {
    try {
      const output = await this.#execSpWithOutSelect(
        `CALL sp_action_record_rental_payment(?, ?, ?, ?, ?, ?, ?, ?, ?, @p_success, @p_payment_id, @p_error_code, @p_error_message)`,
        [
          params.businessId,
          params.branchId,
          params.rentalId,
          params.amount,
          params.modeOfPaymentId,
          params.referenceNo,
          params.notes,
          params.userId,
          params.roleId,
        ],
        `SELECT @p_success success, @p_payment_id payment_id, @p_error_code error_code, @p_error_message error_message`
      );

      const success = output?.success == 1;
      return {
        success,
        paymentId: output?.payment_id,
        message:
          output?.error_message ||
          (success
            ? "Payment recorded successfully"
            : "Failed to record payment"),
        errorCode: output?.error_code,
      };
    } catch (error) {
      logger.error("RentalRepository.recordPayment error", {
        rentalId: params.rentalId,
        error: error.message,
      });

      return {
        success: false,
        message: error.message || "Failed to record payment",
      };
    }
  }

  /**
   * Get payments for a rental
   */
  async getRentalPayments(businessId, branchId, rentalId) {
    try {
      const output = await this.#execSpWithOutSelect(
        `CALL sp_action_get_rental_payments(?, ?, ?, @p_success, @p_data, @p_error_code, @p_error_message)`,
        [businessId, branchId, rentalId],
        `SELECT @p_success success, @p_data data, @p_error_code error_code, @p_error_message error_message`
      );

      const success = output?.success == 1;
      const parsed = this.#parseJsonMaybe(output?.data, []);
      return {
        success,
        data: parsed,
        message:
          output?.error_message ||
          (success
            ? "Payments retrieved successfully"
            : "Failed to retrieve payments"),
        errorCode: output?.error_code,
      };
    } catch (error) {
      logger.error("RentalRepository.getRentalPayments error", {
        rentalId,
        error: error.message,
      });

      return {
        success: false,
        data: [],
        message: error.message || "Failed to retrieve payments",
      };
    }
  }
}

module.exports = new RentalRepository();
