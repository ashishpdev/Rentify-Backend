DROP PROCEDURE IF EXISTS sp_update_asset_status;
CREATE PROCEDURE sp_update_asset_status(
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_asset_id INT,
    IN  p_from_product_status_code VARCHAR(64), -- optional
    IN  p_to_product_status_code VARCHAR(64),   -- required
    IN  p_inventory_movement_code VARCHAR(64),  -- e.g. 'RENTAL_OUT'
    IN  p_reference_no VARCHAR(255),
    IN  p_note TEXT,
    IN  p_user_id INT,
    IN  p_standalone BOOLEAN,                   -- if TRUE, proc opens and commits its own tx
    OUT p_success BOOLEAN,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
BEGIN
    -- declarations (must appear before any other statements)
    DECLARE v_from_status_id INT DEFAULT NULL;
    DECLARE v_to_status_id INT DEFAULT NULL;
    DECLARE v_movement_type_id INT DEFAULT NULL;
    DECLARE v_asset_exists INT DEFAULT 0;
    DECLARE v_error INT DEFAULT 0;

    -- exception handler: rollback only if this proc started the transaction
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        IF p_standalone THEN
            ROLLBACK;
        END IF;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_EXCEPTION';
        SET p_error_message = 'Unexpected database error.';
    END;

    -- initialize outputs
    SET p_success = FALSE;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- lookups
    IF p_from_product_status_code IS NOT NULL THEN
      SELECT product_status_id INTO v_from_status_id
      FROM product_status
      WHERE code = p_from_product_status_code
      LIMIT 1;
    END IF;

    SELECT product_status_id INTO v_to_status_id
    FROM product_status
    WHERE code = p_to_product_status_code
    LIMIT 1;

    SELECT inventory_movement_type_id INTO v_movement_type_id
    FROM inventory_movement_type
    WHERE code = p_inventory_movement_code
    LIMIT 1;

    IF v_to_status_id IS NULL THEN
      SET p_error_code = 'ERR_STATUS_LOOKUP';
      SET p_error_message = 'to_product_status code not found.';
      SET v_error = 1;
    END IF;

    IF v_movement_type_id IS NULL THEN
      SET p_error_code = 'ERR_MOVEMENT_LOOKUP';
      SET p_error_message = 'movement type code not found.';
      SET v_error = 1;
    END IF;

    -- asset existence check
    IF v_error = 0 THEN
      SELECT COUNT(*) INTO v_asset_exists
      FROM asset
      WHERE asset_id = p_asset_id
        AND business_id = p_business_id
        AND branch_id = p_branch_id
        AND is_deleted = 0;

      IF v_asset_exists = 0 THEN
        SET p_error_code = 'ERR_ASSET_NOT_FOUND';
        SET p_error_message = 'Asset not found or deleted.';
        SET v_error = 1;
      END IF;
    END IF;

    -- start transaction only if requested and no pre-check error
    IF v_error = 0 AND p_standalone THEN
      START TRANSACTION;
    END IF;

    -- do the work only if no errors
    IF v_error = 0 THEN
      -- update asset (caller should lock asset if part of a larger transaction)
      UPDATE asset
      SET product_status_id = v_to_status_id,
          updated_by = p_user_id,
          updated_at = UTC_TIMESTAMP(6)
      WHERE asset_id = p_asset_id
        AND business_id = p_business_id
        AND branch_id = p_branch_id;

      -- insert asset movement audit
      INSERT INTO asset_movements (
          business_id, branch_id, product_model_id, asset_id,
          inventory_movement_type_id,
          from_product_status_id, to_product_status_id,
          related_rental_id, reference_no, note, metadata, created_by, created_at
      )
      SELECT
          a.business_id, a.branch_id, a.product_model_id, a.asset_id,
          v_movement_type_id,
          v_from_status_id, v_to_status_id,
          NULL, p_reference_no, p_note, JSON_OBJECT('updated_by', p_user_id), p_user_id, UTC_TIMESTAMP(6)
      FROM asset a
      WHERE a.asset_id = p_asset_id
        AND a.business_id = p_business_id
        AND a.branch_id = p_branch_id;

      -- commit only if this proc started the transaction
      IF p_standalone THEN
        COMMIT;
      END IF;

      SET p_success = TRUE;
      SET p_error_code = 'SUCCESS';
      SET p_error_message = NULL;
    ELSE
      -- ensure no transaction left open when pre-check aborted and we started a tx (defensive)
      IF p_standalone THEN
        -- if caller asked for standalone and we somehow started a tx, roll it back
        -- (we only start tx above when v_error=0, so this is usually no-op)
        ROLLBACK;
      END IF;
      -- p_success already FALSE and p_error_code/message set
    END IF;

END;
