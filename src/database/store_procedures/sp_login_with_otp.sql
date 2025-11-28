DROP PROCEDURE IF EXISTS sp_login_with_otp;
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
    DECLARE v_session_created BOOLEAN DEFAULT FALSE;
    DECLARE v_session_error_message VARCHAR(500);

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

    -- Verify OTP (check if already verified with status_id = 2 which is VERIFIED)
    IF v_ok = 1 THEN
        SELECT id
          INTO v_otp_record_id
          FROM master_otp
         WHERE target_identifier = p_email
           AND otp_status_id = 2
           AND expires_at > NOW()
         ORDER BY created_at DESC
         LIMIT 1;

        IF v_otp_record_id IS NULL THEN
            SET p_error_message = 'OTP not verified or has expired';
            SET v_ok = 0;
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

        IF p_user_id IS NOT NULL THEN
            -- Delete existing sessions for this user (if any) before creating new session
            DELETE FROM master_user_session
             WHERE user_id = p_user_id;

            -- Call sp_session_manage to create a new session (p_action = 1)
            CALL sp_session_manage(
                1,                          -- p_action = 1 (Create session)
                p_user_id,                  -- p_user_id
                NULL,                       -- p_session_token (NULL for create, will be generated)
                p_ip_address,               -- p_ip_address
                p_user_agent,               -- p_user_agent
                v_session_created,          -- OUT p_is_success
                p_session_token,            -- OUT p_session_token
                v_session_error_message     -- OUT p_error_message
            );

            IF v_session_created = TRUE THEN
                -- Delete OTP from master_otp after successful login
                DELETE FROM master_otp
                 WHERE id = v_otp_record_id;

                SET p_error_message = 'Login successful';
            ELSE
                SET p_error_message = CONCAT('Session creation failed: ', v_session_error_message);
                SET v_ok = 0;
            END IF;
        ELSE
            SET p_error_message = 'User not found or inactive';
            SET v_ok = 0;
        END IF;
    END IF;

    -- Commit or rollback
    IF v_ok = 1 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;
END;