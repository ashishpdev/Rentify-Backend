// src/modules/rentals/rentals.service.js
const rentalRepository = require("./rentals.repository");
const logger = require("../../config/logger.config");

class RentalService {
  /**
   * Issue a new rental
   */
  async issueRental(rentalData, userData) {
    try {
      // Validate dates
      const startDate = new Date(rentalData.start_date);
      const dueDate = new Date(rentalData.due_date);

      if (dueDate <= startDate) {
        return {
          success: false,
          message: "Due date must be after start date",
          data: null,
        };
      }

      const result = await rentalRepository.issueRental({
        businessId: userData.business_id,
        branchId: userData.branch_id,
        customerId: rentalData.customer_id,
        userId: userData.user_id,
        roleId: userData.role_id,
        invoiceUrl: rentalData.invoice_url || null,
        invoiceNo: rentalData.invoice_no,
        startDate: rentalData.start_date,
        dueDate: rentalData.due_date,
        billingPeriodId: rentalData.billing_period_id,
        assetIds: rentalData.asset_ids,
        rentPricePerItem: rentalData.rent_price_per_item,
        referenceNo: rentalData.reference_no || null,
        notes: rentalData.notes || null,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { rental_id: result.rentalId } : null,
      };
    } catch (error) {
      logger.error("RentalService.issueRental error", {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get rental details
   */
  async getRental(rentalId, userData) {
    try {
      const result = await rentalRepository.getRental(
        userData.business_id,
        userData.branch_id,
        rentalId
      );

      if (!result.success || !result.data) {
        return {
          success: false,
          message: "Rental not found",
          data: null,
        };
      }

      return {
        success: true,
        message: "Rental retrieved successfully",
        data: { rental: result.data },
      };
    } catch (error) {
      logger.error("RentalService.getRental error", {
        rentalId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * List rentals with filters and pagination
   */
  async listRentals(userData, filters = {}, paginationParams = {}) {
    try {
      const result = await rentalRepository.listRentals(
        userData.business_id,
        userData.branch_id,
        {
          customerId: filters.customer_id,
          productRentalStatusId: filters.product_rental_status_id,
          isOverdue: filters.is_overdue,
          startDateFrom: filters.start_date_from,
          startDateTo: filters.start_date_to,
        }
      );

      // Apply pagination
      const allRentals = result.data || [];
      const total = allRentals.length;
      const page = paginationParams.page || 1;
      const limit = paginationParams.limit || 50;
      const totalPages = Math.ceil(total / limit);
      const startIndex = (page - 1) * limit;
      const endIndex = startIndex + limit;
      const paginatedRentals = allRentals.slice(startIndex, endIndex);

      return {
        success: result.success,
        message: result.message,
        data: {
          rentals: paginatedRentals,
          pagination: {
            page: page,
            limit: limit,
            total: total,
            total_pages: totalPages,
            has_next: page < totalPages,
            has_prev: page > 1,
          },
        },
      };
    } catch (error) {
      logger.error("RentalService.listRentals error", {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update rental details
   */
  async updateRental(rentalData, userData) {
    try {
      const updates = {};

      if (rentalData.due_date !== undefined) {
        // Validate due date if provided
        const dueDate = new Date(rentalData.due_date);
        if (isNaN(dueDate.getTime())) {
          return {
            success: false,
            message: "Invalid due date format",
            data: null,
          };
        }
        updates.dueDate = rentalData.due_date;
      }

      if (rentalData.notes !== undefined) {
        updates.notes = rentalData.notes;
      }

      if (rentalData.product_rental_status_id !== undefined) {
        updates.productRentalStatusId = rentalData.product_rental_status_id;
      }

      const result = await rentalRepository.updateRental(
        userData.business_id,
        userData.branch_id,
        rentalData.rental_id,
        updates,
        userData.user_id
      );

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { rental_id: rentalData.rental_id } : null,
      };
    } catch (error) {
      logger.error("RentalService.updateRental error", {
        rentalId: rentalData.rental_id,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Return rental items
   */
  async returnRental(rentalData, userData) {
    try {
      // Validate end date
      const endDate = new Date(rentalData.end_date);
      if (isNaN(endDate.getTime())) {
        return {
          success: false,
          message: "Invalid end date format",
          data: null,
        };
      }

      const result = await rentalRepository.returnRental(
        userData.business_id,
        userData.branch_id,
        rentalData.rental_id,
        rentalData.end_date,
        rentalData.notes || null,
        userData.user_id
      );

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { rental_id: rentalData.rental_id } : null,
      };
    } catch (error) {
      logger.error("RentalService.returnRental error", {
        rentalId: rentalData.rental_id,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Record a payment for rental
   */
  async recordPayment(paymentData, userData) {
    try {
      const result = await rentalRepository.recordPayment({
        businessId: userData.business_id,
        branchId: userData.branch_id,
        rentalId: paymentData.rental_id,
        amount: paymentData.amount,
        modeOfPaymentId: paymentData.mode_of_payment_id,
        referenceNo: paymentData.reference_no || null,
        notes: paymentData.notes || null,
        userId: userData.user_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success ? { rental_id: paymentData.rental_id } : null,
      };
    } catch (error) {
      logger.error("RentalService.recordPayment error", {
        rentalId: paymentData.rental_id,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get payments for a rental
   */
  async getRentalPayments(rentalId, userData) {
    try {
      const result = await rentalRepository.getRentalPayments(
        userData.business_id,
        userData.branch_id,
        rentalId
      );

      // Calculate summary
      const payments = result.data || [];
      const totalPaid = payments.reduce(
        (sum, payment) => sum + parseFloat(payment.amount || 0),
        0
      );

      return {
        success: result.success,
        message: result.message,
        data: {
          payments: payments,
          summary: {
            total_payments: payments.length,
            total_paid: totalPaid.toFixed(2),
          },
        },
      };
    } catch (error) {
      logger.error("RentalService.getRentalPayments error", {
        rentalId,
        error: error.message,
      });
      throw error;
    }
  }
}

module.exports = new RentalService();
