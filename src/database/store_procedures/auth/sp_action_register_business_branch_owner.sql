DROP PROCEDURE IF EXISTS sp_action_register_business_branch_owner;
CREATE PROCEDURE sp_action_register_business_branch_owner(
    IN  p_business_name         VARCHAR(200),
    IN  p_business_email        VARCHAR(255),
    IN  p_contact_person        VARCHAR(200),
    IN  p_contact_number        VARCHAR(20),
    IN  p_created_by            VARCHAR(100),
    IN  p_owner_email           VARCHAR(255),
    IN  p_owner_contact_number  VARCHAR(20),
    IN  p_updated_by            VARCHAR(100),
    
    OUT p_success               BOOLEAN,
    OUT p_business_id           INT,
    OUT p_branch_id             INT,
    OUT p_owner_id              INT,
    OUT p_error_code            VARCHAR(50),
    OUT p_error_message         VARCHAR(500)
)
proc_label: BEGIN

    DECLARE v_business_id INT DEFAULT NULL;
    DECLARE v_branch_id INT DEFAULT NULL;
    DECLARE v_owner_id INT DEFAULT NULL;
    DECLARE v_email_exists INT DEFAULT 0;
    DECLARE v_business_email_exists INT DEFAULT 0;
    DECLARE v_active_status_id TINYINT DEFAULT 1;
    DECLARE v_owner_role_id TINYINT DEFAULT 1; -- Assuming 1 is OWNER role
    DECLARE v_subscription_type_id TINYINT DEFAULT 1; -- Default subscription
    DECLARE v_subscription_status_id TINYINT DEFAULT 1; -- Active subscription
    DECLARE v_billing_cycle_id TINYINT DEFAULT 2; -- Monthly billing
    DECLARE v_default_password_hash VARCHAR(255) DEFAULT ''; -- Empty, user must set via OTP
    
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- Error handlers
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_FOREIGN_KEY_VIOLATION';
        SET p_error_message = 'Invalid reference data. Please contact support.';
    END;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_DUPLICATE_ENTRY';
        SET p_error_message = 'Email already registered. Please use a different email.';
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
        INSERT INTO proc_error_log(proc_name, proc_args, mysql_errno, sql_state, error_message)
        VALUES ('sp_action_register_business_branch_owner', 
                CONCAT('business_email=', LEFT(p_business_email, 100)), 
                v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_success = FALSE;
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'Registration failed due to unexpected error.';
    END;

    -- Initialize output parameters
    SET p_success = FALSE;
    SET p_business_id = NULL;
    SET p_branch_id = NULL;
    SET p_owner_id = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- Input validation
    IF p_business_name IS NULL OR p_business_name = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Business name is required.';
        LEAVE proc_label;
    END IF;

    IF p_business_email IS NULL OR p_business_email = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Business email is required.';
        LEAVE proc_label;
    END IF;

    IF p_owner_email IS NULL OR p_owner_email = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Owner email is required.';
        LEAVE proc_label;
    END IF;

    IF p_contact_number IS NULL OR p_contact_number = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Contact number is required.';
        LEAVE proc_label;
    END IF;

    -- Check if business email and owner email are different
    IF p_business_email = p_owner_email THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Business email and owner email must be different.';
        LEAVE proc_label;
    END IF;

    -- Check if business email already exists
    SELECT COUNT(*) INTO v_business_email_exists
    FROM master_business
    WHERE email = p_business_email AND deleted_at IS NULL;

    IF v_business_email_exists > 0 THEN
        SET p_error_code = 'ERR_BUSINESS_EMAIL_EXISTS';
        SET p_error_message = 'Business email already registered.';
        LEAVE proc_label;
    END IF;

    -- Check if owner email already exists in any business
    SELECT COUNT(*) INTO v_email_exists
    FROM master_user
    WHERE email = p_owner_email AND deleted_at IS NULL;

    IF v_email_exists > 0 THEN
        SET p_error_code = 'ERR_OWNER_EMAIL_EXISTS';
        SET p_error_message = 'Owner email already registered.';
        LEAVE proc_label;
    END IF;

    -- Verify OTP was completed for owner email (optional check)
    -- Uncomment if you want to enforce OTP verification before registration
    /*
    DECLARE v_otp_verified INT DEFAULT 0;
    SELECT COUNT(*) INTO v_otp_verified
    FROM master_otp
    WHERE target_identifier = p_owner_email
      AND otp_type_id = 2 -- REGISTRATION type
      AND verified_at IS NOT NULL
      AND verified_at > DATE_SUB(NOW(), INTERVAL 30 MINUTE);
    
    IF v_otp_verified = 0 THEN
        SET p_error_code = 'ERR_OTP_NOT_VERIFIED';
        SET p_error_message = 'Owner email not verified. Please verify OTP first.';
        LEAVE proc_label;
    END IF;
    */

    START TRANSACTION;

    -- 1. Create Business
    INSERT INTO master_business (
        business_name,
        email,
        contact_person,
        contact_number,
        status_id,
        subscription_type_id,
        subscription_status_id,
        billing_cycle_id,
        subscription_start_date,
        created_by,
        created_at,
        is_active
    ) VALUES (
        p_business_name,
        p_business_email,
        p_contact_person,
        p_contact_number,
        v_active_status_id,
        v_subscription_type_id,
        v_subscription_status_id,
        v_billing_cycle_id,
        CURDATE(),
        p_created_by,
        UTC_TIMESTAMP(6),
        TRUE
    );

    SET v_business_id = LAST_INSERT_ID();

    -- 2. Create Main Branch
    INSERT INTO master_branch (
        business_id,
        branch_name,
        branch_code,
        address_line,
        city,
        state,
        country,
        pincode,
        contact_number,
        timezone,
        created_by,
        created_at,
        is_active
    ) VALUES (
        v_business_id,
        'Main Branch',
        'MAIN',
        'Head Office',
        'Not Specified',
        'Not Specified',
        'IN',
        '000000',
        p_contact_number,
        'Asia/Kolkata',
        p_created_by,
        UTC_TIMESTAMP(6),
        TRUE
    );

    SET v_branch_id = LAST_INSERT_ID();

    -- 3. Create Owner User Account
    INSERT INTO master_user (
        business_id,
        branch_id,
        role_id,
        is_owner,
        name,
        email,
        hash_password,
        contact_number,
        employee_code,
        joining_date,
        created_by,
        created_at,
        is_active
    ) VALUES (
        v_business_id,
        v_branch_id,
        v_owner_role_id,
        TRUE, -- is_owner
        p_contact_person,
        p_owner_email,
        v_default_password_hash, -- Empty password, must be set later
        p_owner_contact_number,
        'OWNER001',
        CURDATE(),
        p_created_by,
        UTC_TIMESTAMP(6),
        TRUE
    );

    SET v_owner_id = LAST_INSERT_ID();

    -- 4. Clean up used OTP (if verification was done)
    DELETE FROM master_otp
    WHERE target_identifier = p_owner_email
      AND otp_type_id = 2; -- REGISTRATION type

    COMMIT;

    -- Set success response
    SET p_success = TRUE;
    SET p_business_id = v_business_id;
    SET p_branch_id = v_branch_id;
    SET p_owner_id = v_owner_id;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Business registered successfully.';

END;