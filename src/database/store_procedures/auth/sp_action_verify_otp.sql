DROP PROCEDURE IF EXISTS sp_action_verify_otp;

CREATE PROCEDURE sp_action_verify_otp(
    IN  p_target_identifier VARCHAR(255),
    IN  p_otp_code_hash VARCHAR(255),
    IN  p_otp_type_id INT,
    
    OUT p_success BOOLEAN,
    OUT p_otp_id CHAR(36),
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    DECLARE v_otp_id CHAR(36) DEFAULT NULL;
    DECLARE v_expires_at DATETIME(6) DEFAULT NULL;
    DECLARE v_verified_at DATETIME(6) DEFAULT NULL;
    DECLARE v_otp_type_id INT DEFAULT NULL;
    DECLARE v_current_otp_status_id INT DEFAULT NULL;
    DECLARE v_pending_status_id INT DEFAULT NULL;
    DECLARE v_verified_status_id INT DEFAULT NULL;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

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
        VALUES ('sp_action_verify_otp', CONCAT('email=', LEFT(p_target_identifier, 100)), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_success = FALSE;
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'OTP verification failed.';
    END;

    SET p_success = FALSE;
    SET p_otp_id = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

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

    SELECT master_otp_status_id INTO v_verified_status_id
    FROM master_otp_status
    WHERE code = 'VERIFIED'
    LIMIT 1;

    SELECT id, expires_at, verified_at, otp_status_id
    INTO v_otp_id, v_expires_at, v_verified_at, v_current_otp_status_id
    FROM master_otp
    WHERE target_identifier = p_target_identifier
      AND otp_code_hash = p_otp_code_hash
      AND otp_type_id = p_otp_type_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF v_otp_id IS NULL THEN
        SET p_error_code = 'ERR_INVALID_OTP';
        SET p_error_message = 'Invalid OTP.';
        LEAVE proc_body;
    END IF;

    IF v_verified_at IS NOT NULL OR v_current_otp_status_id = v_verified_status_id THEN
        SET p_error_code = 'ERR_OTP_USED';
        SET p_error_message = 'OTP already used.';
        LEAVE proc_body;
    END IF;

    IF UTC_TIMESTAMP(6) > v_expires_at THEN
        SET p_error_code = 'ERR_OTP_EXPIRED';
        SET p_error_message = 'OTP has expired.';
        LEAVE proc_body;
    END IF;

    IF v_current_otp_status_id != v_pending_status_id THEN
        SET p_error_code = 'ERR_INVALID_STATE';
        SET p_error_message = 'OTP is not in valid state.';
        LEAVE proc_body;
    END IF;

    START TRANSACTION;

        UPDATE master_otp
        SET verified_at = UTC_TIMESTAMP(6),
            otp_status_id = v_verified_status_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE id = v_otp_id;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_UPDATE_FAILED';
            SET p_error_message = 'Failed to verify OTP.';
            LEAVE proc_body;
        END IF;

    COMMIT;

    SET p_success = TRUE;
    SET p_otp_id = v_otp_id;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'OTP verified successfully.';

END;