DROP PROCEDURE IF EXISTS sp_manage_product_segment;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_product_segment`(
    IN p_action INT,                        -- 1=Create,2=Update,3=Delete,4=Get Single,5=Get List
    IN p_product_segment_id INT,
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_code VARCHAR(128),
    IN p_name VARCHAR(255),
    IN p_description TEXT,
    IN p_user_id INT,
    IN p_role_id INT,

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
    DECLARE v_role_id INT DEFAULT NULL;
    DECLARE v_exist INT DEFAULT 0;

    /* ================================================================
       ERROR HANDLER
    ================================================================ */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
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
       ROLE VALIDATION
    ================================================================ */
    SELECT role_id INTO v_role_id
    FROM master_user
    WHERE role_id = p_role_id
    LIMIT 1;

    IF v_role_id IS NULL THEN
        SET p_error_code = 'ERR_ROLE_NOT_FOUND';
        SET p_error_message = 'Role not found.';
        LEAVE proc_body;
    END IF;

    /* Only Admin/Manager can modify */
    IF p_action IN (1,2,3) AND v_role_id NOT IN (1,2,3) THEN
        SET p_error_code = 'ERR_PERMISSION_DENIED';
        SET p_error_message = 'User has no permission to modify product segment.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 1: CREATE
    ================================================================ */
    IF p_action = 1 THEN

        -- Unique validation
        SELECT COUNT(*) INTO v_exist FROM product_segment
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND (code = p_code OR name = p_name)
          AND is_deleted = 0;

        IF v_exist > 0 THEN
            SET p_error_code='ERR_DUPLICATE';
            SET p_error_message='Product segment code already exists.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        INSERT INTO product_segment (
            business_id, branch_id, code, name, description,
            created_by
        )
        VALUES (
            p_business_id, p_branch_id, p_code, p_name, p_description,
            p_user_id
        );

        SET p_id = LAST_INSERT_ID();

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product segment created successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 2: UPDATE
    ================================================================ */
    IF p_action = 2 THEN

        START TRANSACTION;

        UPDATE product_segment
        SET
            code = p_code,
            name = p_name,
            description = p_description,
            updated_by = p_user_id,
            updated_at = CURRENT_TIMESTAMP(6)
        WHERE product_segment_id = p_product_segment_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code='ERR_NOT_FOUND';
            SET p_error_message='Product segment not found or deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_product_segment_id;
        SET p_success=TRUE;
        SET p_error_code='SUCCESS';
        SET p_error_message='Product segment updated successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 3: DELETE (Soft Delete)
    ================================================================ */
    IF p_action = 3 THEN

        START TRANSACTION;

        UPDATE product_segment
        SET
            is_deleted = 1,
            is_active = 0,
            deleted_at = CURRENT_TIMESTAMP(6),
            updated_by = p_user_id
        WHERE product_segment_id = p_product_segment_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code='ERR_NOT_FOUND';
            SET p_error_message='Product segment not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_product_segment_id;
        SET p_success=TRUE;
        SET p_error_code='SUCCESS';
        SET p_error_message='Product segment deleted successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 4: GET SINGLE
    ================================================================ */
    IF p_action = 4 THEN

        SELECT JSON_OBJECT(
            'product_segment_id', product_segment_id,
            'business_id', business_id,
            'branch_id', branch_id,
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
        FROM product_segment
        WHERE product_segment_id = p_product_segment_id
          AND is_deleted=0
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code='ERR_NOT_FOUND';
            SET p_error_message='Product segment not found.';
            LEAVE proc_body;
        END IF;

        SET p_success=TRUE;
        SET p_id=p_product_segment_id;
        SET p_error_code='SUCCESS';
        SET p_error_message='Product segment fetched successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 5: GET ALL LIST
    ================================================================ */
    IF p_action=5 THEN

        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'product_segment_id', product_segment_id,
                'code', code,
                'name', name,
                'description', description,
                'created_at', created_at
            )
        )
        INTO p_data
        FROM product_segment
        WHERE business_id=p_business_id
          AND branch_id=p_branch_id
          AND is_deleted=0
        ORDER BY created_at DESC;

        SET p_success=TRUE;
        SET p_error_code='SUCCESS';
        SET p_error_message='Product segment list fetched.';
        LEAVE proc_body;
    END IF;



    /* INVALID ACTION */
    SET p_error_code='ERR_INVALID_ACTION';
    SET p_error_message='Invalid action number provided.';

END;
