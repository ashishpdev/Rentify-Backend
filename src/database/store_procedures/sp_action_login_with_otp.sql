DROP PROCEDURE IF EXISTS sp_action_login_with_otp;
CREATE PROCEDURE sp_action_login_with_otp(
    IN p_email VARCHAR(255),
    IN p_otp_code_hash VARCHAR(255),
    IN p_ip_address VARCHAR(255),
    OUT p_user_id INT,
    OUT p_business_id INT,
    OUT p_branch_id INT,
    OUT p_role_id INT,
    OUT p_contact_number VARCHAR(50),
    OUT p_user_name VARCHAR(255),
    OUT p_business_name VARCHAR(255),
    OUT p_branch_name VARCHAR(255),
    OUT p_role_name VARCHAR(255),
    OUT p_is_owner BOOLEAN,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_otp_record_id CHAR(36) DEFAULT NULL;
    DECLARE v_otp_status_id INT DEFAULT NULL;
    DECLARE v_expires_at DATETIME(6) DEFAULT NULL;
    DECLARE v_verified_status_id INT DEFAULT NULL;
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
        SET p_error_message = 'Error: Invalid reference - Segment, Category or Model not found.';
    END;

    -- Error handler for rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;
            GET DIAGNOSTICS CONDITION v_cno
            v_errno = MYSQL_ERRNO,
            v_sql_state = RETURNED_SQLSTATE,
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_error_message = 'An error occurred. Transaction rolled back.';
    END;

    SET p_user_id = NULL;
    SET p_business_id = NULL;
    SET p_branch_id = NULL;
    SET p_role_id = NULL;
    SET p_contact_number = NULL;
    SET p_user_name = NULL;
    SET p_business_name = NULL;
    SET p_branch_name = NULL;
    SET p_role_name = NULL;
    SET p_is_owner = FALSE;
    SET p_error_message = NULL;

    /* Labeled block to control flow with LEAVE for early exits */
    main_block: BEGIN

        START TRANSACTION;

        -- Get VERIFIED status ID
        SELECT master_otp_status_id
          INTO v_verified_status_id
          FROM master_otp_status
         WHERE code = 'VERIFIED' AND is_deleted = 0
         LIMIT 1;

        -- Find OTP record by email, hash, and type (LOGIN)
        -- Check if OTP matches the provided hash and hasn't expired
        SELECT id, otp_status_id, expires_at
          INTO v_otp_record_id, v_otp_status_id, v_expires_at
          FROM master_otp
         WHERE target_identifier = p_email
           AND otp_code_hash = p_otp_code_hash
           AND otp_type_id = 1
         ORDER BY created_at DESC
         LIMIT 1;

        -- Check if OTP record was found
        IF v_otp_record_id IS NULL THEN
            SET p_error_message = 'Invalid OTP code';
            LEAVE main_block;
        END IF;

        -- Check if OTP has expired
        IF UTC_TIMESTAMP() > v_expires_at THEN
            SET p_error_message = 'OTP has expired';
            LEAVE main_block;
        END IF;

        -- Mark OTP as verified if not already verified
        IF v_otp_status_id != v_verified_status_id THEN
            UPDATE master_otp
            SET 
                verified_at = UTC_TIMESTAMP(6),
                otp_status_id = v_verified_status_id,
                updated_at = UTC_TIMESTAMP(6)
            WHERE id = v_otp_record_id;
        END IF;

        -- Fetch user details from master_user
        SELECT u.master_user_id, u.business_id, u.branch_id, u.role_id, u.is_owner,
               u.name, u.contact_number, 
               b.business_name, br.branch_name, r.name
          INTO p_user_id, p_business_id, p_branch_id, p_role_id, p_is_owner,
               p_user_name, p_contact_number, 
               p_business_name, p_branch_name, p_role_name
          FROM master_user u
          JOIN master_business b ON u.business_id = b.business_id
          LEFT JOIN master_branch br ON u.branch_id = br.branch_id
          JOIN master_role_type r ON u.role_id = r.master_role_type_id
         WHERE u.email = p_email
           AND u.is_deleted = 0
           AND u.is_active = TRUE
           AND b.is_deleted = 0
           AND b.is_active = TRUE
         LIMIT 1;

        IF p_user_id IS NULL THEN
            SET p_error_message = 'User not found or inactive';
            LEAVE main_block;
        END IF;

        -- Delete existing sessions for this user (if any)
        DELETE FROM master_user_session
         WHERE user_id = p_user_id;

        -- Delete OTP from master_otp after successful login
        DELETE FROM master_otp
         WHERE id = v_otp_record_id;

        COMMIT;
        SET p_error_message = 'Login successful';

    END; /* end main_block */
END;