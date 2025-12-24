DROP PROCEDURE IF EXISTS sp_action_reset_password;

CREATE PROCEDURE sp_action_reset_password(
    IN  p_email               VARCHAR(255),
    IN  p_otp_code_hash       VARCHAR(255),
    IN  p_new_password_hash   VARCHAR(255),
    IN  p_updated_by          VARCHAR(100),
    
    OUT p_success             BOOLEAN,
    OUT p_error_code          VARCHAR(50),
    OUT p_error_message       VARCHAR(500)
)
proc_label: BEGIN

    DECLARE v_user_id INT DEFAULT NULL;
    DECLARE v_otp_valid BOOLEAN DEFAULT FALSE;
    DECLARE v_otp_type_reset INT DEFAULT 3;
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
        VALUES ('sp_action_reset_password', CONCAT('email=', LEFT(p_email, 100)), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_success = FALSE;
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'Password reset failed.';
    END;

    SET p_success = FALSE;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_email IS NULL OR p_email = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Email is required.';
        LEAVE proc_label;
    END IF;

    IF p_otp_code_hash IS NULL OR p_otp_code_hash = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'OTP is required.';
        LEAVE proc_label;
    END IF;

    IF p_new_password_hash IS NULL OR p_new_password_hash = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'New password is required.';
        LEAVE proc_label;
    END IF;

    SELECT master_user_id INTO v_user_id
    FROM master_user
    WHERE email = p_email AND deleted_at IS NULL AND is_active = TRUE
    LIMIT 1;

    IF v_user_id IS NULL THEN
        SET p_error_code = 'ERR_USER_NOT_FOUND';
        SET p_error_message = 'User not found or inactive.';
        LEAVE proc_label;
    END IF;

    SELECT COUNT(*) > 0 INTO v_otp_valid
    FROM master_otp
    WHERE target_identifier = p_email
      AND otp_code_hash = p_otp_code_hash
      AND otp_type_id = v_otp_type_reset
      AND expires_at > UTC_TIMESTAMP(6)
      AND verified_at IS NULL
    LIMIT 1;

    IF NOT v_otp_valid THEN
        SET p_error_code = 'ERR_INVALID_OTP';
        SET p_error_message = 'Invalid or expired OTP.';
        LEAVE proc_label;
    END IF;

    START TRANSACTION;

        UPDATE master_user
        SET hash_password = p_new_password_hash,
            updated_by = p_updated_by,
            updated_at = UTC_TIMESTAMP(6),
            locked_until = NULL
        WHERE master_user_id = v_user_id;

        UPDATE master_otp
        SET verified_at = UTC_TIMESTAMP(6),
            updated_at = UTC_TIMESTAMP(6)
        WHERE target_identifier = p_email
          AND otp_code_hash = p_otp_code_hash
          AND otp_type_id = v_otp_type_reset;

        DELETE FROM master_user_session WHERE user_id = v_user_id;

    COMMIT;

    SET p_success = TRUE;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Password reset successfully. Please login with new password.';

END;

