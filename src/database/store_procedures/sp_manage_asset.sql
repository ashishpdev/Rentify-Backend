DROP PROCEDURE IF EXISTS sp_manage_asset;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_asset`(
    IN p_action INT,                             -- 1=Create,2=Update,3=Delete,4=Get Single,5=Get List
    IN p_asset_id INT,
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_product_segment_id INT,
    IN p_product_category_id INT,
    IN p_product_model_id INT,
    IN p_serial_number VARCHAR(200),
    IN p_product_model_images JSON,
    IN p_product_status_id INT,
    IN p_product_condition_id INT,
    IN p_product_rental_status_id INT,
    IN p_purchase_price DECIMAL(12,2),
    IN p_purchase_date DATETIME(6),
    IN p_current_value DECIMAL(12,2),
    IN p_rent_price DECIMAL(12,2),
    IN p_deposit_amount DECIMAL(12,2),
    IN p_source_type_id INT,
    IN p_borrowed_business VARCHAR(255),
    IN p_borrowed_branch VARCHAR(255),
    IN p_purchase_bill_url VARCHAR(1024),
    IN p_user_id INT,
    IN p_role_id INT,

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body:BEGIN

    DECLARE v_role_id INT DEFAULT NULL;
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
        GLOBAL ERROR HANDLER
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

    /* Reset OUT variables */
    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;


    /* ================================================================
        ROLE VALIDATION
    ================================================================ */
    SELECT role_id INTO v_role_id
    FROM master_user WHERE role_id = p_role_id LIMIT 1;

    IF v_role_id IS NULL THEN
        SET p_error_code = 'ERR_ROLE_NOT_FOUND';
        SET p_error_message = 'User role not found.';
        LEAVE proc_body;
    END IF;

    IF p_action IN (1,2,3) AND v_role_id NOT IN (1,2,3) THEN
        SET p_error_code = 'ERR_PERMISSION_DENIED';
        SET p_error_message = 'You do not have permission to modify asset records.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
        ACTION 1: CREATE ASSET
    ================================================================ */
    IF p_action = 1 THEN

        SELECT COUNT(*) INTO v_exist FROM asset
        WHERE serial_number = p_serial_number AND is_deleted = 0;

        IF v_exist > 0 THEN
            SET p_error_code='ERR_DUPLICATE_SERIAL';
            SET p_error_message='Serial number already exists.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        INSERT INTO asset (
            business_id, branch_id, product_segment_id, product_category_id,
            product_model_id, serial_number, product_status_id,
            product_condition_id, product_rental_status_id, purchase_price, purchase_date,
            current_value, rent_price, deposit_amount, source_type_id,
            borrowed_from_business_name, borrowed_from_branch_name, purchase_bill_url,
            created_by
        )
        VALUES (
            p_business_id, p_branch_id, p_product_segment_id, p_product_category_id,
            p_product_model_id, p_serial_number, p_product_status_id,
            p_product_condition_id, p_product_rental_status_id, p_purchase_price, p_purchase_date,
            p_current_value, p_rent_price, p_deposit_amount, p_source_type_id,
            p_borrowed_business, p_borrowed_branch, p_purchase_bill_url,
            p_user_id
        );

        SET p_id = LAST_INSERT_ID();
        COMMIT;

        SET p_success=TRUE;
        SET p_error_code='SUCCESS';
        SET p_error_message='Asset created successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
        ACTION 2: UPDATE ASSET
    ================================================================ */
    IF p_action = 2 THEN

        START TRANSACTION;

        UPDATE asset SET
            business_id = p_business_id,
            branch_id = p_branch_id,
            product_segment_id = p_product_segment_id,
            product_category_id = p_product_category_id,
            product_model_id = p_product_model_id,
            serial_number = p_serial_number,
            product_status_id = p_product_status_id,
            product_condition_id = p_product_condition_id,
            product_rental_status_id = p_product_rental_status_id,
            purchase_price = p_purchase_price,
            purchase_date = p_purchase_date,
            current_value = p_current_value,
            rent_price = p_rent_price,
            deposit_amount = p_deposit_amount,
            source_type_id = p_source_type_id,
            borrowed_from_business_name = p_borrowed_business,
            borrowed_from_branch_name = p_borrowed_branch,
            purchase_bill_url = p_purchase_bill_url,
            updated_by = p_user_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE asset_id = p_asset_id AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code='ERR_NOT_FOUND';
            SET p_error_message='Asset not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_asset_id;
        SET p_success=TRUE;
        SET p_error_code='SUCCESS';
        SET p_error_message='Asset updated successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
        ACTION 3: DELETE (SOFT DELETE)
    ================================================================ */
    IF p_action = 3 THEN

        START TRANSACTION;

        UPDATE asset SET
            is_deleted = 1,
            is_active = 0,
            deleted_at = UTC_TIMESTAMP(6),
            updated_by = p_user_id
        WHERE asset_id = p_asset_id AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code='ERR_NOT_FOUND';
            SET p_error_message='Asset not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_success=TRUE;
        SET p_id = p_asset_id;
        SET p_error_code='SUCCESS';
        SET p_error_message='Asset deleted successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
        ACTION 4: GET SINGLE ASSET
    ================================================================ */
    IF p_action = 4 THEN

        SELECT JSON_OBJECT(
            'asset_id',asset_id,
            'business_id',business_id,
            'branch_id',branch_id,
            'product_segment_id',product_segment_id,
            'product_category_id',product_category_id,
            'product_model_id',product_model_id,
            'serial_number',serial_number,
            'product_status_id',product_status_id,
            'product_condition_id',product_condition_id,
            'product_rental_status_id',product_rental_status_id,
            'purchase_price',purchase_price,
            'purchase_date',purchase_date,
            'current_value',current_value,
            'rent_price',rent_price,
            'deposit_amount',deposit_amount,
            'source_type_id',source_type_id,
            'borrowed_from_business_name',borrowed_from_business_name,
            'borrowed_from_branch_name',borrowed_from_branch_name,
            'purchase_bill_url',purchase_bill_url,
            'created_at',created_at,
            'updated_at',updated_at
        ) INTO p_data
        FROM asset WHERE asset_id = p_asset_id AND is_deleted=0
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code='ERR_NOT_FOUND';
            SET p_error_message='Asset record not found.';
            LEAVE proc_body;
        END IF;

        SET p_success=TRUE;
        SET p_error_code='SUCCESS';
        SET p_error_message='Asset details fetched.';
        SET p_id = p_asset_id;
        LEAVE proc_body;
    END IF;



    /* ================================================================
        ACTION 5: GET LIST
    ================================================================ */
    IF p_action = 5 THEN

        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'asset_id', asset_id,
                'serial_number', serial_number,
                'product_status_id', product_status_id,
                'rent_price', rent_price
            )
        ) INTO p_data
        FROM asset
        WHERE business_id=p_business_id AND branch_id=p_branch_id AND is_deleted=0
        ORDER BY created_at DESC;

        SET p_success=TRUE;
        SET p_error_code='SUCCESS';
        SET p_error_message='Asset list fetched.';
        LEAVE proc_body;
    END IF;



    /* INVALID ACTION */
    SET p_error_code='ERR_INVALID_ACTION';
    SET p_error_message='Invalid action provided.';

END;
