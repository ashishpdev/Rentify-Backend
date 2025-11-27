DROP PROCEDURE IF EXISTS sp_login_with_otp;
DELIMITER $$

CREATE PROCEDURE sp_login_with_otp(
    IN p_email VARCHAR(255),
    IN p_ip_address VARCHAR(255),
    IN p_user_agent VARCHAR(255),
    OUT p_user_id INT,
    OUT p_business_id INT,
    OUT p_branch_id INT,
    OUT p_role_id INT,
    OUT p_is_owner BOOLEAN,
    OUT p_user_name VARCHAR(255),
    OUT p_contact_number VARCHAR(50),
    OUT p_business_name VARCHAR(255),
    OUT p_session_token VARCHAR(255),
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_ok INT DEFAULT 1;
    DECLARE v_otp_record_id CHAR(36) DEFAULT NULL;
    DECLARE v_stored_hash VARCHAR(255) DEFAULT NULL;
    DECLARE v_attempts INT DEFAULT 0;
    DECLARE v_max_attempts INT DEFAULT 3;
    DECLARE v_verified_status_id INT DEFAULT NULL;
    DECLARE v_failed_status_id INT DEFAULT NULL;
    DECLARE v_verified_otp_status_id INT DEFAULT NULL;
    DECLARE v_login_otp_type_id INT DEFAULT NULL;
    DECLARE v_temporary_user_flag BOOLEAN DEFAULT FALSE;

    -- Error handler for rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_error_message = 'An error occurred. Transaction rolled back.';
        SET v_ok = 0;
    END;

    START TRANSACTION;

    SET p_user_id = NULL;
    SET p_business_id = NULL;
    SET p_branch_id = NULL;
    SET p_role_id = NULL;
    SET p_is_owner = FALSE;
    SET p_user_name = NULL;
    SET p_contact_number = NULL;
    SET p_business_name = NULL;
    SET p_session_token = NULL;
    SET p_error_message = NULL;

    -- Get VERIFIED and FAILED status IDs
    SELECT master_otp_status_id
      INTO v_verified_status_id
      FROM master_otp_status
     WHERE code = 'VERIFIED' AND is_deleted = 0
     LIMIT 1;

    SELECT master_otp_status_id
      INTO v_failed_status_id
      FROM master_otp_status
     WHERE code = 'FAILED' AND is_deleted = 0
     LIMIT 1;

    -- Get LOGIN OTP type ID (if used elsewhere)
    SELECT master_otp_type_id
      INTO v_login_otp_type_id
      FROM master_otp_type
     WHERE code = 'LOGIN' AND is_deleted = 0
     LIMIT 1;

    IF v_verified_status_id IS NULL OR v_failed_status_id IS NULL THEN
        SET p_error_message = 'OTP status configuration error';
        SET v_ok = 0;
    END IF;

    -- Verify OTP (check if already verified)
    IF v_ok = 1 THEN
        SELECT id, otp_code_hash, attempts
          INTO v_otp_record_id, v_stored_hash, v_attempts
          FROM master_otp
         WHERE target_identifier = p_email
           AND otp_status_id = v_verified_status_id
           AND expires_at > NOW()
         ORDER BY created_at DESC
         LIMIT 1;

        IF v_otp_record_id IS NULL THEN
            SET p_error_message = 'OTP not verified or has expired';
            SET v_ok = 0;
        ELSE
            -- OTP is verified, proceed
            SET v_verified_otp_status_id = v_verified_status_id;
        END IF;
    END IF;

    -- Fetch user details from master_user
    IF v_ok = 1 THEN
        SELECT u.master_user_id, u.business_id, u.branch_id, u.role_id, u.is_owner,
               u.name, u.contact_number, b.business_name
          INTO p_user_id, p_business_id, p_branch_id, p_role_id, p_is_owner,
               p_user_name, p_contact_number, p_business_name
          FROM master_user u
          JOIN master_business b ON u.business_id = b.business_id
         WHERE u.email = p_email
           AND u.is_deleted = 0
           AND u.is_active = TRUE
           AND b.is_deleted = 0
           AND b.is_active = TRUE
         LIMIT 1;

        -- Generate session token
        SET p_session_token = UUID();

        -- Insert session record (remove business_id, use id, created_at, last_active)
        INSERT INTO master_user_session (
            id, user_id, session_token, ip_address,
            user_agent, created_at, last_active, is_active
        ) VALUES (
            UUID(), p_user_id, p_session_token, p_ip_address,
            p_user_agent, NOW(), NOW(), 1
        );

        -- Delete OTP from master_otp after successful login
        DELETE FROM master_otp
         WHERE id = v_otp_record_id;

        IF p_user_id IS NULL THEN
            SET p_error_message = 'User not found or inactive';
            SET v_ok = 0;
        ELSE
            SET p_error_message = 'Login successful';
        END IF;
    END IF;

    -- Commit or rollback
    IF v_ok = 1 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;
END $$
DELIMITER ;
