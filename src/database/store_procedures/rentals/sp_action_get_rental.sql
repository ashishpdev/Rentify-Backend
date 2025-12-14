DROP PROCEDURE IF EXISTS sp_action_get_rental;
CREATE PROCEDURE sp_action_get_rental(
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_rental_id INT,
    OUT p_success BOOLEAN,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(1000)
)
proc_exit: BEGIN

    SET p_success = FALSE;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_rental_id IS NULL OR p_rental_id <= 0 THEN
      SET p_error_code = 'ERR_INVALID_RENTAL_ID';
      SET p_error_message = 'Valid rental_id is required.';
      LEAVE proc_exit;
    END IF;

    IF NOT EXISTS (
      SELECT 1
      FROM rental r
      WHERE r.rental_id = p_rental_id
        AND r.business_id = p_business_id
        AND (p_branch_id IS NULL OR r.branch_id = p_branch_id)
        AND r.is_deleted = 0
      LIMIT 1
    ) THEN
      SET p_error_code = 'ERR_NOT_FOUND';
      SET p_error_message = 'Rental not found.';
      LEAVE proc_exit;
    END IF;

    SET p_data = (
      SELECT JSON_OBJECT(
        'rental', (
          SELECT JSON_OBJECT(
            'rental_id', r.rental_id,
            'business_id', r.business_id,
            'branch_id', r.branch_id,
            'customer_id', r.customer_id,
            'user_id', r.user_id,
            'invoice_no', r.invoice_no,
            'invoice_photo_id', r.invoice_photo_id,
            'invoice_date', r.invoice_date,
            'start_date', r.start_date,
            'due_date', r.due_date,
            'end_date', r.end_date,
            'total_items', r.total_items,
            'security_deposit', r.security_deposit,
            'subtotal_amount', r.subtotal_amount,
            'tax_amount', r.tax_amount,
            'discount_amount', r.discount_amount,
            'total_amount', r.total_amount,
            'paid_amount', r.paid_amount,
            'billing_period_id', r.billing_period_id,
            'currency', r.currency,
            'notes', r.notes,
            'product_rental_status_id', r.product_rental_status_id,
            'is_overdue', r.is_overdue,
            'created_by', r.created_by,
            'created_at', r.created_at,
            'updated_by', r.updated_by,
            'updated_at', r.updated_at,
            'customer_first_name', c.first_name,
            'customer_last_name', c.last_name,
            'customer_email', c.email,
            'customer_contact', c.contact_number,
            'rental_status_name', prs.name,
            'rental_status_code', prs.code,
            'billing_period_name', bp.name,
            'billing_period_code', bp.code,
            'invoice_url', ip.invoice_url
          )
          FROM rental r
          LEFT JOIN customer c ON r.customer_id = c.customer_id
          LEFT JOIN product_rental_status prs ON r.product_rental_status_id = prs.product_rental_status_id
          LEFT JOIN billing_period bp ON r.billing_period_id = bp.billing_period_id
          LEFT JOIN invoice_photos ip ON r.invoice_photo_id = ip.invoice_photo_id
          WHERE r.rental_id = p_rental_id
            AND r.business_id = p_business_id
            AND (p_branch_id IS NULL OR r.branch_id = p_branch_id)
            AND r.is_deleted = 0
          LIMIT 1
        ),
        'items', (
          SELECT COALESCE(JSON_ARRAYAGG(
            JSON_OBJECT(
              'rental_item_id', ri.rental_item_id,
              'rental_id', ri.rental_id,
              'asset_id', ri.asset_id,
              'product_model_id', ri.product_model_id,
              'rent_price', ri.rent_price,
              'notes', ri.notes,
              'created_at', ri.created_at,
              'serial_number', a.serial_number,
              'model_name', pm.model_name,
              'category_name', pc.name,
              'segment_name', ps.name,
              'item_status_name', prs2.name,
              'item_status_code', prs2.code
            )
          ), JSON_ARRAY())
          FROM rental_item ri
          LEFT JOIN asset a ON ri.asset_id = a.asset_id
          LEFT JOIN product_model pm ON ri.product_model_id = pm.product_model_id
          LEFT JOIN product_category pc ON ri.product_category_id = pc.product_category_id
          LEFT JOIN product_segment ps ON ri.product_segment_id = ps.product_segment_id
          LEFT JOIN product_rental_status prs2 ON ri.product_rental_status_id = prs2.product_rental_status_id
          WHERE ri.rental_id = p_rental_id
        )
      )
    );

    SET p_success = TRUE;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Rental retrieved successfully.';

END proc_exit;
