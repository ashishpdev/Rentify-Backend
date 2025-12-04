DROP PROCEDURE IF EXISTS sp_manage_product_category;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_product_category`(
    IN  p_action INT,                       -- 1=Create, 2=Update, 3=Delete, 4=GetSingle, 5=GetAll
    IN  p_product_category_id INT,
    IN  p_business_id INT,
    IN  p_branch_id INT,
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
       ERROR HANDLER
       ================================================================ */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        IF p_error_code IS NULL THEN
            SET p_success = FALSE;
            SET p_error_code = 'ERR_SQL_EXCEPTION';
            SET p_error_message = 'Database error during product category operation';
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
        START TRANSACTION;

        INSERT INTO product_category (
            business_id, branch_id, code, name, description,
            created_by, created_at, is_active, is_deleted
        )
        VALUES (
            p_business_id, p_branch_id, p_code, p_name, p_description,
            p_user, NOW(), 1, 0
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
        START TRANSACTION;

        UPDATE product_category
        SET
            code = p_code,
            name = p_name,
            description = p_description,
            updated_by = p_user,
            updated_at = NOW()
        WHERE product_category_id = p_product_category_id
          AND is_deleted = 0;

        SET p_id = p_product_category_id;

        COMMIT;

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
            deleted_at = NOW(),
            updated_by = p_user,
            updated_at = NOW()
        WHERE product_category_id = p_product_category_id
          AND is_deleted = 0;

        SET p_id = p_product_category_id;

        COMMIT;

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
            'code', code,
            'name', name,
            'description', description,
            'is_active', is_active,
            'created_at', created_at,
            'updated_at', updated_at
        )
        INTO p_data
        FROM product_category
        WHERE product_category_id = p_product_category_id
          AND is_deleted = 0
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Category not found';
            LEAVE proc_body;
        END IF;

        SET p_success = TRUE;
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
                'code', code,
                'name', name,
                'description', description,
                'is_active', is_active,
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
    SET p_error_message = 'Invalid action provided';

END;
