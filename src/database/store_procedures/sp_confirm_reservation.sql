DROP PROCEDURE IF EXISTS sp_confirm_reservation;
CREATE PROCEDURE sp_confirm_reservation(
  IN p_reservation_id INT,
  IN p_user_id VARCHAR(255),
  OUT p_rental_id INT,
  OUT p_success BOOLEAN,
  OUT p_error_code VARCHAR(50),
  OUT p_error_message VARCHAR(500)
)
BEGIN
  DECLARE v_reserved_status INT;
  DECLARE v_confirmed_status INT;
  DECLARE v_available_status INT;
  DECLARE v_rented_status INT;
  DECLARE v_rental_out_move INT;
  DECLARE done INT DEFAULT 0;

  SET p_rental_id = NULL; SET p_success = FALSE; SET p_error_code = NULL; SET p_error_message = NULL;

  SELECT reservation_status_id INTO v_reserved_status FROM reservation_status WHERE code = 'PENDING' LIMIT 1;
  SELECT reservation_status_id INTO v_confirmed_status FROM reservation_status WHERE code = 'CONFIRMED' LIMIT 1;
  SELECT product_status_id INTO v_available_status FROM product_status WHERE code = 'AVAILABLE' LIMIT 1;
  SELECT product_status_id INTO v_rented_status FROM product_status WHERE code = 'RENTED' LIMIT 1;
  SELECT inventory_movement_type_id INTO v_rental_out_move FROM inventory_movement_type WHERE code = 'RENTAL_OUT' LIMIT 1;

  IF v_reserved_status IS NULL OR v_confirmed_status IS NULL OR v_available_status IS NULL OR v_rented_status IS NULL OR v_rental_out_move IS NULL THEN
    SET p_error_code = 'ERR_CONFIG';
    SET p_error_message = 'Required lookup rows missing.';
    LEAVE sp_confirm_reservation;
  END IF;

  START TRANSACTION;

  -- lock reservation header
  SELECT * FROM reservations WHERE reservation_id = p_reservation_id FOR UPDATE;

  -- check it's PENDING
  IF (SELECT reservation_status_id FROM reservations WHERE reservation_id = p_reservation_id) <> v_reserved_status THEN
    ROLLBACK;
    SET p_error_code = 'ERR_RES_NOT_PENDING';
    SET p_error_message = 'Reservation not in PENDING state.';
    LEAVE sp_confirm_reservation;
  END IF;

  -- For each reservation_item, pick N available assets FOR UPDATE (deterministic order)
  DROP TEMPORARY TABLE IF EXISTS tmp_confirm_assets;
  CREATE TEMPORARY TABLE tmp_confirm_assets (asset_id INT PRIMARY KEY, product_model_id INT) ENGINE=MEMORY;

  INSERT INTO tmp_confirm_assets (asset_id, product_model_id)
  SELECT a.asset_id, ri.product_model_id
  FROM reservation_item ri
  JOIN asset a ON a.product_model_id = ri.product_model_id
     AND a.product_status_id = v_available_status
     AND a.is_deleted = 0
     AND a.business_id = (SELECT business_id FROM reservations WHERE reservation_id = p_reservation_id)
     AND a.branch_id = (SELECT branch_id FROM reservations WHERE reservation_id = p_reservation_id)
  WHERE ri.reservation_id = p_reservation_id
  ORDER BY a.asset_id ASC
  LIMIT 10000 -- safety cap; real system should loop per-item when large
  FOR UPDATE;

  -- Validate counts per model match requested quantities (simple approach)
  -- If insufficient, rollback
  -- (a robust version would loop per reservation_item and select LIMIT qty FOR UPDATE — simplified here)
  -- Count assets per model selected:
  IF EXISTS (
    SELECT 1 FROM (
      SELECT ri.product_model_id, ri.quantity AS required_qty,
             COALESCE(COUNT(a.asset_id),0) AS found_qty
      FROM reservation_item ri
      LEFT JOIN tmp_confirm_assets a ON a.product_model_id = ri.product_model_id
      WHERE ri.reservation_id = p_reservation_id
      GROUP BY ri.product_model_id, ri.quantity
      HAVING found_qty < required_qty
    ) tmp
  ) THEN
    ROLLBACK;
    SET p_error_code = 'ERR_ASSETS_INSUFFICIENT';
    SET p_error_message = 'Not enough available assets to fulfill reservation (race condition).';
    LEAVE sp_confirm_reservation;
  END IF;

  -- create rental
  INSERT INTO rental (business_id, branch_id, customer_id, user_id, invoice_date, start_date, due_date, subtotal_amount, billing_period_id, currency, notes, created_by, created_at)
  SELECT business_id, branch_id, customer_id, created_by, UTC_TIMESTAMP(6), MIN(started.start_date), MAX(started.end_date), 0.00, NULL, 'INR', '', p_user_id, UTC_TIMESTAMP(6)
  FROM reservations r
  LEFT JOIN (
    SELECT reservation_id, MIN(start_date) AS start_date, MAX(end_date) AS end_date FROM reservation_item WHERE reservation_id = p_reservation_id GROUP BY reservation_id
  ) started ON started.reservation_id = r.reservation_id
  WHERE r.reservation_id = p_reservation_id;

  SET p_rental_id = LAST_INSERT_ID();

  -- insert rental_items for selected assets
  INSERT INTO rental_item (rental_id, business_id, branch_id, product_segment_id, product_category_id, product_model_id, asset_id, product_rental_status_id, customer_id, rent_price, created_by, created_at)
  SELECT p_rental_id, a.business_id, a.branch_id, a.product_segment_id, a.product_category_id, a.product_model_id, a.asset_id, (SELECT product_rental_status_id FROM product_rental_status WHERE code='ACTIVE' LIMIT 1), (SELECT customer_id FROM reservations WHERE reservation_id = p_reservation_id), COALESCE(a.rent_price,0), p_user_id, UTC_TIMESTAMP(6)
  FROM tmp_confirm_assets t
  JOIN asset a ON a.asset_id = t.asset_id;

  -- update selected assets to RENTED
  UPDATE asset a
  JOIN tmp_confirm_assets t ON a.asset_id = t.asset_id
  SET a.product_status_id = v_rented_status, a.updated_by = p_user_id, a.updated_at = UTC_TIMESTAMP(6);

  -- insert asset_movements
  INSERT INTO asset_movements (business_id, branch_id, product_model_id, asset_id, inventory_movement_type_id, quantity, from_product_status_id, to_product_status_id, related_rental_id, created_by, created_at)
  SELECT a.business_id, a.branch_id, a.product_model_id, a.asset_id, v_rental_out_move, 1, v_available_status, v_rented_status, p_rental_id, p_user_id, UTC_TIMESTAMP(6)
  FROM tmp_confirm_assets t JOIN asset a ON a.asset_id = t.asset_id;

  -- adjust stock: reserved -> on_rent
  UPDATE stock s
  JOIN (
    SELECT product_model_id, COUNT(*) AS qty
    FROM tmp_confirm_assets
    GROUP BY product_model_id
  ) ch ON ch.product_model_id = s.product_model_id
  SET s.quantity_reserved = s.quantity_reserved - ch.qty,
      s.quantity_on_rent = s.quantity_on_rent + ch.qty,
      s.last_updated_by = p_user_id, s.last_updated_at = UTC_TIMESTAMP(6)
  WHERE s.business_id = (SELECT business_id FROM reservations WHERE reservation_id = p_reservation_id)
    AND (s.branch_id = (SELECT branch_id FROM reservations WHERE reservation_id = p_reservation_id));

  -- insert stock_movements for confirm
  INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, related_rental_id, created_by, created_at)
  SELECT (SELECT business_id FROM reservations WHERE reservation_id = p_reservation_id),
         (SELECT branch_id FROM reservations WHERE reservation_id = p_reservation_id),
         t.product_model_id, v_rental_out_move, COUNT(*), p_rental_id, p_user_id, UTC_TIMESTAMP(6)
  FROM tmp_confirm_assets t
  GROUP BY t.product_model_id;

  -- mark reservation confirmed
  UPDATE reservations SET reservation_status_id = v_confirmed_status, updated_by = p_user_id, updated_at = UTC_TIMESTAMP(6) WHERE reservation_id = p_reservation_id;

  COMMIT;

  SET p_success = TRUE;
  SET p_error_code = 'SUCCESS';
  SET p_error_message = NULL;
END;