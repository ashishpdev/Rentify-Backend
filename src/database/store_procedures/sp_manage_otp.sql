DROP PROCEDURE IF EXISTS sp_manage_otp;

CREATE PROCEDURE sp_manage_otp(
    IN  p_action INT,                    -- 1=Create, 2=Get, 3=Delete, 4=Resend
    IN  p_target_identifier VARCHAR(255),
    IN  p_otp_code_hash VARCHAR(255),
    IN  p_otp_type_id INT,
    IN  p_expiry_minutes INT,
    IN  p_ip_address VARCHAR(100),
    IN  p_created_by VARCHAR(255),
    OUT p_success BOOLEAN,
    OUT p_id CHAR(36),
    OUT p_expires_at DATETIME(6),
    OUT p_otp_code_hash_out VARCHAR(255),   -- NEW OUT parameter to return the hash on GET
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN
    DECLARE v_otp_type_id INT;
    DECLARE v_user_exists INT;
    DECLARE v_email_exists INT;
    DECLARE v_default_expiry INT DEFAULT 10;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'Database error during OTP operation';
    END;

    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_expires_at = NULL;
    SET p_otp_code_hash_out = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- ==================== CREATE OTP ====================
    IF p_action = 1 THEN
        START TRANSACTION;

        -- Input validation
        IF p_target_identifier IS NULL OR p_target_identifier = '' THEN
            SET p_error_code = 'ERR_INVALID_INPUT';
            SET p_error_message = 'Target identifier is required';
            ROLLBACK;
            LEAVE proc_body;
        END IF;

        IF p_otp_code_hash IS NULL OR p_otp_code_hash = '' THEN
            SET p_error_code = 'ERR_INVALID_INPUT';
            SET p_error_message = 'OTP code is required';
            ROLLBACK;
            LEAVE proc_body;
        END IF;

        -- Validate OTP type
        SELECT master_otp_type_id INTO v_otp_type_id
        FROM master_otp_type
        WHERE master_otp_type_id = p_otp_type_id
          AND is_deleted = 0
          AND is_active = TRUE
        LIMIT 1;

        IF v_otp_type_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_TYPE';
            SET p_error_message = 'Invalid OTP type';
            ROLLBACK;
            LEAVE proc_body;
        END IF;

        -- Type-specific validations
        IF p_otp_type_id = 1 THEN
            SELECT COUNT(*) INTO v_user_exists
            FROM master_user
            WHERE email = p_target_identifier
              AND is_deleted = 0
              AND is_active = TRUE;

            IF v_user_exists = 0 THEN
                SET p_error_code = 'ERR_USER_NOT_FOUND';
                SET p_error_message = 'Email not registered';
                ROLLBACK;
                LEAVE proc_body;
            END IF;
        END IF;

        IF p_otp_type_id = 2 THEN
            SELECT COUNT(*) INTO v_email_exists
            FROM master_user
            WHERE email = p_target_identifier AND is_deleted = 0 AND is_active = TRUE;

            IF v_email_exists > 0 THEN
                SET p_error_code = 'ERR_EMAIL_EXISTS';
                SET p_error_message = 'Email already registered';
                ROLLBACK;
                LEAVE proc_body;
            END IF;
        END IF;

        -- Delete existing OTPs for this identifier and type
        DELETE FROM master_otp
        WHERE target_identifier = p_target_identifier
          AND otp_type_id = p_otp_type_id;

        -- Create new OTP
        SET p_id = UUID();
        SET p_expires_at = DATE_ADD(UTC_TIMESTAMP(),
                                    INTERVAL COALESCE(p_expiry_minutes, v_default_expiry) MINUTE);

        INSERT INTO master_otp (
            id, target_identifier, otp_code_hash, otp_type_id,
            expires_at, ip_address, created_by, created_at
        ) VALUES (
            p_id, p_target_identifier, p_otp_code_hash, p_otp_type_id,
            p_expires_at, p_ip_address, p_created_by, UTC_TIMESTAMP(6)
        );

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'OTP created successfully';
        LEAVE proc_body;
    END IF;

    -- ==================== GET OTP ====================
    IF p_action = 2 THEN
        SELECT id, expires_at, otp_code_hash
        INTO p_id, p_expires_at, p_otp_code_hash_out
        FROM master_otp
        WHERE target_identifier = p_target_identifier
          AND otp_type_id = p_otp_type_id
          AND is_deleted = 0
          AND is_active = TRUE
        ORDER BY created_at DESC
        LIMIT 1;

        IF p_id IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'No OTP found';
            LEAVE proc_body;
        END IF;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'OTP retrieved successfully';
        LEAVE proc_body;
    END IF;

    -- ==================== DELETE OTP ====================
    IF p_action = 3 THEN
        START TRANSACTION;

        DELETE FROM master_otp
        WHERE (p_target_identifier IS NOT NULL AND target_identifier = p_target_identifier);

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'OTP deleted successfully';
        LEAVE proc_body;
    END IF;

    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action specified';


END proc_body;