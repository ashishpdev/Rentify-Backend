DROP PROCEDURE IF EXISTS sp_manage_business;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_business`(
    IN  p_action INT,                      -- 1=Create, 2=Update, 3=Delete, 4=Get Single
    IN  p_business_id INT,
    IN  p_business_name VARCHAR(255),
    IN  p_business_email VARCHAR(255),
    IN  p_contact_person VARCHAR(255),
    IN  p_contact_number VARCHAR(50),
    IN  p_status_code VARCHAR(100),
    IN  p_created_by VARCHAR(255),

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
    DECLARE v_business_status_id INT DEFAULT NULL;
    DECLARE v_existing_business INT DEFAULT 0;
    DECLARE v_subscription_type_id INT DEFAULT NULL;
    DECLARE v_subscription_status_id INT DEFAULT NULL;
    DECLARE v_billing_cycle_id INT DEFAULT NULL;
    DECLARE v_user_role_id INT DEFAULT NULL;



    /* ================================================================
       ERROR HANDLER
       ================================================================ */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;

        IF p_error_code IS NULL THEN
            SET p_error_code = 'ERR_SQL_EXCEPTION';
            SET p_error_message = 'Database error during business operation.';
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
       VALIDATE USER ROLE FOR UPDATE / DELETE
       ================================================================ */
    IF p_action IN (2,3) THEN

        SELECT role_id INTO v_user_role_id
        FROM master_user
        WHERE email = p_created_by AND is_deleted = 0
        LIMIT 1;

        IF v_user_role_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_ROLE';
            SET p_error_message = 'Unauthorized user: Role not found.';
            LEAVE proc_body;
        END IF;

        IF v_user_role_id != 1 THEN
            SET p_error_code = 'ERR_PERMISSION_DENIED';
            SET p_error_message = 'You are not allowed to modify business records.';
            LEAVE proc_body;
        END IF;

    END IF;



    /* ================================================================
       ACTION 1: CREATE BUSINESS
       ================================================================ */
    IF p_action = 1 THEN

        /* Fetch ACTIVE status ID */
        SELECT master_business_status_id INTO v_business_status_id
        FROM master_business_status
        WHERE code = 'ACTIVE' AND is_deleted = 0
        LIMIT 1;
        IF v_business_status_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_STATUS';
            SET p_error_message = 'Business status ACTIVE not found.';
            LEAVE proc_body;
        END IF;

        /* Fetch TRIAL subscription type */
        SELECT master_subscription_type_id INTO v_subscription_type_id
        FROM master_subscription_type
        WHERE code = 'TRIAL' AND is_deleted = 0
        LIMIT 1;
        IF v_subscription_type_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_SUBSCRIPTION';
            SET p_error_message = 'Subscription type TRIAL not found.';
            LEAVE proc_body;
        END IF;

        /* Fetch ACTIVE subscription status */
        SELECT master_subscription_status_id INTO v_subscription_status_id
        FROM master_subscription_status
        WHERE code = 'ACTIVE' AND is_deleted = 0
        LIMIT 1;
        IF v_subscription_status_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_SUBSCRIPTION_STATUS';
            SET p_error_message = 'Subscription status ACTIVE not found.';
            LEAVE proc_body;
        END IF;

        /* Fetch MONTHLY billing cycle */
        SELECT master_billing_cycle_id INTO v_billing_cycle_id
        FROM master_billing_cycle
        WHERE code = 'MONTHLY' AND is_deleted = 0
        LIMIT 1;
        IF v_billing_cycle_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_BILLING_CYCLE';
            SET p_error_message = 'Billing cycle MONTHLY not found.';
            LEAVE proc_body;
        END IF;

        /* Check duplicate email */
        SELECT COUNT(*) INTO v_existing_business
        FROM master_business
        WHERE email = p_business_email AND is_deleted = 0;

        IF v_existing_business > 0 THEN
            SET p_error_code = 'ERR_EMAIL_EXISTS';
            SET p_error_message = 'Business email already exists.';
            LEAVE proc_body;
        END IF;


        /* Insert business */
        START TRANSACTION;

        INSERT INTO master_business (
            business_name, email, contact_person, contact_number,
            status_id, subscription_type_id, subscription_status_id, billing_cycle_id,
            created_by
        )
        VALUES (
            p_business_name, p_business_email, p_contact_person, p_contact_number,
            v_business_status_id, v_subscription_type_id, v_subscription_status_id,
            v_billing_cycle_id, p_created_by
        );

        SET p_id = LAST_INSERT_ID();

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Business created successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 2: UPDATE BUSINESS
       ================================================================ */
    IF p_action = 2 THEN

        /* Fetch required status */
        SELECT master_business_status_id INTO v_business_status_id
        FROM master_business_status
        WHERE code = p_status_code AND is_deleted = 0
        LIMIT 1;

        IF v_business_status_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_STATUS';
            SET p_error_message = 'Invalid status code.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        UPDATE master_business
        SET 
            business_name = p_business_name,
            email = p_business_email,
            contact_person = p_contact_person,
            contact_number = p_contact_number,
            status_id = v_business_status_id,
            updated_by = p_created_by,
            updated_at = CURRENT_TIMESTAMP(6)
        WHERE business_id = p_business_id AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Business not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_business_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Business updated successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 3: DELETE BUSINESS (Soft Delete)
       ================================================================ */
    IF p_action = 3 THEN

        START TRANSACTION;

        UPDATE master_business
        SET 
            is_deleted = 1,
            deleted_at = CURRENT_TIMESTAMP(6),
            updated_by = p_created_by,
            updated_at = CURRENT_TIMESTAMP(6)
        WHERE business_id = p_business_id AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Business not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_business_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Business deleted successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 4: GET BUSINESS DETAILS
       ================================================================ */
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
        WHERE business_id = p_business_id AND is_deleted = 0
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Business not found.';
            LEAVE proc_body;
        END IF;

        SET p_id = p_business_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Business details fetched successfully.';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       INVALID ACTION
       ================================================================ */
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action specified.';

END;
