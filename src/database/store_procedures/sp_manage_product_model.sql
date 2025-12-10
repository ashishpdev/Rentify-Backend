DROP PROCEDURE sp_manage_product_model;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_product_model`(
    IN  p_action INT,                          -- 1=Create, 2=Update, 3=Delete, 4=GetSingle, 5=GetAll
    IN  p_product_model_id INT,
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_product_segment_id INT,
    IN  p_product_category_id INT,
    IN  p_model_name VARCHAR(255),
    IN  p_description TEXT,
    IN  p_product_model_images JSON,
    IN  p_default_rent DECIMAL(12,2),
    IN  p_default_deposit DECIMAL(12,2),
    IN  p_default_warranty_days INT,
    IN  p_user_id INT,
    IN  p_role_id INT,

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    -- DECLARATIONS
    DECLARE v_role_id INT DEFAULT NULL;
    DECLARE v_exist INT DEFAULT 0;
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

    -- RESET OUTPUT PARAMETERS
    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- ROLE VALIDATION
    SELECT role_id INTO v_role_id
    FROM master_user
    WHERE role_id = p_role_id
    LIMIT 1;

    IF v_role_id IS NULL THEN
        SET p_error_code = 'ERR_ROLE_NOT_FOUND';
        SET p_error_message = 'User role not found.';
        LEAVE proc_body;
    END IF;

    IF p_action IN (1,2,3) AND v_role_id NOT IN (1,2,3) THEN
        SET p_error_code = 'ERR_PERMISSION_DENIED';
        SET p_error_message = 'You do not have permission to modify products.';
        LEAVE proc_body;
    END IF;



    /* 1: CREATE */
    IF p_action = 1 THEN

        -- Check for duplicate model name
        SELECT COUNT(*) INTO v_exist FROM product_model
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND product_segment_id = p_product_segment_id
          AND product_category_id = p_product_category_id
          AND model_name = p_model_name
          AND is_deleted = 0;

        IF v_exist > 0 THEN
            SET p_error_code = 'ERR_DUPLICATE';
            SET p_error_message = 'Product model name already exists.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        INSERT INTO product_model (
            business_id, branch_id, product_segment_id, product_category_id,
            model_name, description, default_rent, default_deposit,
            default_warranty_days, is_active, is_deleted
        )
        VALUES (
            p_business_id, p_branch_id, p_product_segment_id, p_product_category_id,
            p_model_name, p_description, p_default_rent, p_default_deposit,
            p_default_warranty_days, 1, 0
        );

        SET p_id = LAST_INSERT_ID();

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model created successfully.';
        LEAVE proc_body;
    END IF;


    /* 2: UPDATE */
    IF p_action = 2 THEN

        -- Check if model exists
        SELECT COUNT(*) INTO v_exist FROM product_model
        WHERE product_model_id = p_product_model_id
          AND is_deleted = 0;

        IF v_exist = 0 THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product model not found or deleted.';
            LEAVE proc_body;
        END IF;

        -- Check for duplicate model name (excluding current record)
        SELECT COUNT(*) INTO v_exist FROM product_model
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND product_segment_id = p_product_segment_id
          AND product_category_id = p_product_category_id
          AND model_name = p_model_name
          AND product_model_id != p_product_model_id
          AND is_deleted = 0;

        IF v_exist > 0 THEN
            SET p_error_code = 'ERR_DUPLICATE';
            SET p_error_message = 'Product model name already exists.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        UPDATE product_model
        SET 
            product_segment_id = p_product_segment_id,
            product_category_id = p_product_category_id,
            model_name = p_model_name,
            description = p_description,
            default_rent = p_default_rent,
            default_deposit = p_default_deposit,
            default_warranty_days = p_default_warranty_days,
            updated_by = p_user_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE product_model_id = p_product_model_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product model not found or deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_product_model_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model updated successfully.';
        LEAVE proc_body;
    END IF;



    /* 3: DELETE */
    IF p_action = 3 THEN

        START TRANSACTION;

        UPDATE product_model
        SET 
            is_deleted = 1,
            is_active = 0,
            deleted_at = UTC_TIMESTAMP(6),
            updated_by = p_user_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE product_model_id = p_product_model_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product model not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_product_model_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model deleted successfully.';
        LEAVE proc_body;
    END IF;



    /* 4: GET */
    IF p_action = 4 THEN

        SELECT JSON_OBJECT(
            'product_model_id', product_model_id,
            'business_id', business_id,
            'branch_id', branch_id,
            'product_segment_id', product_segment_id,
            'product_category_id', product_category_id,
            'model_name', model_name,
            'description', description,
            'default_rent', default_rent,
            'default_deposit', default_deposit,
            'default_warranty_days', default_warranty_days,
            'is_active', is_active
        )
        INTO p_data
        FROM product_model
        WHERE product_model_id = p_product_model_id
          AND is_deleted = 0
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product model not found.';
            LEAVE proc_body;
        END IF;

        SET p_id = p_product_model_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model fetched successfully.';
        LEAVE proc_body;
    END IF;



    /* 5: GET ALL */
    IF p_action = 5 THEN

        SELECT IFNULL(
            JSON_ARRAYAGG(
                JSON_OBJECT(
                    'product_model_id', pm.product_model_id,
                    'model_name', pm.model_name,
                    'default_rent', pm.default_rent,

                    'product_category_id', pm.product_category_id,
                    'category_name', pc.name,

                    'product_segment_id', pm.product_segment_id,
                    'segment_name', ps.name,

                    'created_at', pm.created_at,
                    'status', CASE WHEN pm.is_active = 1 THEN 'Active' ELSE 'Inactive' END
                )
            ),
            JSON_ARRAY()
        ) INTO p_data
        FROM product_model pm
        STRAIGHT_JOIN product_category pc ON pm.product_category_id = pc.product_category_id
        STRAIGHT_JOIN product_segment ps ON pm.product_segment_id = ps.product_segment_id
        WHERE pm.business_id = p_business_id
        AND pm.branch_id = p_branch_id
        AND pm.is_deleted = 0;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product models fetched successfully.';
        LEAVE proc_body;

    END IF;


    -- INVALID ACTION
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action provided.';

END