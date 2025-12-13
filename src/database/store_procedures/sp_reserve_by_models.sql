DROP PROCEDURE IF EXISTS sp_reserve_by_models;
CREATE PROCEDURE sp_reserve_by_models(
  IN p_business_id INT,
  IN p_branch_id INT,
  IN p_requested_json JSON,
  IN p_customer_id INT,
  IN p_user_id VARCHAR(255),
  OUT p_reservation_id INT,
  OUT p_success BOOLEAN,
  OUT p_error_code VARCHAR(50),
  OUT p_error_message VARCHAR(500)
)
BEGIN
  DECLARE v_count INT DEFAULT 0;
  DECLARE v_locked_count INT DEFAULT 0;
  DECLARE v_status_pending INT;
  
  SET p_reservation_id = NULL;
  SET p_success = FALSE;
  SET p_error_code = NULL;
  SET p_error_message = NULL;

  -- Lookup reservation status
  SELECT reservation_status_id INTO v_status_pending 
  FROM reservation_status WHERE code = 'PENDING' LIMIT 1;

  IF v_status_pending IS NULL THEN
    SET p_error_code = 'ERR_CONFIG';
    SET p_error_message = 'PENDING status not found';
    LEAVE sp_reserve_by_models;
  END IF;

  -- Parse request
  DROP TEMPORARY TABLE IF EXISTS tmp_requested;
  CREATE TEMPORARY TABLE tmp_requested (
    product_model_id INT PRIMARY KEY,
    qty INT NOT NULL,
    start_date TIMESTAMP(6),
    end_date TIMESTAMP(6)
  ) ENGINE=MEMORY;

  INSERT INTO tmp_requested (product_model_id, qty, start_date, end_date)
  SELECT
    CAST(JSON_EXTRACT(j.value, '$.product_model_id') AS UNSIGNED),
    CAST(IFNULL(JSON_EXTRACT(j.value, '$.qty'), 0) AS SIGNED),
    CAST(JSON_UNQUOTE(JSON_EXTRACT(j.value, '$.start_date')) AS DATETIME),
    CAST(JSON_UNQUOTE(JSON_EXTRACT(j.value, '$.end_date')) AS DATETIME)
  FROM JSON_TABLE(p_requested_json, '$[*]' COLUMNS (value JSON PATH '$')) AS jt
  WHERE JSON_EXTRACT(j.value, '$.product_model_id') IS NOT NULL
    AND CAST(IFNULL(JSON_EXTRACT(j.value, '$.qty'), 0) AS SIGNED) > 0
  ORDER BY CAST(JSON_EXTRACT(j.value, '$.product_model_id') AS UNSIGNED) ASC; -- ✅ Deterministic order

  SELECT COUNT(*) INTO v_count FROM tmp_requested;
  IF v_count = 0 THEN
    SET p_error_code = 'ERR_INVALID_REQUEST';
    SET p_error_message = 'No valid model/qty found in request';
    LEAVE sp_reserve_by_models;
  END IF;

  START TRANSACTION;

  -- ✅ FIX: Lock stock rows FIRST in deterministic order
  SELECT COUNT(*) INTO v_locked_count
  FROM stock s
  JOIN tmp_requested r ON s.product_model_id = r.product_model_id
  WHERE s.business_id = p_business_id
    AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
    AND s.quantity_available >= r.qty -- ✅ Check availability while locked
  FOR UPDATE; -- ✅ Explicit row lock BEFORE update

  -- Validate all models have sufficient stock
  IF v_locked_count <> v_count THEN
    ROLLBACK;
    SET p_error_code = 'ERR_OUT_OF_STOCK';
    SET p_error_message = 'One or more models do not have enough available quantity.';
    LEAVE sp_reserve_by_models;
  END IF;

  -- Now safe to update (rows are locked)
  UPDATE stock s
  JOIN tmp_requested r ON s.product_model_id = r.product_model_id
  SET s.quantity_available = s.quantity_available - r.qty,
      s.quantity_reserved = s.quantity_reserved + r.qty,
      s.last_updated_at = UTC_TIMESTAMP(6),
      s.last_updated_by = p_user_id
  WHERE s.business_id = p_business_id
    AND (p_branch_id IS NULL OR s.branch_id = p_branch_id);

  -- Create reservation header
  INSERT INTO reservations (
    business_id, branch_id, customer_id, product_model_id, 
    reservation_status_id, reserved_from, reserved_until, 
    created_by, created_at
  )
  VALUES (
    p_business_id, p_branch_id, p_customer_id, NULL, 
    v_status_pending, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 
    p_user_id, UTC_TIMESTAMP(6)
  ); 
  
  SET p_reservation_id = LAST_INSERT_ID();

  -- Insert reservation items
  INSERT INTO reservation_item (
    reservation_id, product_model_id, quantity, 
    start_date, end_date, created_by, created_at
  )
  SELECT 
    p_reservation_id, product_model_id, qty, 
    start_date, end_date, p_user_id, UTC_TIMESTAMP(6) 
  FROM tmp_requested;

  -- ✅ ADD: Insert stock movements for audit trail
  INSERT INTO stock_movements (
    business_id, branch_id, product_model_id, 
    inventory_movement_type_id, quantity, 
    related_reservation_id, 
    from_product_status_id, to_product_status_id,
    created_by, created_at
  )
  SELECT 
    p_business_id, 
    COALESCE(p_branch_id, (SELECT branch_id FROM stock WHERE product_model_id = r.product_model_id LIMIT 1)),
    r.product_model_id,
    (SELECT inventory_movement_type_id FROM inventory_movement_type WHERE code = 'RESERVE' LIMIT 1),
    r.qty,
    p_reservation_id,
    (SELECT product_status_id FROM product_status WHERE code = 'AVAILABLE' LIMIT 1),
    (SELECT product_status_id FROM product_status WHERE code = 'RESERVED' LIMIT 1),
    p_user_id, 
    UTC_TIMESTAMP(6)
  FROM tmp_requested r;

  COMMIT;

  SET p_success = TRUE;
  SET p_error_code = 'SUCCESS';
  SET p_error_message = NULL;
END;