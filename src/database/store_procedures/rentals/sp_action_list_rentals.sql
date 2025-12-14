DROP PROCEDURE IF EXISTS sp_action_list_rentals;
CREATE PROCEDURE sp_action_list_rentals(
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_customer_id INT,
    IN  p_product_rental_status_id INT,
    IN  p_is_overdue TINYINT,
    IN  p_start_date_from TIMESTAMP(6),
    IN  p_start_date_to TIMESTAMP(6),
    IN  p_page INT,
    IN  p_limit INT,
    OUT p_success BOOLEAN,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(1000)
)
proc_exit: BEGIN

    DECLARE v_page INT DEFAULT 1;
    DECLARE v_limit INT DEFAULT 50;
    DECLARE v_offset INT DEFAULT 0;
    DECLARE v_total INT DEFAULT 0;

    SET p_success = FALSE;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    SET v_page = IFNULL(p_page, 1);
    IF v_page < 1 THEN SET v_page = 1; END IF;

    SET v_limit = IFNULL(p_limit, 50);
    IF v_limit < 1 THEN SET v_limit = 50; END IF;
    IF v_limit > 100 THEN SET v_limit = 100; END IF;

    SET v_offset = (v_page - 1) * v_limit;

    SELECT COUNT(*) INTO v_total
    FROM rental r
    WHERE r.business_id = p_business_id
      AND (p_branch_id IS NULL OR r.branch_id = p_branch_id)
      AND (p_customer_id IS NULL OR r.customer_id = p_customer_id)
      AND (p_product_rental_status_id IS NULL OR r.product_rental_status_id = p_product_rental_status_id)
      AND (p_is_overdue IS NULL OR r.is_overdue = p_is_overdue)
      AND (p_start_date_from IS NULL OR r.start_date >= p_start_date_from)
      AND (p_start_date_to IS NULL OR r.start_date <= p_start_date_to)
      AND r.is_deleted = 0;

    SET p_data = JSON_OBJECT(
      'rentals', (
        SELECT COALESCE(JSON_ARRAYAGG(
          JSON_OBJECT(
            'rental_id', x.rental_id,
            'customer_id', x.customer_id,
            'invoice_no', x.invoice_no,
            'start_date', x.start_date,
            'due_date', x.due_date,
            'end_date', x.end_date,
            'total_items', x.total_items,
            'total_amount', x.total_amount,
            'paid_amount', x.paid_amount,
            'is_overdue', x.is_overdue,
            'created_at', x.created_at,
            'customer_first_name', x.customer_first_name,
            'customer_last_name', x.customer_last_name,
            'customer_contact', x.customer_contact,
            'rental_status_name', x.rental_status_name,
            'rental_status_code', x.rental_status_code,
            'balance_amount', x.balance_amount
          )
        ), JSON_ARRAY())
        FROM (
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
            c.first_name AS customer_first_name,
            c.last_name AS customer_last_name,
            c.contact_number AS customer_contact,
            prs.name AS rental_status_name,
            prs.code AS rental_status_code,
            (r.total_amount - r.paid_amount) AS balance_amount
          FROM rental r
          LEFT JOIN customer c ON r.customer_id = c.customer_id
          LEFT JOIN product_rental_status prs ON r.product_rental_status_id = prs.product_rental_status_id
          WHERE r.business_id = p_business_id
            AND (p_branch_id IS NULL OR r.branch_id = p_branch_id)
            AND (p_customer_id IS NULL OR r.customer_id = p_customer_id)
            AND (p_product_rental_status_id IS NULL OR r.product_rental_status_id = p_product_rental_status_id)
            AND (p_is_overdue IS NULL OR r.is_overdue = p_is_overdue)
            AND (p_start_date_from IS NULL OR r.start_date >= p_start_date_from)
            AND (p_start_date_to IS NULL OR r.start_date <= p_start_date_to)
            AND r.is_deleted = 0
          ORDER BY r.created_at DESC, r.rental_id DESC
          LIMIT v_limit OFFSET v_offset
        ) x
      ),
      'pagination', JSON_OBJECT(
        'page', v_page,
        'limit', v_limit,
        'total', v_total,
        'total_pages', CEIL(v_total / v_limit),
        'has_next', v_page < CEIL(v_total / v_limit),
        'has_prev', v_page > 1
      )
    );

    SET p_success = TRUE;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Rentals retrieved successfully.';

END proc_exit;
