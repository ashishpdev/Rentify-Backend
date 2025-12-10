DROP PROCEDURE IF EXISTS sp_manage_stock;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_stock`(
    IN p_action INT,                        -- 1: CREATE, 2: UPDATE, 3: DELETE, 4: GET SINGLE, 5: GET ALL
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_product_segment_id INT,
    IN p_product_category_id INT,
    IN p_product_model_id INT,
    IN p_quantity INT,                      -- quantity to add/subtract/set
    IN p_movement_type_id INT,              -- required for p_action = 2 (stock_movements type id)
    IN p_user_id INT,
    IN p_role_id INT,

    OUT p_success BOOLEAN,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN
    -- DECLARE LOCAL VARIABLES
    DECLARE v_stock_id INT DEFAULT NULL;
    DECLARE v_qty_avail INT DEFAULT 0;
    DECLARE v_qty_reserved INT DEFAULT 0;
    DECLARE v_qty_on_rent INT DEFAULT 0;
    DECLARE v_qty_in_maintenance INT DEFAULT 0;
    DECLARE v_qty_damaged INT DEFAULT 0;
    DECLARE v_qty_lost INT DEFAULT 0;

    DECLARE v_new_avail INT DEFAULT 0;
    DECLARE v_new_reserved INT DEFAULT 0;
    DECLARE v_new_on_rent INT DEFAULT 0;
    DECLARE v_new_in_maintenance INT DEFAULT 0;
    DECLARE v_new_damaged INT DEFAULT 0;
    DECLARE v_new_lost INT DEFAULT 0;

    DECLARE v_from_status INT DEFAULT NULL;
    DECLARE v_to_status INT DEFAULT NULL;

    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- ==============================
    -- Exception Handlers (preserve original behavior)
    -- ==============================
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_FOREIGN_KEY';
        SET p_error_message = 'Foreign key violation (likely missing reference).';
    END;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_DUPLICATE';
        SET p_error_message = 'Duplicate key error (unique constraint).';
    END;

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
            proc_name,
            proc_args,
            mysql_errno,
            sql_state,
            error_message
        ) VALUES (
            'sp_manage_stock',
            CONCAT(
                'p_action=', p_action,
                ', p_business_id=', COALESCE(CAST(p_business_id AS CHAR), 'NULL'),
                ', p_branch_id=', COALESCE(CAST(p_branch_id AS CHAR), 'NULL'),
                ', p_product_model_id=', COALESCE(CAST(p_product_model_id AS CHAR), 'NULL'),
                ', p_movement_type_id=', COALESCE(CAST(p_movement_type_id AS CHAR), 'NULL'),
                ', p_quantity=', COALESCE(CAST(p_quantity AS CHAR), 'NULL')
            ),
            v_errno,
            v_sql_state,
            LEFT(v_error_msg, 2000)
        );

        SET p_success = FALSE;
        SET p_error_code = 'ERR_EXCEPTION';
        SET p_error_message = CONCAT(
            'Error logged (errno=', IFNULL(CAST(v_errno AS CHAR), '?'),
            ', sqlstate=', IFNULL(v_sql_state, '?'), '). See proc_error_log.'
        );
    END;

    -- RESET OUTPUTS
    SET p_success = FALSE;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- ==========================================================
    /* 1: CREATE */
    -- ==========================================================
    IF p_action = 1 THEN
        INSERT INTO stock (
            business_id,
            branch_id,
            product_segment_id,
            product_category_id,
            product_model_id,
            quantity_available,
            quantity_reserved,
            quantity_on_rent,
            quantity_in_maintenance,
            quantity_damaged,
            quantity_lost,
            created_by
        ) VALUES (
            p_business_id,
            p_branch_id,
            p_product_segment_id,
            p_product_category_id,
            p_product_model_id,
            IFNULL(p_quantity, 0),
            0, 0, 0, 0, 0,
            p_user_id
        );

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Stock created successfully.';
        LEAVE proc_body;
    END IF;

    -- ==========================================================
    /* 3: DELETE */
    -- ==========================================================
    IF p_action = 3 THEN
        DELETE FROM stock
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND product_model_id = p_product_model_id;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Stock deleted successfully.';
        LEAVE proc_body;
    END IF;

    -- ==========================================================
    /* 4: GET SINGLE */
    -- ==========================================================
    IF p_action = 4 THEN
        SELECT JSON_OBJECT(
            'stock_id', stock_id,
            'product_model_id', product_model_id,
            'quantity_available', quantity_available,
            'quantity_reserved', quantity_reserved,
            'quantity_on_rent', quantity_on_rent,
            'quantity_in_maintenance', quantity_in_maintenance,
            'quantity_damaged', quantity_damaged,
            'quantity_lost', quantity_lost,
            'quantity_total', quantity_total,
            'last_updated_at', last_updated_at,
            'last_updated_by', last_updated_by
        ) INTO p_data
        FROM stock
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND product_model_id = p_product_model_id
        LIMIT 1;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        LEAVE proc_body;
    END IF;

    -- ==========================================================
    /* 5: GET ALL */
    -- ==========================================================
    IF p_action = 5 THEN
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'product_model_id', product_model_id,
                'quantity_available', quantity_available,
                'quantity_reserved', quantity_reserved,
                'quantity_on_rent', quantity_on_rent,
                'quantity_in_maintenance', quantity_in_maintenance,
                'quantity_damaged', quantity_damaged,
                'quantity_lost', quantity_lost,
                'quantity_total', quantity_total,
                'last_updated_at', last_updated_at,
                'last_updated_by', last_updated_by
            )
        ) INTO p_data
        FROM stock
        WHERE business_id = p_business_id
          AND (p_branch_id IS NULL OR branch_id = p_branch_id);

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        LEAVE proc_body;
    END IF;

    -- ==========================================================
    /* 2: UPDATE */
    -- ==========================================================
    IF p_action = 2 THEN
        -- Validate required params for update
        IF p_movement_type_id IS NULL THEN
            SET p_success = FALSE;
            SET p_error_code = 'ERR_MISSING_MOVEMENT_TYPE';
            SET p_error_message = 'p_movement_type_id is required for updates (p_action=2).';
            LEAVE proc_body;
        END IF;

        IF p_quantity IS NULL OR p_quantity <= 0 THEN
            SET p_success = FALSE;
            SET p_error_code = 'ERR_INVALID_QTY';
            SET p_error_message = 'p_quantity must be provided and > 0.';
            LEAVE proc_body;
        END IF;

        -- Lock the row to avoid race conditions
        SELECT
            stock_id,
            quantity_available,
            quantity_reserved,
            quantity_on_rent,
            quantity_in_maintenance,
            quantity_damaged,
            quantity_lost
        INTO
            v_stock_id,
            v_qty_avail,
            v_qty_reserved,
            v_qty_on_rent,
            v_qty_in_maintenance,
            v_qty_damaged,
            v_qty_lost
        FROM stock
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND product_model_id = p_product_model_id
        FOR UPDATE;

        IF v_stock_id IS NULL THEN
            SET p_success = FALSE;
            SET p_error_code = 'ERR_STOCK_NOT_FOUND';
            SET p_error_message = 'No stock row found for given business/branch/product_model.';
            LEAVE proc_body;
        END IF;

        -- Default from/to product status mapping for standard movement types:
        CASE p_movement_type_id
            WHEN 1 THEN -- ADD_STOCK
                SET v_from_status = 1, v_to_status = 2; -- PROCUREMENT -> AVAILABLE
            WHEN 2 THEN -- REMOVE_STOCK
                SET v_from_status = 2, v_to_status = 8; -- AVAILABLE -> RETIRED
            WHEN 3 THEN -- RENTAL_OUT
                SET v_from_status = 2, v_to_status = 4; -- AVAILABLE -> RENTED
            WHEN 4 THEN -- RENTAL_RETURN
                SET v_from_status = 4, v_to_status = 2; -- RENTED -> AVAILABLE
            WHEN 5 THEN -- RESERVE_ITEMS
                SET v_from_status = 2, v_to_status = 3; -- AVAILABLE -> RESERVED
            WHEN 6 THEN -- UNRESERVE_ITEMS
                SET v_from_status = 3, v_to_status = 2; -- RESERVED -> AVAILABLE
            WHEN 7 THEN -- MAINTENANCE_IN
                SET v_from_status = 2, v_to_status = 5; -- AVAILABLE -> MAINTENANCE
            WHEN 8 THEN -- MAINTENANCE_OUT
                SET v_from_status = 5, v_to_status = 2; -- MAINTENANCE -> AVAILABLE
            WHEN 9 THEN -- MARK_DAMAGED
                SET v_from_status = 2, v_to_status = 6; -- AVAILABLE -> DAMAGE
            WHEN 10 THEN -- LOST
                SET v_from_status = 4, v_to_status = 7; -- RENTED -> LOST (default)
            WHEN 11 THEN -- RETIRE_ITEM
                SET v_from_status = 2, v_to_status = 8; -- AVAILABLE -> RETIRED
            ELSE
                SET v_from_status = NULL, v_to_status = NULL;
        END CASE;

        -- Initialize new values with current ones
        SET v_new_avail = v_qty_avail;
        SET v_new_reserved = v_qty_reserved;
        SET v_new_on_rent = v_qty_on_rent;
        SET v_new_in_maintenance = v_qty_in_maintenance;
        SET v_new_damaged = v_qty_damaged;
        SET v_new_lost = v_qty_lost;

        -- Apply movement logic (safe checks included)
        CASE p_movement_type_id
            WHEN 1 THEN -- ADD_STOCK: available += qty
                SET v_new_avail = v_new_avail + p_quantity;

            WHEN 2 THEN -- REMOVE_STOCK: available -= qty
                IF v_new_avail < p_quantity THEN
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_AVAILABLE';
                    SET p_error_message = 'Not enough available stock to remove.';
                    LEAVE proc_body;
                END IF;
                SET v_new_avail = v_new_avail - p_quantity;

            WHEN 3 THEN -- RENTAL_OUT: available -= qty; on_rent += qty
                IF v_new_avail < p_quantity THEN
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_AVAILABLE';
                    SET p_error_message = 'Not enough available stock to issue for rental.';
                    LEAVE proc_body;
                END IF;
                SET v_new_avail = v_new_avail - p_quantity;
                SET v_new_on_rent = v_new_on_rent + p_quantity;

            WHEN 4 THEN -- RENTAL_RETURN: on_rent -= qty; available += qty
                IF v_new_on_rent < p_quantity THEN
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_ON_RENT';
                    SET p_error_message = 'Not enough items marked as on_rent to return.';
                    LEAVE proc_body;
                END IF;
                SET v_new_on_rent = v_new_on_rent - p_quantity;
                SET v_new_avail = v_new_avail + p_quantity;

            WHEN 5 THEN -- RESERVE_ITEMS: available -= qty; reserved += qty
                IF v_new_avail < p_quantity THEN
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_AVAILABLE';
                    SET p_error_message = 'Not enough available stock to reserve.';
                    LEAVE proc_body;
                END IF;
                SET v_new_avail = v_new_avail - p_quantity;
                SET v_new_reserved = v_new_reserved + p_quantity;

            WHEN 6 THEN -- UNRESERVE_ITEMS: reserved -= qty; available += qty
                IF v_new_reserved < p_quantity THEN
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_RESERVED';
                    SET p_error_message = 'Not enough reserved items to unreserve.';
                    LEAVE proc_body;
                END IF;
                SET v_new_reserved = v_new_reserved - p_quantity;
                SET v_new_avail = v_new_avail + p_quantity;

            WHEN 7 THEN -- MAINTENANCE_IN: available -= qty; in_maintenance += qty
                IF v_new_avail < p_quantity THEN
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_AVAILABLE';
                    SET p_error_message = 'Not enough available stock to send to maintenance.';
                    LEAVE proc_body;
                END IF;
                SET v_new_avail = v_new_avail - p_quantity;
                SET v_new_in_maintenance = v_new_in_maintenance + p_quantity;

            WHEN 8 THEN -- MAINTENANCE_OUT: in_maintenance -= qty; available += qty
                IF v_new_in_maintenance < p_quantity THEN
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_MAINT';
                    SET p_error_message = 'Not enough items in maintenance to move out.';
                    LEAVE proc_body;
                END IF;
                SET v_new_in_maintenance = v_new_in_maintenance - p_quantity;
                SET v_new_avail = v_new_avail + p_quantity;

            WHEN 9 THEN -- MARK_DAMAGED: available -= qty; damaged += qty
                IF v_new_avail < p_quantity THEN
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_AVAILABLE';
                    SET p_error_message = 'Not enough available items to mark damaged.';
                    LEAVE proc_body;
                END IF;
                SET v_new_avail = v_new_avail - p_quantity;
                SET v_new_damaged = v_new_damaged + p_quantity;

            WHEN 10 THEN -- LOST: typically from on_rent or available -> lost
                -- prefer to deduct from on_rent first, else available
                IF v_new_on_rent >= p_quantity THEN
                    SET v_new_on_rent = v_new_on_rent - p_quantity;
                ELSEIF v_new_avail >= p_quantity THEN
                    SET v_new_avail = v_new_avail - p_quantity;
                ELSE
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_STOCK_FOR_LOST';
                    SET p_error_message = 'Not enough stock (on_rent or available) to mark lost.';
                    LEAVE proc_body;
                END IF;
                SET v_new_lost = v_new_lost + p_quantity;

            WHEN 11 THEN -- RETIRE_ITEM: remove from available (or damaged) and mark retired (we treat as retired -> moved out)
                IF v_new_avail >= p_quantity THEN
                    SET v_new_avail = v_new_avail - p_quantity;
                ELSEIF v_new_damaged >= p_quantity THEN
                    SET v_new_damaged = v_new_damaged - p_quantity;
                ELSE
                    SET p_success = FALSE;
                    SET p_error_code = 'ERR_INSUFFICIENT_STOCK_TO_RETIRE';
                    SET p_error_message = 'Not enough stock to retire.';
                    LEAVE proc_body;
                END IF;
                -- retired items are not tracked as a separate column in stock table; movement recorded below

            ELSE
                SET p_success = FALSE;
                SET p_error_code = 'ERR_UNKNOWN_MOVEMENT';
                SET p_error_message = 'Unknown stock movement type.';
                LEAVE proc_body;
        END CASE;

        -- Final safety checks (no negative quantities)
        IF v_new_avail < 0 OR v_new_reserved < 0 OR v_new_on_rent < 0 OR v_new_in_maintenance < 0 OR v_new_damaged < 0 OR v_new_lost < 0 THEN
            SET p_success = FALSE;
            SET p_error_code = 'ERR_NEGATIVE_QTY';
            SET p_error_message = 'Operation would produce negative inventory counts.';
            LEAVE proc_body;
        END IF;

        -- Perform update
        UPDATE stock
        SET
            quantity_available = v_new_avail,
            quantity_reserved = v_new_reserved,
            quantity_on_rent = v_new_on_rent,
            quantity_in_maintenance = v_new_in_maintenance,
            quantity_damaged = v_new_damaged,
            quantity_lost = v_new_lost,
            last_updated_by = p_user_id
        WHERE stock_id = v_stock_id;

        -- Insert stock_movements record
        INSERT INTO stock_movements (
            business_id,
            branch_id,
            product_model_id,
            stock_movements_type_id,
            quantity,
            from_product_status_id,
            to_product_status_id,
            created_by
        ) VALUES (
            p_business_id,
            p_branch_id,
            p_product_model_id,
            p_movement_type_id,
            p_quantity,
            v_from_status,
            v_to_status,
            p_user_id
        );

        -- Return updated stock row as JSON
        SELECT JSON_OBJECT(
            'stock_id', stock_id,
            'product_model_id', product_model_id,
            'quantity_available', quantity_available,
            'quantity_reserved', quantity_reserved,
            'quantity_on_rent', quantity_on_rent,
            'quantity_in_maintenance', quantity_in_maintenance,
            'quantity_damaged', quantity_damaged,
            'quantity_lost', quantity_lost,
            'quantity_total', quantity_total,
            'last_updated_at', last_updated_at,
            'last_updated_by', last_updated_by
        ) INTO p_data
        FROM stock
        WHERE stock_id = v_stock_id
        LIMIT 1;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Stock updated and movement recorded successfully.';
        LEAVE proc_body;
    END IF;

    -- ==========================================================
    -- Invalid Action
    -- ==========================================================
    SET p_success = FALSE;
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action provided for stock management.';

END;