// src/modules/rentals/rentals.repository.js
const db = require("../../database/connection");
const logger = require("../../config/logger.config");

class RentalRepository {
  /**
   * Issue a new rental using sp_action_issue_rental
   */
  async issueRental(params) {
    try {
      // Convert asset_ids array to JSON string for MySQL
      const assetIdsJson = JSON.stringify(params.assetIds);

      await db.executeSP(
        `CALL sp_action_issue_rental(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
          @p_success, @p_rental_id, @p_error_code, @p_error_message)`,
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
          params.rentPricePerItem,
          params.referenceNo,
          params.notes,
        ]
      );

      const output = await db.executeSelect(
        `SELECT 
          @p_success AS success,
          @p_rental_id AS rental_id,
          @p_error_code AS error_code,
          @p_error_message AS error_message`
      );

      const success = output.success == 1;

      if (!success) {
        logger.warn("Issue rental procedure returned error", {
          errorCode: output.error_code,
          errorMessage: output.error_message,
        });
      }

      return {
        success,
        rentalId: output.rental_id,
        errorCode: output.error_code,
        message: output.error_message || "Rental issued successfully",
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
      const query = `
        SELECT 
          r.rental_id,
          r.business_id,
          r.branch_id,
          r.customer_id,
          r.user_id,
          r.invoice_no,
          r.invoice_photo_id,
          r.invoice_date,
          r.start_date,
          r.due_date,
          r.end_date,
          r.total_items,
          r.security_deposit,
          r.subtotal_amount,
          r.tax_amount,
          r.discount_amount,
          r.total_amount,
          r.paid_amount,
          r.billing_period_id,
          r.currency,
          r.notes,
          r.product_rental_status_id,
          r.is_overdue,
          r.created_by,
          r.created_at,
          r.updated_by,
          r.updated_at,
          
          -- Customer details
          c.first_name AS customer_first_name,
          c.last_name AS customer_last_name,
          c.email AS customer_email,
          c.contact_number AS customer_contact,
          
          -- Rental status
          prs.name AS rental_status_name,
          prs.code AS rental_status_code,
          
          -- Billing period
          bp.name AS billing_period_name,
          bp.code AS billing_period_code,
          
          -- Invoice photo
          ip.invoice_url
          
        FROM rental r
        LEFT JOIN customer c ON r.customer_id = c.customer_id
        LEFT JOIN product_rental_status prs ON r.product_rental_status_id = prs.product_rental_status_id
        LEFT JOIN billing_period bp ON r.billing_period_id = bp.billing_period_id
        LEFT JOIN invoice_photos ip ON r.invoice_photo_id = ip.invoice_photo_id
        WHERE r.rental_id = ?
          AND r.business_id = ?
          AND (? IS NULL OR r.branch_id = ?)
          AND r.is_deleted = 0
        LIMIT 1
      `;

      const rental = await db.executeSelect(query, [
        rentalId,
        businessId,
        branchId,
        branchId,
      ]);

      if (!rental) {
        return {
          success: false,
          data: null,
          message: "Rental not found",
        };
      }

      // Get rental items
      const itemsQuery = `
        SELECT 
          ri.rental_item_id,
          ri.rental_id,
          ri.asset_id,
          ri.product_model_id,
          ri.rent_price,
          ri.notes,
          ri.created_at,
          
          -- Asset details
          a.serial_number,
          
          -- Model details
          pm.model_name,
          
          -- Category details
          pc.name AS category_name,
          
          -- Segment details
          ps.name AS segment_name,
          
          -- Rental item status
          prs.name AS item_status_name,
          prs.code AS item_status_code
          
        FROM rental_item ri
        LEFT JOIN asset a ON ri.asset_id = a.asset_id
        LEFT JOIN product_model pm ON ri.product_model_id = pm.product_model_id
        LEFT JOIN product_category pc ON ri.product_category_id = pc.product_category_id
        LEFT JOIN product_segment ps ON ri.product_segment_id = ps.product_segment_id
        LEFT JOIN product_rental_status prs ON ri.product_rental_status_id = prs.product_rental_status_id
        WHERE ri.rental_id = ?
        ORDER BY ri.rental_item_id
      `;

      const items = await db.executeSelect(itemsQuery, [rentalId]);

      return {
        success: true,
        data: {
          ...rental,
          items: items || [],
        },
        message: "Rental retrieved successfully",
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
      let conditions = ["r.business_id = ?", "r.is_deleted = 0"];
      let params = [businessId];

      if (branchId) {
        conditions.push("r.branch_id = ?");
        params.push(branchId);
      }

      if (filters.customerId) {
        conditions.push("r.customer_id = ?");
        params.push(filters.customerId);
      }

      if (filters.productRentalStatusId) {
        conditions.push("r.product_rental_status_id = ?");
        params.push(filters.productRentalStatusId);
      }

      if (filters.isOverdue !== undefined) {
        conditions.push("r.is_overdue = ?");
        params.push(filters.isOverdue ? 1 : 0);
      }

      if (filters.startDateFrom) {
        conditions.push("r.start_date >= ?");
        params.push(filters.startDateFrom);
      }

      if (filters.startDateTo) {
        conditions.push("r.start_date <= ?");
        params.push(filters.startDateTo);
      }

      const whereClause = conditions.join(" AND ");

      const query = `
        SELECT 
          r.rental_id,
          r.customer_id,
          r.invoice_no,
          r.start_date,
          r.due_date,
          r.end_date,
          r.total_items,
          r.total_amount,
          r.paid_amount,
          r.is_overdue,
          r.created_at,
          
          -- Customer details
          c.first_name AS customer_first_name,
          c.last_name AS customer_last_name,
          c.contact_number AS customer_contact,
          
          -- Rental status
          prs.name AS rental_status_name,
          prs.code AS rental_status_code,
          
          -- Balance amount
          (r.total_amount - r.paid_amount) AS balance_amount
          
        FROM rental r
        LEFT JOIN customer c ON r.customer_id = c.customer_id
        LEFT JOIN product_rental_status prs ON r.product_rental_status_id = prs.product_rental_status_id
        WHERE ${whereClause}
        ORDER BY r.created_at DESC, r.rental_id DESC
      `;

      const rentals = await db.executeSelect(query, params);

      return {
        success: true,
        data: rentals || [],
        message: "Rentals retrieved successfully",
      };
    } catch (error) {
      logger.error("RentalRepository.listRentals error", {
        error: error.message,
      });

      return {
        success: false,
        data: [],
        message: error.message || "Failed to list rentals",
      };
    }
  }

  /**
   * Update rental details
   */
  async updateRental(businessId, branchId, rentalId, updates, userId) {
    try {
      let setClauses = [];
      let params = [];

      if (updates.dueDate !== undefined) {
        setClauses.push("due_date = ?");
        params.push(updates.dueDate);
      }

      if (updates.notes !== undefined) {
        setClauses.push("notes = ?");
        params.push(updates.notes);
      }

      if (updates.productRentalStatusId !== undefined) {
        setClauses.push("product_rental_status_id = ?");
        params.push(updates.productRentalStatusId);
      }

      if (setClauses.length === 0) {
        return {
          success: false,
          message: "No fields to update",
        };
      }

      setClauses.push("updated_by = ?");
      setClauses.push("updated_at = UTC_TIMESTAMP(6)");
      params.push(userId);

      // Add WHERE conditions
      params.push(rentalId, businessId);
      if (branchId) {
        params.push(branchId);
      }

      const query = `
        UPDATE rental
        SET ${setClauses.join(", ")}
        WHERE rental_id = ?
          AND business_id = ?
          ${branchId ? "AND branch_id = ?" : ""}
          AND is_deleted = 0
      `;

      const result = await db.executeUpdate(query, params);

      if (result.affectedRows === 0) {
        return {
          success: false,
          message: "Rental not found or no changes made",
        };
      }

      return {
        success: true,
        message: "Rental updated successfully",
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
  async returnRental(businessId, branchId, rentalId, endDate, notes, userId) {
    try {
      await db.executeTransaction(async (connection) => {
        // Get rental and asset information
        const rentalQuery = `
          SELECT 
            r.rental_id,
            r.product_rental_status_id,
            ri.rental_item_id,
            ri.asset_id,
            a.product_status_id
          FROM rental r
          JOIN rental_item ri ON r.rental_id = ri.rental_id
          JOIN asset a ON ri.asset_id = a.asset_id
          WHERE r.rental_id = ?
            AND r.business_id = ?
            ${branchId ? "AND r.branch_id = ?" : ""}
            AND r.is_deleted = 0
        `;

        const params = branchId
          ? [rentalId, businessId, branchId]
          : [rentalId, businessId];
        const rentalData = await db.executeSelect(rentalQuery, params);

        if (!rentalData || rentalData.length === 0) {
          throw new Error("Rental not found");
        }

        // Get status IDs
        const returnedStatusQuery = `
          SELECT product_rental_status_id 
          FROM product_rental_status 
          WHERE code = 'RETURNED' 
          LIMIT 1
        `;
        const returnedStatus = await db.executeSelect(returnedStatusQuery);

        const availableStatusQuery = `
          SELECT product_status_id 
          FROM product_status 
          WHERE code = 'AVAILABLE' 
          LIMIT 1
        `;
        const availableStatus = await db.executeSelect(availableStatusQuery);

        const returnedStatusId = returnedStatus.product_rental_status_id;
        const availableStatusId = availableStatus.product_status_id;

        // Update rental header
        const updateRentalQuery = `
          UPDATE rental
          SET end_date = ?,
              product_rental_status_id = ?,
              notes = CONCAT(IFNULL(notes, ''), ?, ?),
              updated_by = ?,
              updated_at = UTC_TIMESTAMP(6)
          WHERE rental_id = ?
        `;
        await db.executeUpdate(updateRentalQuery, [
          endDate,
          returnedStatusId,
          notes ? "\n" : "",
          notes || "",
          userId,
          rentalId,
        ]);

        // Update rental items status
        const updateItemsQuery = `
          UPDATE rental_item
          SET product_rental_status_id = ?,
              updated_by = ?,
              updated_at = UTC_TIMESTAMP(6)
          WHERE rental_id = ?
        `;
        await db.executeUpdate(updateItemsQuery, [
          returnedStatusId,
          userId,
          rentalId,
        ]);

        // Update asset statuses back to AVAILABLE
        for (const item of rentalData) {
          const updateAssetQuery = `
            UPDATE asset
            SET product_status_id = ?,
                updated_by = ?,
                updated_at = UTC_TIMESTAMP(6)
            WHERE asset_id = ?
          `;
          await db.executeUpdate(updateAssetQuery, [
            availableStatusId,
            userId,
            item.asset_id,
          ]);
        }
      });

      return {
        success: true,
        message: "Rental returned successfully",
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
      const query = `
        INSERT INTO rental_payments (
          business_id,
          branch_id,
          rental_id,
          paid_on,
          amount,
          mode_of_payment_id,
          reference_no,
          notes,
          created_by,
          created_at
        ) VALUES (?, ?, ?, UTC_TIMESTAMP(6), ?, ?, ?, ?, ?, UTC_TIMESTAMP(6))
      `;

      await db.executeInsert(query, [
        params.businessId,
        params.branchId,
        params.rentalId,
        params.amount,
        params.modeOfPaymentId,
        params.referenceNo,
        params.notes,
        params.userId,
      ]);

      // Update paid_amount in rental
      const updateQuery = `
        UPDATE rental
        SET paid_amount = paid_amount + ?,
            updated_by = ?,
            updated_at = UTC_TIMESTAMP(6)
        WHERE rental_id = ?
          AND business_id = ?
      `;

      await db.executeUpdate(updateQuery, [
        params.amount,
        params.userId,
        params.rentalId,
        params.businessId,
      ]);

      return {
        success: true,
        message: "Payment recorded successfully",
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
      const query = `
        SELECT 
          rp.rental_payment_id,
          rp.rental_id,
          rp.paid_on,
          rp.amount,
          rp.mode_of_payment_id,
          rp.reference_no,
          rp.notes,
          rp.created_by,
          rp.created_at,
          
          -- Payment mode details
          pm.name AS payment_mode_name,
          pm.code AS payment_mode_code
          
        FROM rental_payments rp
        LEFT JOIN payment_mode pm ON rp.mode_of_payment_id = pm.payment_mode_id
        WHERE rp.rental_id = ?
          AND rp.business_id = ?
          ${branchId ? "AND rp.branch_id = ?" : ""}
          AND rp.is_deleted = 0
        ORDER BY rp.paid_on DESC, rp.rental_payment_id DESC
      `;

      const params = branchId
        ? [rentalId, businessId, branchId]
        : [rentalId, businessId];
      const payments = await db.executeSelect(query, params);

      return {
        success: true,
        data: payments || [],
        message: "Payments retrieved successfully",
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
