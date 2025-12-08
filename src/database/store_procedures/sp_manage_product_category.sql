DROP PROCEDURE IF EXISTS sp_manage_product_category;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_product_category`(
    IN  p_action INT,                       -- 1=Create, 2=Update, 3=Delete, 4=GetSingle, 5=GetAll
    IN  p_product_category_id INT,
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_product_segment_id INT,
    IN  p_code VARCHAR(128),
    IN  p_name VARCHAR(255),
    IN  p_description TEXT,
    IN  p_user VARCHAR(255),

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    /* ================================================================
       DECLARATIONS
       ================================================================ */
    DECLARE v_exist INT DEFAULT 0;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    /* ================================================================
       SPECIFIC ERROR HANDLER FOR FOREIGN KEY VIOLATIONS (Error 1452)
       ================================================================ */
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_INVALID_REFERENCE';
        SET p_error_message = 'Operation failed: Invalid Segment, Category or Model name provided.';
    END;

    /* ================================================================
       ERROR HANDLER
       ================================================================ */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;
            GET DIAGNOSTICS CONDITION v_cno
            v_errno = MYSQL_ERRNO,
            v_sql_state = RETURNED_SQLSTATE,
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        
        SET p_success = FALSE;
        IF p_error_code IS NULL THEN
            SET p_error_code = 'ERR_SQL_EXCEPTION';
            SET p_error_message = 'Unexpected database error occurred.';
        END IF;
    END;

    /* ================================================================
       RESET OUTPUT PARAMETERS
       ================================================================ */
    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;



    /* ================================================================
       ACTION 1: CREATE CATEGORY
       ================================================================ */
    IF p_action = 1 THEN

        -- Check for duplicate code
        SELECT COUNT(*) INTO v_exist FROM product_category
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND product_segment_id = p_product_segment_id
          AND code = p_code
          AND is_deleted = 0;

        IF v_exist > 0 THEN
            SET p_error_code = 'ERR_DUPLICATE';
            SET p_error_message = 'Product category code already exists.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        INSERT INTO product_category (
            business_id, branch_id, product_segment_id, code, name, description,
            created_by, created_at, is_active, is_deleted
        )
        VALUES (
            p_business_id, p_branch_id, p_product_segment_id, p_code, p_name, p_description,
            p_user, UTC_TIMESTAMP(6), 1, 0
        );

        SET p_id = LAST_INSERT_ID();

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Category created successfully';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 2: UPDATE CATEGORY
       ================================================================ */
    IF p_action = 2 THEN

        -- Check if category exists
        SELECT COUNT(*) INTO v_exist FROM product_category
        WHERE product_category_id = p_product_category_id
          AND is_deleted = 0;

        IF v_exist = 0 THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product category not found or deleted.';
            LEAVE proc_body;
        END IF;

        -- Check for duplicate code (excluding current record)
        SELECT COUNT(*) INTO v_exist FROM product_category
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND code = p_code
          AND product_category_id != p_product_category_id
          AND is_deleted = 0;

        IF v_exist > 0 THEN
            SET p_error_code = 'ERR_DUPLICATE';
            SET p_error_message = 'Product category code already exists.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        UPDATE product_category
        SET
            product_segment_id = p_product_segment_id,
            code = p_code,
            name = p_name,
            description = p_description,
            updated_by = p_user,
            updated_at = UTC_TIMESTAMP(6)
        WHERE product_category_id = p_product_category_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product category not found or deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_product_category_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Category updated successfully';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 3: DELETE CATEGORY (SOFT DELETE)
       ================================================================ */
    IF p_action = 3 THEN

        START TRANSACTION;

        UPDATE product_category
        SET
            is_deleted = 1,
            is_active = 0,
            deleted_at = UTC_TIMESTAMP(6),
            updated_by = p_user,
            updated_at = UTC_TIMESTAMP(6)
        WHERE product_category_id = p_product_category_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product category not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_product_category_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Category deleted successfully';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 4: GET SINGLE CATEGORY
       ================================================================ */
    IF p_action = 4 THEN

        SELECT JSON_OBJECT(
            'product_category_id', product_category_id,
            'business_id', business_id,
            'branch_id', branch_id,
            'product_segment_id', product_segment_id,
            'code', code,
            'name', name,
            'description', description,
            'is_active', is_active,
            'created_by', created_by,
            'created_at', created_at,
            'updated_by', updated_by,
            'updated_at', updated_at
        )
        INTO p_data
        FROM product_category
        WHERE product_category_id = p_product_category_id
          AND is_deleted = 0
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product category not found.';
            LEAVE proc_body;
        END IF;

        SET p_success = TRUE;
        SET p_id = p_product_category_id;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Category fetched successfully';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 5: GET ALL CATEGORIES
       ================================================================ */
    IF p_action = 5 THEN

        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'product_category_id', product_category_id,
                'product_segment_id', product_segment_id,
                'code', code,
                'name', name,
                'description', description,
                'created_at', created_at
            )
        )
        INTO p_data
        FROM product_category
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND is_deleted = 0
        ORDER BY created_at DESC;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Category list fetched';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       INVALID ACTION
       ================================================================ */
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action number provided.';

END;
