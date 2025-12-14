-- CURRENTLY NOT IN USE
DROP PROCEDURE IF EXISTS sp_apply_stock_deltas;
CREATE PROCEDURE sp_apply_stock_deltas(
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_deltas_json JSON,     -- [{product_model_id:1, delta_available:-2, delta_reserved:2, delta_on_rent:0}, ...]
    IN  p_user_id VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_count INT DEFAULT 0;

    SET p_success = FALSE;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    DROP TEMPORARY TABLE IF EXISTS tmp_stock_deltas;
    CREATE TEMPORARY TABLE tmp_stock_deltas (
        product_model_id INT PRIMARY KEY,
        delta_available INT DEFAULT 0,
        delta_reserved INT DEFAULT 0,
        delta_on_rent INT DEFAULT 0
    ) ENGINE=MEMORY;

    INSERT INTO tmp_stock_deltas (product_model_id, delta_available, delta_reserved, delta_on_rent)
    SELECT
      CAST(JSON_EXTRACT(j.value, '$.product_model_id') AS UNSIGNED),
      CAST(IFNULL(JSON_EXTRACT(j.value, '$.delta_available'), 0) AS SIGNED),
      CAST(IFNULL(JSON_EXTRACT(j.value, '$.delta_reserved'), 0) AS SIGNED),
      CAST(IFNULL(JSON_EXTRACT(j.value, '$.delta_on_rent'), 0) AS SIGNED)
    FROM JSON_TABLE(p_deltas_json, '$[*]' COLUMNS (value JSON PATH '$')) AS j
    WHERE JSON_EXTRACT(j.value, '$.product_model_id') IS NOT NULL;

    SELECT COUNT(*) INTO v_count FROM tmp_stock_deltas;
    IF v_count = 0 THEN
      SET p_error_code = 'ERR_NO_DELTAS';
      SET p_error_message = 'No deltas parsed from JSON.';
      LEAVE sp_apply_stock_deltas;
    END IF;

    -- guarded update: prevent negative available. Caller should CALL this inside a transaction.
    UPDATE stock s
    JOIN tmp_stock_deltas d ON s.product_model_id = d.product_model_id
    SET
      s.quantity_available = s.quantity_available + d.delta_available,
      s.quantity_reserved  = s.quantity_reserved + d.delta_reserved,
      s.quantity_on_rent   = s.quantity_on_rent + d.delta_on_rent,
      s.last_updated_by    = p_user_id,
      s.last_updated_at    = UTC_TIMESTAMP(6)
    WHERE s.business_id = p_business_id
      AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
      AND (s.quantity_available + d.delta_available) >= 0;

    -- ensure all deltas applied
    IF (SELECT COUNT(*) FROM tmp_stock_deltas) <> ROW_COUNT() THEN
      SET p_error_code = 'ERR_STOCK_CONSTRAINT';
      SET p_error_message = 'One or more deltas would make available negative. No change applied by this call (caller should rollback).';
      SET p_success = FALSE;
      LEAVE sp_apply_stock_deltas;
    END IF;

    SET p_success = TRUE;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = NULL;
END;