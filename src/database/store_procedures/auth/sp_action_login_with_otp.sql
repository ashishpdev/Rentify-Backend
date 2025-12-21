DROP PROCEDURE IF EXISTS sp_action_login_with_otp;

CREATE PROCEDURE sp_action_login_with_otp(
    IN  p_email           VARCHAR(255),
    IN  p_otp_code_hash   VARCHAR(255),
    IN  p_ip_address      VARCHAR(45),
    
    OUT p_user_id         INT,
    OUT p_business_id     INT,
    OUT p_branch_id       INT,
    OUT p_role_id         TINYINT,
    OUT p_contact_number  VARCHAR(20),
    OUT p_user_name       VARCHAR(200),
    OUT p_business_name   VARCHAR(200),
    OUT p_branch_name     VARCHAR(200),
    OUT p_role_name       VARCHAR(100),
    OUT p_is_owner        BOOLEAN,
    OUT p_error_code      VARCHAR(50),
    OUT p_error_message   VARCHAR(500)
)
proc_label: BEGIN

    DECLARE v_otp_record_id      CHAR(36) DEFAULT NULL;
    DECLARE v_otp_status_id      INT DEFAULT NULL;
    DECLARE v_expires_at         DATETIME(6) DEFAULT NULL;
    DECLARE v_verified_status_id INT DEFAULT NULL;
    DECLARE v_attempts           INT DEFAULT 0;
    DECLARE v_max_attempts       INT DEFAULT 3;
    DECLARE v_stored_otp_hash    VARCHAR(255) DEFAULT NULL;
    DECLARE v_otp_type_login     INT DEFAULT 1; 
    DECLARE v_status_code_ver    VARCHAR(50) DEFAULT 'VERIFIED';
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_error_code = 'ERR_FOREIGN_KEY_VIOLATION';
        SET p_error_message = 'Database integrity error.';
    END;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_error_code = 'ERR_DUPLICATE_KEY';
        SET p_error_message = 'Duplicate entry detected.';
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
        VALUES ('sp_action_login_with_otp', CONCAT('email=', LEFT(p_email, 100)), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'An unexpected error occurred.';
    END;

    SET p_user_id = NULL;
    SET p_business_id = NULL;
    SET p_branch_id = NULL;
    SET p_role_id = NULL;
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

    START TRANSACTION;

        SELECT master_otp_status_id
        INTO v_verified_status_id
        FROM master_otp_status
        WHERE code = v_status_code_ver
        LIMIT 1;

        SELECT id, otp_status_id, expires_at, attempts, max_attempts, otp_code_hash
        INTO v_otp_record_id, v_otp_status_id, v_expires_at, v_attempts, v_max_attempts, v_stored_otp_hash
        FROM master_otp
        WHERE target_identifier = p_email
          AND otp_type_id = v_otp_type_login
        ORDER BY created_at DESC
        LIMIT 1
        FOR UPDATE;

        IF v_otp_record_id IS NULL THEN
            ROLLBACK;
            SET p_error_code = 'ERR_OTP_NOT_FOUND';
            SET p_error_message = 'No OTP found for this email.';
            LEAVE proc_label;
        END IF;

        IF v_attempts >= v_max_attempts THEN
            ROLLBACK;
            SET p_error_code = 'ERR_MAX_ATTEMPTS';
            SET p_error_message = 'Maximum OTP attempts exceeded.';
            LEAVE proc_label;
        END IF;

        UPDATE master_otp
        SET attempts = attempts + 1, updated_at = UTC_TIMESTAMP(6)
        WHERE id = v_otp_record_id;

        IF UTC_TIMESTAMP() > v_expires_at THEN
            ROLLBACK;
            SET p_error_code = 'ERR_OTP_EXPIRED';
            SET p_error_message = 'OTP has expired.';
            LEAVE proc_label;
        END IF;

        IF v_stored_otp_hash != p_otp_code_hash THEN
            COMMIT;
            SET p_error_code = 'ERR_INVALID_OTP';
            SET p_error_message = 'Invalid OTP code.';
            LEAVE proc_label;
        END IF;

        SELECT
            u.master_user_id, u.business_id, u.branch_id, u.role_id, u.is_owner,
            u.name, u.contact_number, b.business_name, br.branch_name, r.name
        INTO
            p_user_id, p_business_id, p_branch_id, p_role_id, p_is_owner,
            p_user_name, p_contact_number, p_business_name, p_branch_name, p_role_name
        FROM master_user u
        JOIN master_business b ON u.business_id = b.business_id
        LEFT JOIN master_branch br ON u.branch_id = br.branch_id
        JOIN master_role_type r ON u.role_id = r.master_role_type_id
        WHERE u.email = p_email AND u.deleted_at IS NULL AND u.is_active = TRUE
          AND b.is_active = TRUE
        LIMIT 1;

        IF p_user_id IS NULL THEN
            ROLLBACK;
            SET p_error_code = 'ERR_USER_NOT_FOUND';
            SET p_error_message = 'User not found or inactive.';
            LEAVE proc_label;
        END IF;

        IF v_otp_status_id != v_verified_status_id THEN
            UPDATE master_otp
            SET verified_at = UTC_TIMESTAMP(6), otp_status_id = v_verified_status_id, updated_at = UTC_TIMESTAMP(6)
            WHERE id = v_otp_record_id;
        END IF;

        DELETE FROM master_user_session WHERE user_id = p_user_id;
        DELETE FROM master_otp WHERE id = v_otp_record_id;

        UPDATE master_user
        SET last_login_at = UTC_TIMESTAMP(6)
        WHERE master_user_id = p_user_id;

    COMMIT;
    
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Login successful.';

END;

