DROP PROCEDURE IF EXISTS sp_manage_otp;

CREATE PROCEDURE sp_manage_otp(
    IN  p_action INT,
    IN  p_target_identifier VARCHAR(255),
    IN  p_otp_code_hash VARCHAR(255),
    IN  p_otp_type_id INT,
    IN  p_expiry_minutes INT,
    IN  p_ip_address VARCHAR(45),
    IN  p_created_by VARCHAR(100),
    
    OUT p_success BOOLEAN,
    OUT p_id CHAR(36),
    OUT p_expires_at DATETIME(6),
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    DECLARE v_otp_type_id INT DEFAULT NULL;
    DECLARE v_user_exists INT DEFAULT 0;
    DECLARE v_email_exists INT DEFAULT 0;
    DECLARE v_default_expiry INT DEFAULT 10;
    DECLARE v_pending_status_id TINYINT DEFAULT NULL;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_FOREIGN_KEY_VIOLATION';
        SET p_error_message = 'Invalid OTP type reference.';
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
        VALUES ('sp_manage_otp', CONCAT('action=', p_action, ', email=', LEFT(p_target_identifier, 100)), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_success = FALSE;
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'OTP operation failed.';
    END;

    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_expires_at = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_action = 1 THEN

        IF p_target_identifier IS NULL OR p_target_identifier = '' THEN
            SET p_error_code = 'ERR_INVALID_INPUT';
            SET p_error_message = 'Email/phone is required.';
            LEAVE proc_body;
        END IF;

        IF p_otp_code_hash IS NULL OR p_otp_code_hash = '' THEN
            SET p_error_code = 'ERR_INVALID_INPUT';
            SET p_error_message = 'OTP code is required.';
            LEAVE proc_body;
        END IF;

        SELECT master_otp_type_id INTO v_otp_type_id
        FROM master_otp_type
        WHERE master_otp_type_id = p_otp_type_id
        LIMIT 1;

        IF v_otp_type_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_TYPE';
            SET p_error_message = 'Invalid OTP type.';
            LEAVE proc_body;
        END IF;

        SELECT master_otp_status_id INTO v_pending_status_id
        FROM master_otp_status
        WHERE code = 'PENDING'
        LIMIT 1;

        IF p_otp_type_id IN (1, 3) THEN
            SELECT COUNT(*) INTO v_user_exists
            FROM master_user
            WHERE email = p_target_identifier AND deleted_at IS NULL;

            IF v_user_exists = 0 THEN
                SET p_error_code = 'ERR_USER_NOT_FOUND';
                SET p_error_message = 'Email not registered.';
                LEAVE proc_body;
            END IF;
        END IF;

        IF p_otp_type_id = 2 THEN
            SELECT COUNT(*) INTO v_email_exists
            FROM master_user
            WHERE email = p_target_identifier AND deleted_at IS NULL;

            IF v_email_exists > 0 THEN
                SET p_error_code = 'ERR_EMAIL_EXISTS';
                SET p_error_message = 'Email already registered.';
                LEAVE proc_body;
            END IF;
        END IF;

        START TRANSACTION;

            DELETE FROM master_otp
            WHERE target_identifier = p_target_identifier
              AND otp_type_id = p_otp_type_id;

            SET p_id = UUID();
            SET p_expires_at = DATE_ADD(UTC_TIMESTAMP(6), INTERVAL COALESCE(p_expiry_minutes, v_default_expiry) MINUTE);

            INSERT INTO master_otp (
                id, target_identifier, otp_code_hash, otp_type_id, otp_status_id,
                expires_at, ip_address, created_by, created_at
            ) VALUES (
                p_id, p_target_identifier, p_otp_code_hash, p_otp_type_id, v_pending_status_id,
                p_expires_at, p_ip_address, p_created_by, UTC_TIMESTAMP(6)
            );

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'OTP created successfully.';

    ELSEIF p_action = 2 THEN

        SELECT id, expires_at
        INTO p_id, p_expires_at
        FROM master_otp
        WHERE target_identifier = p_target_identifier
          AND otp_type_id = p_otp_type_id
        ORDER BY created_at DESC
        LIMIT 1;

        IF p_id IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'No OTP found.';
            LEAVE proc_body;
        END IF;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'OTP retrieved.';

    ELSEIF p_action = 3 THEN

        START TRANSACTION;

            DELETE FROM master_otp
            WHERE target_identifier = p_target_identifier;

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'OTP(s) deleted.';

    ELSE
        SET p_error_code = 'ERR_INVALID_ACTION';
        SET p_error_message = 'Invalid action. Use 1=Create, 2=Get, 3=Delete.';
    END IF;

END;