DROP PROCEDURE IF EXISTS sp_manage_product_model;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_product_model`(
    IN  p_action INT,                          -- 1=Create, 2=Update, 3=Delete, 4=GetSingle, 5=GetAll
    IN  p_product_model_id INT,
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_product_category_id INT,
    IN  p_model_name VARCHAR(255),
    IN  p_description TEXT,
    IN  p_product_images JSON,
    IN  p_default_rent DECIMAL(10,2),
    IN  p_default_deposit DECIMAL(10,2),
    IN  p_default_warranty_days INT,
    IN  p_total_quantity INT,
    IN  p_available_quantity INT,
    IN  p_user_id INT,
    IN  p_role_id INT,

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



    /* ================================================================
       GLOBAL ERROR HANDLER
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
        SET p_error_message = 'User role not found.';
        LEAVE proc_body;
    END IF;

    IF p_action IN (1,2,3) AND v_role_id NOT IN (1,2,3) THEN
        SET p_error_code = 'ERR_PERMISSION_DENIED';
        SET p_error_message = 'You do not have permission to modify products.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 1: CREATE PRODUCT
       ================================================================ */
    IF p_action = 1 THEN

        START TRANSACTION;

        INSERT INTO product_model (
            business_id, branch_id, product_category_id,
            model_name, description, product_images,
            default_rent, default_deposit, default_warranty_days,
            total_quantity, available_quantity,
            created_by, created_at,
            is_active, is_deleted
        )
        VALUES (
            p_business_id, p_branch_id, p_product_category_id,
            p_model_name, p_description, p_product_images,
            p_default_rent, p_default_deposit, p_default_warranty_days,
            p_total_quantity, p_available_quantity,
            p_user_id, NOW(),
            1, 0
        );

        SET p_id = LAST_INSERT_ID();

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product created successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 2: UPDATE PRODUCT
       ================================================================ */
    IF p_action = 2 THEN

        START TRANSACTION;

        UPDATE product_model
        SET 
            product_category_id = p_product_category_id,
            model_name = p_model_name,
            description = p_description,
            product_images = p_product_images,
            default_rent = p_default_rent,
            default_deposit = p_default_deposit,
            default_warranty_days = p_default_warranty_days,
            total_quantity = p_total_quantity,
            available_quantity = p_available_quantity,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE product_model_id = p_product_model_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_product_model_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product updated successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 3: DELETE PRODUCT (SOFT DELETE)
       ================================================================ */
    IF p_action = 3 THEN

        START TRANSACTION;

        UPDATE product_model
        SET 
            is_deleted = 1,
            is_active = 0,
            deleted_at = NOW(),
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE product_model_id = p_product_model_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_product_model_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product deleted successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 4: GET SINGLE PRODUCT
       ================================================================ */
    IF p_action = 4 THEN

        SELECT JSON_OBJECT(
            'product_model_id', product_model_id,
            'business_id', business_id,
            'branch_id', branch_id,
            'product_category_id', product_category_id,
            'model_name', model_name,
            'description', description,
            'product_images', product_images,
            'default_rent', default_rent,
            'default_deposit', default_deposit,
            'default_warranty_days', default_warranty_days,
            'total_quantity', total_quantity,
            'available_quantity', available_quantity,
            'created_by', created_by,
            'created_at', created_at,
            'updated_by', updated_by,
            'updated_at', updated_at,
            'is_active', is_active,
            'is_deleted', is_deleted
        )
        INTO p_data
        FROM product_model
        WHERE product_model_id = p_product_model_id
          AND is_deleted = 0
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product not found.';
            LEAVE proc_body;
        END IF;

        SET p_id = p_product_model_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product fetched successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 5: GET ALL PRODUCTS
       ================================================================ */
    IF p_action = 5 THEN

        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'product_model_id', product_model_id,
                'product_category_id', product_category_id,
                'model_name', model_name,
                'description', description,
                'default_rent', default_rent,
                'default_deposit', default_deposit,
                'default_warranty_days', default_warranty_days,
                'total_quantity', total_quantity,
                'available_quantity', available_quantity,
                'created_at', created_at
            )
        )
        INTO p_data
        FROM product_model
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND is_deleted = 0
        ORDER BY created_at DESC;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product list fetched successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       INVALID ACTION
       ================================================================ */
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action provided.';

END;
