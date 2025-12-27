DROP PROCEDURE IF EXISTS sp_manage_business;
CREATE PROCEDURE sp_manage_business(
    IN  p_action INT,
    IN  p_business_id INT,
    IN  p_business_name VARCHAR(255),
    IN  p_business_email VARCHAR(255),
    IN  p_contact_person VARCHAR(255),
    IN  p_contact_number VARCHAR(50),
    IN  p_status_code VARCHAR(100),
    IN  p_user_id INT,                        -- Changed from p_created_by to p_user_id

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    DECLARE v_business_status_id INT DEFAULT NULL;
    DECLARE v_existing_business INT DEFAULT 0;
    DECLARE v_subscription_type_id INT DEFAULT NULL;
    DECLARE v_subscription_status_id INT DEFAULT NULL;
    DECLARE v_billing_cycle_id INT DEFAULT NULL;
    
    -- Permission checking variables
    DECLARE v_has_permission BOOLEAN DEFAULT FALSE;
    DECLARE v_perm_error_code VARCHAR(50);
    DECLARE v_perm_error_msg VARCHAR(500);
    DECLARE v_required_permission VARCHAR(100);
    
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_INVALID_REFERENCE';
        SET p_error_message = 'Foreign key violation.';
    END;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_DUPLICATE';
        SET p_error_message = 'Duplicate entry detected.';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;
        IF v_cno > 0 THEN
            GET DIAGNOSTICS CONDITION 1
                v_errno = MYSQL_ERRNO,
                v_sql_state = RETURNED_SQLSTATE,
                v_error_msg = MESSAGE_TEXT;
        END IF;
        ROLLBACK;
        INSERT IGNORE INTO proc_error_log(proc_name, proc_args, mysql_errno, sql_state, error_message)
        VALUES ('sp_manage_business', CONCAT('action=', p_action, ', user_id=', p_user_id), 
                v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_success = FALSE;
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'Database error occurred';
    END;

    -- Reset outputs
    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- Validate user_id
    IF p_user_id IS NULL OR p_user_id <= 0 THEN
        SET p_error_code = 'ERR_INVALID_USER';
        SET p_error_message = 'Valid user ID is required';
        LEAVE proc_body;
    END IF;

    -- Determine required permission based on action
    SET v_required_permission = CASE p_action
        WHEN 1 THEN 'CREATE_BUSINESS'
        WHEN 2 THEN 'UPDATE_BUSINESS'
        WHEN 3 THEN 'DELETE_BUSINESS'
        WHEN 4 THEN 'READ_BUSINESS'
        ELSE NULL
    END;

    IF v_required_permission IS NULL THEN
        SET p_error_code = 'ERR_INVALID_ACTION';
        SET p_error_message = 'Invalid action specified';
        LEAVE proc_body;
    END IF;

    -- Check permission
    CALL sp_check_permission(
        p_user_id,
        v_required_permission,
        v_has_permission,
        v_perm_error_code,
        v_perm_error_msg
    );

    IF NOT v_has_permission THEN
        SET p_error_code = v_perm_error_code;
        SET p_error_message = v_perm_error_msg;
        LEAVE proc_body;
    END IF;

    -- ACTION 1: CREATE
    IF p_action = 1 THEN
        
        SELECT master_business_status_id INTO v_business_status_id
        FROM master_business_status WHERE code = 'ACTIVE' LIMIT 1;

        SELECT master_subscription_type_id INTO v_subscription_type_id
        FROM master_subscription_type WHERE code = 'TRIAL' LIMIT 1;

        SELECT master_subscription_status_id INTO v_subscription_status_id
        FROM master_subscription_status WHERE code = 'ACTIVE' LIMIT 1;

        SELECT master_billing_cycle_id INTO v_billing_cycle_id
        FROM master_billing_cycle WHERE code = 'MONTHLY' LIMIT 1;

        IF v_business_status_id IS NULL OR v_subscription_type_id IS NULL OR 
           v_subscription_status_id IS NULL OR v_billing_cycle_id IS NULL THEN
            SET p_error_code = 'ERR_MISSING_REFERENCES';
            SET p_error_message = 'Required reference data not found';
            LEAVE proc_body;
        END IF;

        SELECT COUNT(*) INTO v_existing_business
        FROM master_business WHERE email = p_business_email;

        IF v_existing_business > 0 THEN
            SET p_error_code = 'ERR_EMAIL_EXISTS';
            SET p_error_message = 'Business email already exists';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        INSERT INTO master_business (
            business_name, email, contact_person, contact_number,
            status_id, subscription_type_id, subscription_status_id, billing_cycle_id,
            created_by, created_at
        )
        VALUES (
            p_business_name, p_business_email, p_contact_person, p_contact_number,
            v_business_status_id, v_subscription_type_id, v_subscription_status_id,
            v_billing_cycle_id, p_user_id, UTC_TIMESTAMP(6)
        );

        SET p_id = LAST_INSERT_ID();
        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Business created successfully';
        LEAVE proc_body;
    END IF;

    -- ACTION 2: UPDATE
    IF p_action = 2 THEN
        
        IF p_status_code IS NOT NULL THEN
            SELECT master_business_status_id INTO v_business_status_id
            FROM master_business_status WHERE code = p_status_code LIMIT 1;

            IF v_business_status_id IS NULL THEN
                SET p_error_code = 'ERR_INVALID_STATUS';
                SET p_error_message = 'Invalid status code';
                LEAVE proc_body;
            END IF;
        END IF;

        START TRANSACTION;

        UPDATE master_business
        SET 
            business_name = COALESCE(p_business_name, business_name),
            email = COALESCE(p_business_email, email),
            contact_person = COALESCE(p_contact_person, contact_person),
            contact_number = COALESCE(p_contact_number, contact_number),
            status_id = COALESCE(v_business_status_id, status_id),
            updated_by = p_user_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE business_id = p_business_id
          AND deleted_at IS NULL;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Business not found or already deleted';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_business_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Business updated successfully';
        LEAVE proc_body;
    END IF;

    -- ACTION 3: DELETE
    IF p_action = 3 THEN
        
        START TRANSACTION;

        UPDATE master_business
        SET 
            deleted_at = UTC_TIMESTAMP(6),
            updated_by = p_user_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE business_id = p_business_id
          AND deleted_at IS NULL;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Business not found or already deleted';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_business_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Business deleted successfully';
        LEAVE proc_body;
    END IF;

    -- ACTION 4: GET
    IF p_action = 4 THEN
        
        SELECT JSON_OBJECT(
            'business_id', business_id,
            'business_name', business_name,
            'email', email,
            'contact_person', contact_person,
            'contact_number', contact_number,
            'status_id', status_id,
            'subscription_type_id', subscription_type_id,
            'subscription_status_id', subscription_status_id,
            'billing_cycle_id', billing_cycle_id,
            'created_by', created_by,
            'created_at', created_at,
            'updated_by', updated_by,
            'updated_at', updated_at
        )
        INTO p_data
        FROM master_business
        WHERE business_id = p_business_id
          AND deleted_at IS NULL
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Business not found';
            LEAVE proc_body;
        END IF;

        SET p_id = p_business_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Business retrieved successfully';
        LEAVE proc_body;
    END IF;

END;