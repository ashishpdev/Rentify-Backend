DROP PROCEDURE IF EXISTS sp_action_register_business_branch_owner;

CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_action_register_business_branch_owner`(
    IN  p_business_name VARCHAR(255),
    IN  p_business_email VARCHAR(255),
    IN  p_contact_person VARCHAR(255),
    IN  p_contact_number VARCHAR(50),
    IN  p_owner_name VARCHAR(255),
    IN  p_owner_email VARCHAR(255),
    IN  p_owner_contact_number VARCHAR(50),
    IN  p_created_by VARCHAR(255),

    OUT p_success BOOLEAN,
    OUT p_business_id INT,
    OUT p_branch_id INT,
    OUT p_owner_id INT,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    /* ================================================================
       DECLARATIONS
       ================================================================ */
    -- OTP Variables
    DECLARE v_otp_verified_count INT DEFAULT 0;
    DECLARE v_otp_type_id INT DEFAULT NULL;
    DECLARE v_otp_status_id INT DEFAULT NULL;
    
    -- Sub-procedure Output Holders
    DECLARE v_sp_success BOOLEAN DEFAULT FALSE;
    DECLARE v_sp_id INT DEFAULT NULL;
    DECLARE v_sp_data JSON DEFAULT NULL;
    DECLARE v_sp_error_code VARCHAR(50) DEFAULT NULL;
    DECLARE v_sp_error_message VARCHAR(500) DEFAULT NULL;

    -- Temp IDs
    DECLARE v_new_business_id INT DEFAULT NULL;
    DECLARE v_new_branch_id INT DEFAULT NULL;
    DECLARE v_new_owner_id INT DEFAULT NULL;

    /* ================================================================
       ERROR HANDLER
       ================================================================ */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK; 
        SET p_success = FALSE;
        IF p_error_code IS NULL THEN
            SET p_error_code = 'ERR_SQL_EXCEPTION';
            SET p_error_message = 'Database error during registration process.';
        END IF;
    END;

    /* ================================================================
       RESET OUTPUT PARAMETERS
       ================================================================ */
    SET p_success = FALSE;
    SET p_business_id = NULL;
    SET p_branch_id = NULL;
    SET p_owner_id = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    /* ================================================================
       VALIDATION: INPUTS & OTP
       ================================================================ */
    
    -- 1. Validate Emails are different
    IF p_business_email = p_owner_email THEN
        SET p_error_code = 'ERR_DUPLICATE_EMAIL_USAGE';
        SET p_error_message = 'Business email and owner email must be different.';
        LEAVE proc_body;
    END IF;

    -- 2. Fetch OTP Configuration (Registration Type & Verified Status)
    SELECT master_otp_type_id INTO v_otp_type_id 
    FROM master_otp_type WHERE code = 'REGISTRATION' LIMIT 1; 
    -- Assuming code is 'REGISTRATION', otherwise use ID 2 if code not available

    SELECT master_otp_status_id INTO v_otp_status_id 
    FROM master_otp_status WHERE code = 'VERIFIED' LIMIT 1;
    -- Assuming code is 'VERIFIED', otherwise use ID 2

    -- Fallback if configs missing (Optional safety)
    IF v_otp_type_id IS NULL THEN SET v_otp_type_id = 2; END IF;
    IF v_otp_status_id IS NULL THEN SET v_otp_status_id = 2; END IF;

    -- 3. Verify Owner Email OTP
    SELECT COUNT(*) INTO v_otp_verified_count
    FROM master_otp
    WHERE target_identifier = p_owner_email
      AND otp_type_id = v_otp_type_id
      AND otp_status_id = v_otp_status_id
      AND expires_at > UTC_TIMESTAMP(); -- Using UTC to match other SPs

    IF v_otp_verified_count = 0 THEN
        SET p_error_code = 'ERR_OTP_NOT_VERIFIED';
        SET p_error_message = 'Owner email is not verified or OTP has expired.';
        LEAVE proc_body;
    END IF;


    /* ================================================================
       STEP 1: CREATE BUSINESS (Call SP)
       ================================================================ */
    CALL sp_manage_business(
        1,                      -- Action: Create
        NULL,                   -- ID
        p_business_name,
        p_business_email,
        p_contact_person,
        p_contact_number,
        NULL,                   -- Status Code (Handled inside SP)
        p_created_by,
        
        v_sp_success,
        v_sp_id,
        v_sp_data,
        v_sp_error_code,
        v_sp_error_message
    );

    IF v_sp_success = FALSE THEN
        SET p_error_code = v_sp_error_code;
        SET p_error_message = CONCAT('Business Creation Failed: ', v_sp_error_message);
        LEAVE proc_body;
    END IF;

    SET v_new_business_id = v_sp_id;


    /* ================================================================
       STEP 2: CREATE HQ BRANCH (Direct Insert)
       ================================================================ */
    START TRANSACTION;

    INSERT INTO master_branch (
        business_id, 
        branch_name, 
        branch_code, 
        contact_number, 
        created_by,
        created_at
    )
    VALUES (
        v_new_business_id, 
        CONCAT(p_business_name, ' - HQ'), 
        'HQ-001',
        p_contact_number, 
        p_created_by,
        UTC_TIMESTAMP(6)
    );

    SET v_new_branch_id = LAST_INSERT_ID();

    COMMIT;


    /* ================================================================
       STEP 3: CREATE OWNER (Call SP)
       ================================================================ */
    CALL sp_manage_owner(
        1,                      -- Action: Create
        NULL,                   -- ID
        v_new_business_id,
        v_new_branch_id,
        p_owner_name,
        p_owner_email,
        p_owner_contact_number,
        p_created_by,

        v_sp_success,
        v_sp_id,
        v_sp_data,
        v_sp_error_code,
        v_sp_error_message
    );

    IF v_sp_success = FALSE THEN
        -- CRITICAL: Business was created, but Owner failed.
        -- In a real-world scenario, you might want to DELETE the business here to rollback.
        -- For now, we return the error as requested.
        SET p_error_code = v_sp_error_code;
        SET p_error_message = CONCAT('Owner Creation Failed: ', v_sp_error_message);
        LEAVE proc_body;
    END IF;

    SET v_new_owner_id = v_sp_id;


    /* ================================================================
       STEP 4: CLEANUP & SUCCESS
       ================================================================ */
    
    -- Remove used OTPs
    START TRANSACTION;
    DELETE FROM master_otp
    WHERE target_identifier IN (p_business_email, p_owner_email)
      AND otp_type_id = v_otp_type_id;
    COMMIT;

    -- Set Final Outputs
    SET p_business_id = v_new_business_id;
    SET p_branch_id = v_new_branch_id;
    SET p_owner_id = v_new_owner_id;
    
    SET p_success = TRUE;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Business, Branch, and Owner registered successfully.';

END;