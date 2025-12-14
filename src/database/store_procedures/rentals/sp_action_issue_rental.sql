DROP PROCEDURE IF EXISTS sp_action_issue_rental;
CREATE PROCEDURE sp_action_issue_rental(
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_customer_id INT,
    IN  p_user_id INT,
    IN  p_role_id INT,
    IN  p_invoice_url VARCHAR(2048),
    IN  p_invoice_no VARCHAR(255),
    IN  p_start_date TIMESTAMP(6),
    IN  p_due_date TIMESTAMP(6),
    IN  p_billing_period_id INT,
    IN  p_asset_ids_json JSON,       -- JSON array [1,2,3]
    IN  p_rent_price_per_item DECIMAL(14,2),
    IN  p_reference_no VARCHAR(255),
    IN  p_notes TEXT,
    OUT p_success BOOLEAN,
    OUT p_rental_id INT,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(1000)
)
proc_exit: BEGIN
    DECLARE v_available_status INT;
    DECLARE v_rented_status INT;
    DECLARE v_rental_status_active INT;
    DECLARE v_rental_out_movement INT;
    DECLARE v_row_count INT DEFAULT 0;
    DECLARE v_invoice_photo_id INT DEFAULT NULL;
    DECLARE v_rental_id_local INT DEFAULT NULL;

    SET p_success = FALSE;
    SET p_rental_id = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_asset_ids_json IS NULL OR JSON_VALID(p_asset_ids_json) = 0 OR JSON_LENGTH(p_asset_ids_json) = 0 THEN
        SET p_error_code = 'ERR_NO_ASSET_LIST';
        SET p_error_message = 'p_asset_ids_json must be a non-empty valid JSON array.';
        LEAVE proc_exit;
    END IF;

    -- lookups
    SELECT product_status_id INTO v_available_status FROM product_status WHERE code = 'AVAILABLE' LIMIT 1;
    SELECT product_status_id INTO v_rented_status   FROM product_status WHERE code = 'RENTED'   LIMIT 1;
    SELECT product_rental_status_id INTO v_rental_status_active FROM product_rental_status WHERE code = 'ACTIVE' LIMIT 1;
    SELECT inventory_movement_type_id INTO v_rental_out_movement FROM inventory_movement_type WHERE code = 'RENTAL_OUT' LIMIT 1;

    IF v_available_status IS NULL OR v_rented_status IS NULL OR v_rental_status_active IS NULL OR v_rental_out_movement IS NULL THEN
        SET p_error_code = 'ERR_LOOKUP_MISSING';
        SET p_error_message = 'Required lookup rows missing.';
        LEAVE proc_exit;
    END IF;

    START TRANSACTION;

    -- temp list + deterministic ordering to avoid deadlocks
    DROP TEMPORARY TABLE IF EXISTS tmp_asset_ids;
    CREATE TEMPORARY TABLE tmp_asset_ids (asset_id INT PRIMARY KEY) ENGINE=MEMORY;

    INSERT INTO tmp_asset_ids (asset_id)
    SELECT DISTINCT CAST(jt.asset_id AS SIGNED)
    FROM JSON_TABLE(p_asset_ids_json, '$[*]' COLUMNS (asset_id VARCHAR(50) PATH '$')) AS jt
    ORDER BY CAST(jt.asset_id AS SIGNED) ASC;

    SELECT COUNT(*) INTO v_row_count FROM tmp_asset_ids;
    IF v_row_count = 0 THEN
        ROLLBACK;
        SET p_error_code = 'ERR_NO_ASSETS';
        SET p_error_message = 'No assets found for provided ids.';
        LEAVE proc_exit;
    END IF;

    -- Lock the asset rows to prevent double-booking
    DROP TEMPORARY TABLE IF EXISTS tmp_asset_rows;
    CREATE TEMPORARY TABLE tmp_asset_rows (
      asset_id INT PRIMARY KEY,
      product_model_id INT,
      rent_price DECIMAL(14,2),
      business_id INT, branch_id INT
    ) ENGINE=MEMORY;

    INSERT INTO tmp_asset_rows (asset_id, product_model_id, rent_price, business_id, branch_id)
    SELECT a.asset_id, a.product_model_id, IFNULL(a.rent_price, p_rent_price_per_item), a.business_id, a.branch_id
    FROM asset a
    JOIN tmp_asset_ids t ON t.asset_id = a.asset_id
    WHERE a.business_id = p_business_id
      AND (p_branch_id IS NULL OR a.branch_id = p_branch_id)
      AND a.is_deleted = 0
    ORDER BY a.asset_id ASC
    FOR UPDATE;

    -- verify count matched
    SELECT COUNT(*) INTO v_row_count FROM tmp_asset_rows;
    IF v_row_count <> (SELECT COUNT(*) FROM tmp_asset_ids) THEN
        ROLLBACK;
        SET p_error_code = 'ERR_ASSET_MISMATCH';
        SET p_error_message = 'One or more assets not found or deleted.';
        LEAVE proc_exit;
    END IF;

    -- ensure all are available
    IF EXISTS (
      SELECT 1
      FROM asset a
      JOIN tmp_asset_rows t ON a.asset_id = t.asset_id
      WHERE a.product_status_id <> v_available_status
    ) THEN
      ROLLBACK;
      SET p_error_code = 'ERR_ASSET_NOT_AVAILABLE';
      SET p_error_message = 'One or more assets are not AVAILABLE.';
      LEAVE proc_exit;
    END IF;

    /* invoice_photos */
    -- invoice photo (if any)
    IF p_invoice_url IS NOT NULL AND TRIM(p_invoice_url) <> '' THEN
      INSERT INTO invoice_photos (business_id, branch_id, customer_id, invoice_url, created_by)
      VALUES (p_business_id, p_branch_id, p_customer_id, p_invoice_url, p_user_id);
      SET v_invoice_photo_id = LAST_INSERT_ID();
    END IF;

    /* rental */
    -- create rental header (include product_rental_status_id to satisfy FK)
    INSERT INTO rental (
      business_id, branch_id, customer_id, user_id, invoice_no, invoice_photo_id,
      invoice_date, start_date, due_date, subtotal_amount, total_amount, billing_period_id,
      currency, notes, product_rental_status_id, created_by, created_at
    ) VALUES (
      p_business_id, p_branch_id, p_customer_id, p_user_id, p_invoice_no, v_invoice_photo_id,
      UTC_TIMESTAMP(6), p_start_date, p_due_date, 0.00, 0.00, p_billing_period_id,
      'INR', p_notes, v_rental_status_active, p_user_id, UTC_TIMESTAMP(6)
    );
    SET v_rental_id_local = LAST_INSERT_ID();

    /* rental_items */
    -- bulk insert rental_item with rental_id FK (fast)
    INSERT INTO rental_item (
      rental_id, business_id, branch_id, product_segment_id, product_category_id, product_model_id,
      asset_id, product_rental_status_id, customer_id, rent_price, notes, created_by, created_at
    )
    SELECT
      v_rental_id_local,
      a.business_id,
      a.branch_id,
      a.product_segment_id,
      a.product_category_id,
      a.product_model_id,
      a.asset_id,
      v_rental_status_active,
      p_customer_id,
      IFNULL(a.rent_price, p_rent_price_per_item),
      p_notes,
      p_user_id,
      UTC_TIMESTAMP(6)
    FROM asset a
    JOIN tmp_asset_rows t ON a.asset_id = t.asset_id;

    /* asset */
    -- update assets in bulk to RENTED
    UPDATE asset a
    JOIN tmp_asset_rows t ON a.asset_id = t.asset_id
    SET a.product_status_id = v_rented_status,
        a.updated_by = p_user_id,
        a.updated_at = UTC_TIMESTAMP(6);

    /* asset_movements*/
    -- insert asset_movements in bulk
    INSERT INTO asset_movements (
      business_id, branch_id, product_model_id, asset_id,
      inventory_movement_type_id, from_product_status_id, to_product_status_id,
      related_rental_id, reference_no, note, metadata, created_by, created_at
    )
    SELECT
      a.business_id,
      a.branch_id,
      a.product_model_id,
      a.asset_id,
      v_rental_out_movement,
      v_available_status,
      v_rented_status,
      v_rental_id_local,
      p_reference_no,
      p_notes,
      JSON_OBJECT('updated_by', p_user_id),
      p_user_id,
      UTC_TIMESTAMP(6)
    FROM asset a
    JOIN tmp_asset_rows t ON a.asset_id = t.asset_id;

    /* stock */
    -- grouped stock update: fully qualify product_model_id
    UPDATE stock s
    JOIN (
      SELECT a.product_model_id AS product_model_id, COUNT(*) AS qty_change
      FROM asset a
      JOIN tmp_asset_rows t ON a.asset_id = t.asset_id
      GROUP BY a.product_model_id
    ) ch ON ch.product_model_id = s.product_model_id
    SET s.quantity_available = s.quantity_available - ch.qty_change,
        s.quantity_on_rent = s.quantity_on_rent + ch.qty_change,
        s.last_updated_by = p_user_id
    WHERE s.business_id = p_business_id AND (p_branch_id IS NULL OR s.branch_id = p_branch_id);

    /* stock_movements */
    -- grouped stock_movements (qualify product_model_id)
    INSERT INTO stock_movements (
      business_id, branch_id, product_model_id, inventory_movement_type_id,
      quantity, related_rental_id, from_product_status_id, to_product_status_id, created_by, created_at
    )
    SELECT
      p_business_id,
      p_branch_id,
      a.product_model_id,
      v_rental_out_movement,
      COUNT(*) AS qty,
      v_rental_id_local,
      v_available_status,
      v_rented_status,
      p_user_id,
      UTC_TIMESTAMP(6)
    FROM asset a
    JOIN tmp_asset_rows t ON a.asset_id = t.asset_id
    GROUP BY a.product_model_id;

    /* rental */
    -- compute subtotal
    UPDATE rental r
    SET subtotal_amount = (
      SELECT IFNULL(SUM(ri.rent_price),0) FROM rental_item ri WHERE ri.rental_id = v_rental_id_local
    ), updated_by = p_user_id
    WHERE r.rental_id = v_rental_id_local;

    COMMIT;

    SET p_success = TRUE;
    SET p_rental_id = v_rental_id_local;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Rental created and stock updated.';
END proc_exit;
