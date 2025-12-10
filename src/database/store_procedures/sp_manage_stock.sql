DROP PROCEDURE IF EXISTS sp_manage_stock;

CREATE PROCEDURE sp_manage_stock(
    IN p_action INT,                 -- 1:Create, 2:Update, 3:Delete, 4:Get(Single), 5:GetAll
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_product_segment_id INT,     -- Required for Create
    IN p_product_category_id INT,    -- Required for Create
    IN p_product_model_id INT,       -- Required for Create/Update/Delete/Get
    IN p_quantity INT,               -- Used as 'quantity_available' for Create/Update
    IN p_user_id INT,                -- For tracking/logging (optional implementation)
    IN p_role_id INT,                -- For tracking/logging (optional implementation)

    OUT p_success BOOLEAN,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    -- DECLARATIONS
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- =============================================
    /* Exception Handling */
    -- =============================================
    -- Specific Handler: Foreign Key Violation
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_error_message = 'Foreign key violation (likely missing reference).';
    END;

    -- Specific Handler: Duplicate Key
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_error_message = 'Duplicate key error (unique constraint).';
    END;

    -- Generic Handler: SQLEXCEPTION
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

        -- Log error details
        INSERT INTO proc_error_log(
            proc_name, 
            proc_args, 
            mysql_errno, 
            sql_state, 
            error_message
        )
        VALUES (
            'sp_action_login_with_otp',
            CONCAT('p_email=', LEFT(p_email, 200), ', p_ip=', IFNULL(p_ip_address, 'NULL')),
            v_errno,
            v_sql_state,
            LEFT(v_error_msg, 2000)
        );

        -- Safe return message
        SET p_error_message = CONCAT(
            'Error logged (errno=', IFNULL(CAST(v_errno AS CHAR), '?'),
            ', sqlstate=', IFNULL(v_sql_state, '?'), '). See proc_error_log.'
        );
    END;

    -- Reset Outputs
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
            quantity_lost
        ) VALUES (
            p_business_id,
            p_branch_id,
            p_product_segment_id,
            p_product_category_id,
            p_product_model_id,
            IFNULL(p_quantity, 0), -- Initial available quantity
            0, 0, 0, 0, 0
        );

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Stock created successfully.';
        LEAVE proc_body;
    END IF;

    -- ==========================================================
    /* 2: UPDATE */
    -- ==========================================================
    IF p_action = 2 THEN
        UPDATE stock
        SET quantity_available = IFNULL(p_quantity, quantity_available)
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND product_model_id = p_product_model_id;

        IF ROW_COUNT() = 0 THEN
            SET p_success = FALSE;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Stock record not found for update.';
        ELSE
            SET p_success = TRUE;
            SET p_error_code = 'SUCCESS';
            SET p_error_message = 'Stock updated successfully.';
        END IF;
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
            'stock_id', stock_id, -- Assuming PK exists, or composite key
            'business_id', business_id,
            'branch_id', branch_id,
            'product_model_id', product_model_id,
            'quantity_available', quantity_available,
            'quantity_on_rent', quantity_on_rent,
            'quantity_reserved', quantity_reserved
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
                'quantity_on_rent', quantity_on_rent
            )
        ) INTO p_data
        FROM stock
        WHERE business_id = p_business_id
          AND (p_branch_id IS NULL OR branch_id = p_branch_id);

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        LEAVE proc_body;
    END IF;

    -- Invalid Action
    SET p_success = FALSE;
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action provided for stock management.';

END;