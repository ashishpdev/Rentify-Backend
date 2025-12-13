DROP PROCEDURE IF EXISTS sp_manage_stock_admin;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE sp_manage_stock_admin(
    IN  p_action INT,                   -- 2 = SYNC/UPDATE, 4 = GET_SINGLE, 5 = GET_LIST
    IN  p_business_id INT,
    IN  p_branch_id INT,                -- optional: pass NULL to consider all branches for the business
    IN  p_product_segment_id INT,       -- optional: NULL means ignore
    IN  p_product_category_id INT,      -- optional: NULL means ignore
    IN  p_product_model_id INT,         -- optional: NULL -> apply to all models matching filters
    IN  p_stock_id INT,                 -- optional: for GET_SINGLE
    IN  p_user_id VARCHAR(255),         -- who triggered the call
    IN  p_role_id INT,                  -- kept for compatibility / audit
    OUT p_success BOOLEAN,
    OUT p_data JSON,                    -- JSON_ARRAY of updated stock rows (or single object)
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN
    -- Local vars
    DECLARE v_add_type INT;
    DECLARE v_remove_type INT;

    DECLARE v_status_available INT;
    DECLARE v_status_reserved INT;
    DECLARE v_status_rented INT;
    DECLARE v_status_maintenance INT;
    DECLARE v_status_damage INT;
    DECLARE v_status_lost INT;

    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT DEFAULT NULL;

    -- error handlers
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;
        IF v_cno > 0 THEN
            GET DIAGNOSTICS CONDITION 1
                v_errno     = MYSQL_ERRNO,
                v_sql_state = RETURNED_SQLSTATE,
                v_error_msg = MESSAGE_TEXT;
        ELSE
            SET v_errno = NULL;
            SET v_sql_state = NULL;
            SET v_error_msg = 'No diagnostics available';
        END IF;

        ROLLBACK;

        INSERT INTO proc_error_log(
            proc_name, proc_args, mysql_errno, sql_state, error_message
        ) VALUES (
            'sp_manage_stock_admin',
            JSON_OBJECT(
                'p_business_id', p_business_id,
                'p_branch_id', p_branch_id,
                'p_product_segment_id', p_product_segment_id,
                'p_product_category_id', p_product_category_id,
                'p_product_model_id', p_product_model_id,
                'p_user_id', p_user_id
            ),
            v_errno, v_sql_state, LEFT(v_error_msg,2000)
        );

        SET p_success = FALSE;
        SET p_data = NULL;
        SET p_error_code = 'ERR_EXCEPTION';
        SET p_error_message = CONCAT('Exception logged; errno=', IFNULL(CAST(v_errno AS CHAR), '?'));
    END;

    -- Initialize outputs
    SET p_success = FALSE;
    SET p_data = JSON_ARRAY();
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- Basic validation
    IF p_business_id IS NULL THEN
        SET p_error_code = 'ERR_MISSING_BUSINESS';
        SET p_error_message = 'p_business_id is required';
        LEAVE proc_body;
    END IF;

    -- load lookup ids
    SELECT inventory_movement_type_id INTO v_add_type FROM inventory_movement_type WHERE code = 'ADD' LIMIT 1;
    SELECT inventory_movement_type_id INTO v_remove_type FROM inventory_movement_type WHERE code = 'REMOVE' LIMIT 1;

    SELECT product_status_id INTO v_status_available FROM product_status WHERE code = 'AVAILABLE' LIMIT 1;
    SELECT product_status_id INTO v_status_reserved  FROM product_status WHERE code = 'RESERVED' LIMIT 1;
    SELECT product_status_id INTO v_status_rented    FROM product_status WHERE code = 'RENTED' LIMIT 1;
    SELECT product_status_id INTO v_status_maintenance FROM product_status WHERE code = 'MAINTENANCE' LIMIT 1;
    SELECT product_status_id INTO v_status_damage    FROM product_status WHERE code = 'DAMAGE' LIMIT 1;
    SELECT product_status_id INTO v_status_lost      FROM product_status WHERE code = 'LOST' LIMIT 1;

    -- ACTION: GET_SINGLE (4)
    IF p_action = 4 THEN
        -- if stock_id provided, prefer that, else fallback to product_model_id
        IF p_stock_id IS NOT NULL THEN
            SELECT JSON_OBJECT(
                'stock_id', stock_id,
                'business_id', business_id,
                'branch_id', branch_id,
                'product_model_id', product_model_id,
                'quantity_available', quantity_available,
                'quantity_reserved', quantity_reserved,
                'quantity_on_rent', quantity_on_rent,
                'quantity_in_maintenance', quantity_in_maintenance,
                'quantity_damaged', quantity_damaged,
                'quantity_lost', quantity_lost,
                'quantity_total', quantity_total,
                'is_product_model_rentable', is_product_model_rentable,
                'last_updated_at', last_updated_at,
                'last_updated_by', last_updated_by
            ) INTO p_data
            FROM stock
            WHERE stock_id = p_stock_id
            LIMIT 1;

            IF p_data IS NULL THEN
                SET p_error_code = 'ERR_NOT_FOUND';
                SET p_error_message = 'stock_id not found';
                SET p_success = FALSE;
            ELSE
                SET p_success = TRUE;
                SET p_error_code = 'SUCCESS';
                SET p_error_message = 'OK';
            END IF;

            LEAVE proc_body;
        END IF;

        IF p_product_model_id IS NOT NULL THEN
            SELECT JSON_OBJECT(
                'stock_id', stock_id,
                'business_id', business_id,
                'branch_id', branch_id,
                'product_model_id', product_model_id,
                'quantity_available', quantity_available,
                'quantity_reserved', quantity_reserved,
                'quantity_on_rent', quantity_on_rent,
                'quantity_in_maintenance', quantity_in_maintenance,
                'quantity_damaged', quantity_damaged,
                'quantity_lost', quantity_lost,
                'quantity_total', quantity_total,
                'is_product_model_rentable', is_product_model_rentable,
                'last_updated_at', last_updated_at,
                'last_updated_by', last_updated_by
            ) INTO p_data
            FROM stock
            WHERE business_id = p_business_id
              AND (p_branch_id IS NULL OR branch_id = p_branch_id)
              AND product_model_id = p_product_model_id
            LIMIT 1;

            IF p_data IS NULL THEN
                SET p_error_code = 'ERR_NOT_FOUND';
                SET p_error_message = 'stock row not found for provided model/filters';
                SET p_success = FALSE;
            ELSE
                SET p_success = TRUE;
                SET p_error_code = 'SUCCESS';
                SET p_error_message = 'OK';
            END IF;

            LEAVE proc_body;
        END IF;

        SET p_error_code = 'ERR_PARAMS';
        SET p_error_message = 'Provide p_stock_id or p_product_model_id for GET_SINGLE';
        LEAVE proc_body;
    END IF;

    -- ACTION: GET_LIST (5)
    IF p_action = 5 THEN
        SELECT IFNULL(JSON_ARRAYAGG(JSON_OBJECT(
            'stock_id', stock_id,
            'business_id', business_id,
            'branch_id', branch_id,
            'product_model_id', product_model_id,
            'quantity_available', quantity_available,
            'quantity_reserved', quantity_reserved,
            'quantity_on_rent', quantity_on_rent,
            'quantity_in_maintenance', quantity_in_maintenance,
            'quantity_damaged', quantity_damaged,
            'quantity_lost', quantity_lost,
            'quantity_total', quantity_total,
            'is_product_model_rentable', is_product_model_rentable,
            'last_updated_at', last_updated_at,
            'last_updated_by', last_updated_by
        )), JSON_ARRAY()) INTO p_data
        FROM stock
        WHERE business_id = p_business_id
          AND (p_branch_id IS NULL OR branch_id = p_branch_id)
          AND (p_product_segment_id IS NULL OR product_segment_id = p_product_segment_id)
          AND (p_product_category_id IS NULL OR product_category_id = p_product_category_id)
          AND (p_product_model_id IS NULL OR product_model_id = p_product_model_id);

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'OK';
        LEAVE proc_body;
    END IF;

    -- ACTION: SYNC/UPDATE (2)
    IF p_action = 2 THEN
        START TRANSACTION;

        -- Build tmp_new_stock: aggregated counts per product_model from asset
        DROP TEMPORARY TABLE IF EXISTS tmp_new_stock;
        CREATE TEMPORARY TABLE tmp_new_stock AS
        SELECT
            product_model_id,
            SUM(CASE WHEN product_status_id = v_status_available THEN 1 ELSE 0 END) AS qty_available,
            SUM(CASE WHEN product_status_id = v_status_reserved  THEN 1 ELSE 0 END) AS qty_reserved,
            SUM(CASE WHEN product_status_id = v_status_rented    THEN 1 ELSE 0 END) AS qty_on_rent,
            SUM(CASE WHEN product_status_id = v_status_maintenance THEN 1 ELSE 0 END) AS qty_in_maintenance,
            SUM(CASE WHEN product_status_id = v_status_damage    THEN 1 ELSE 0 END) AS qty_damaged,
            SUM(CASE WHEN product_status_id = v_status_lost      THEN 1 ELSE 0 END) AS qty_lost
        FROM asset
        WHERE business_id = p_business_id
          AND (p_branch_id IS NULL OR branch_id = p_branch_id)
          AND (p_product_segment_id IS NULL OR product_segment_id = p_product_segment_id)
          AND (p_product_category_id IS NULL OR product_category_id = p_product_category_id)
          AND (p_product_model_id IS NULL OR product_model_id = p_product_model_id)
          AND is_deleted = 0
        GROUP BY product_model_id;

        -- If tmp_new_stock is empty then nothing to do: return empty array
        IF (SELECT COUNT(*) FROM tmp_new_stock) = 0 THEN
            -- ensure there is at least an empty result
            SET p_data = JSON_ARRAY();
            COMMIT;
            SET p_success = TRUE;
            SET p_error_code = 'SUCCESS';
            SET p_error_message = 'No matching models to sync.';
            LEAVE proc_body;
        END IF;

        -- Build a temporary table with existing stock rows for the models (LOCK rows FOR UPDATE)
        DROP TEMPORARY TABLE IF EXISTS tmp_old_stock;
        CREATE TEMPORARY TABLE tmp_old_stock AS
        SELECT s.stock_id, s.product_model_id, s.quantity_available, s.quantity_reserved, s.quantity_on_rent,
               s.quantity_in_maintenance, s.quantity_damaged, s.quantity_lost, s.branch_id
        FROM stock s
        JOIN (SELECT DISTINCT product_model_id FROM tmp_new_stock) m ON m.product_model_id = s.product_model_id
        WHERE s.business_id = p_business_id
          AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
        FOR UPDATE;

        -- Upsert new rows: insert any models that don't exist in stock
        INSERT INTO stock (
            business_id, branch_id, product_segment_id, product_category_id, product_model_id,
            quantity_available, quantity_reserved, quantity_on_rent,
            quantity_in_maintenance, quantity_damaged, quantity_lost,
            created_by
        )
        SELECT
            p_business_id,
            COALESCE(p_branch_id, 0),
            COALESCE(p_product_segment_id, 0),
            COALESCE(p_product_category_id, 0),
            n.product_model_id,
            n.qty_available, n.qty_reserved, n.qty_on_rent,
            n.qty_in_maintenance, n.qty_damaged, n.qty_lost,
            p_user_id
        FROM tmp_new_stock n
        LEFT JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE o.stock_id IS NULL;

        -- Update existing rows with new counts
        UPDATE stock s
        JOIN tmp_new_stock n ON n.product_model_id = s.product_model_id
        SET
            s.quantity_available = n.qty_available,
            s.quantity_reserved  = n.qty_reserved,
            s.quantity_on_rent   = n.qty_on_rent,
            s.quantity_in_maintenance = n.qty_in_maintenance,
            s.quantity_damaged = n.qty_damaged,
            s.quantity_lost = n.qty_lost,
            s.last_updated_by = p_user_id,
            s.last_updated_at = UTC_TIMESTAMP(6)
        WHERE s.business_id = p_business_id
          AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
          AND (p_product_model_id IS NULL OR s.product_model_id = p_product_model_id);

        -- Insert stock_movements for deltas by comparing tmp_old_stock and tmp_new_stock
        -- For models newly inserted (no old row) we already inserted stock row — record ADD movements for non-zero fields.
        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id, v_add_type, n.qty_available, p_user_id
        FROM tmp_new_stock n
        LEFT JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE o.product_model_id IS NULL AND n.qty_available > 0 AND v_add_type IS NOT NULL;

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id, v_add_type, n.qty_on_rent, p_user_id
        FROM tmp_new_stock n
        LEFT JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE o.product_model_id IS NULL AND n.qty_on_rent > 0 AND v_add_type IS NOT NULL;

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id, v_add_type, n.qty_reserved, p_user_id
        FROM tmp_new_stock n
        LEFT JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE o.product_model_id IS NULL AND n.qty_reserved > 0 AND v_add_type IS NOT NULL;

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id, v_add_type, n.qty_in_maintenance, p_user_id
        FROM tmp_new_stock n
        LEFT JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE o.product_model_id IS NULL AND n.qty_in_maintenance > 0 AND v_add_type IS NOT NULL;

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id, v_add_type, n.qty_damaged, p_user_id
        FROM tmp_new_stock n
        LEFT JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE o.product_model_id IS NULL AND n.qty_damaged > 0 AND v_add_type IS NOT NULL;

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id, v_add_type, n.qty_lost, p_user_id
        FROM tmp_new_stock n
        LEFT JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE o.product_model_id IS NULL AND n.qty_lost > 0 AND v_add_type IS NOT NULL;

        -- For existing rows: insert movements where delta != 0
        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id,
               CASE WHEN n.qty_available > o.quantity_available THEN v_add_type ELSE v_remove_type END,
               ABS(n.qty_available - o.quantity_available),
               p_user_id
        FROM tmp_new_stock n
        JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE n.qty_available <> o.quantity_available
          AND ((n.qty_available > o.quantity_available AND v_add_type IS NOT NULL) OR (n.qty_available < o.quantity_available AND v_remove_type IS NOT NULL));

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id,
               CASE WHEN n.qty_on_rent > o.quantity_on_rent THEN v_add_type ELSE v_remove_type END,
               ABS(n.qty_on_rent - o.quantity_on_rent),
               p_user_id
        FROM tmp_new_stock n
        JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE n.qty_on_rent <> o.quantity_on_rent
          AND ((n.qty_on_rent > o.quantity_on_rent AND v_add_type IS NOT NULL) OR (n.qty_on_rent < o.quantity_on_rent AND v_remove_type IS NOT NULL));

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id,
               CASE WHEN n.qty_reserved > o.quantity_reserved THEN v_add_type ELSE v_remove_type END,
               ABS(n.qty_reserved - o.quantity_reserved),
               p_user_id
        FROM tmp_new_stock n
        JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE n.qty_reserved <> o.quantity_reserved
          AND ((n.qty_reserved > o.quantity_reserved AND v_add_type IS NOT NULL) OR (n.qty_reserved < o.quantity_reserved AND v_remove_type IS NOT NULL));

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id,
               CASE WHEN n.qty_in_maintenance > o.quantity_in_maintenance THEN v_add_type ELSE v_remove_type END,
               ABS(n.qty_in_maintenance - o.quantity_in_maintenance),
               p_user_id
        FROM tmp_new_stock n
        JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE n.qty_in_maintenance <> o.quantity_in_maintenance
          AND ((n.qty_in_maintenance > o.quantity_in_maintenance AND v_add_type IS NOT NULL) OR (n.qty_in_maintenance < o.quantity_in_maintenance AND v_remove_type IS NOT NULL));

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id,
               CASE WHEN n.qty_damaged > o.quantity_damaged THEN v_add_type ELSE v_remove_type END,
               ABS(n.qty_damaged - o.quantity_damaged),
               p_user_id
        FROM tmp_new_stock n
        JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE n.qty_damaged <> o.quantity_damaged
          AND ((n.qty_damaged > o.quantity_damaged AND v_add_type IS NOT NULL) OR (n.qty_damaged < o.quantity_damaged AND v_remove_type IS NOT NULL));

        INSERT INTO stock_movements (business_id, branch_id, product_model_id, inventory_movement_type_id, quantity, created_by)
        SELECT p_business_id, COALESCE(p_branch_id,0), n.product_model_id,
               CASE WHEN n.qty_lost > o.quantity_lost THEN v_add_type ELSE v_remove_type END,
               ABS(n.qty_lost - o.quantity_lost),
               p_user_id
        FROM tmp_new_stock n
        JOIN tmp_old_stock o ON o.product_model_id = n.product_model_id
        WHERE n.qty_lost <> o.quantity_lost
          AND ((n.qty_lost > o.quantity_lost AND v_add_type IS NOT NULL) OR (n.qty_lost < o.quantity_lost AND v_remove_type IS NOT NULL));

        -- Return updated stock rows for the affected models as JSON array
        SELECT IFNULL(JSON_ARRAYAGG(JSON_OBJECT(
            'stock_id', s.stock_id,
            'business_id', s.business_id,
            'branch_id', s.branch_id,
            'product_model_id', s.product_model_id,
            'quantity_available', s.quantity_available,
            'quantity_reserved', s.quantity_reserved,
            'quantity_on_rent', s.quantity_on_rent,
            'quantity_in_maintenance', s.quantity_in_maintenance,
            'quantity_damaged', s.quantity_damaged,
            'quantity_lost', s.quantity_lost,
            'quantity_total', s.quantity_total,
            'is_product_model_rentable', s.is_product_model_rentable,
            'last_updated_at', s.last_updated_at,
            'last_updated_by', s.last_updated_by
        )), JSON_ARRAY()) INTO p_data
        FROM stock s
        JOIN (SELECT DISTINCT product_model_id FROM tmp_new_stock) m ON m.product_model_id = s.product_model_id
        WHERE s.business_id = p_business_id
          AND (p_branch_id IS NULL OR s.branch_id = p_branch_id);

        COMMIT;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Stock synced from asset table.';
        LEAVE proc_body;
    END IF;

    -- Unknown action
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'p_action must be 2 (SYNC), 4 (GET_SINGLE) or 5 (GET_LIST).';
    SET p_success = FALSE;
END;  