DROP PROCEDURE IF EXISTS sp_action_login_with_password;

CREATE PROCEDURE sp_action_login_with_password(
    IN  p_email           VARCHAR(255),
    IN  p_password_hash   VARCHAR(255),
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

    DECLARE v_stored_password_hash  VARCHAR(255) DEFAULT NULL;
    DECLARE v_user_locked_until     TIMESTAMP(6) DEFAULT NULL;
    DECLARE v_user_is_active        BOOLEAN DEFAULT FALSE;
    DECLARE v_business_is_active    BOOLEAN DEFAULT FALSE;
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
        VALUES ('sp_action_login_with_password', CONCAT('email=', LEFT(p_email, 100)), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
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

    IF p_password_hash IS NULL OR p_password_hash = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Password is required.';
        LEAVE proc_label;
    END IF;

    START TRANSACTION;

        SELECT
            u.master_user_id, u.business_id, u.branch_id, u.role_id, u.is_owner,
            u.name, u.contact_number, u.hash_password, u.locked_until, u.is_active,
            b.business_name, b.is_active, br.branch_name, r.name
        INTO
            p_user_id, p_business_id, p_branch_id, p_role_id, p_is_owner,
            p_user_name, p_contact_number, v_stored_password_hash, v_user_locked_until, v_user_is_active,
            p_business_name, v_business_is_active, p_branch_name, p_role_name
        FROM master_user u
        JOIN master_business b ON u.business_id = b.business_id
        LEFT JOIN master_branch br ON u.branch_id = br.branch_id
        JOIN master_role_type r ON u.role_id = r.master_role_type_id
        WHERE u.email = p_email AND u.deleted_at IS NULL
        LIMIT 1;

        IF p_user_id IS NULL THEN
            ROLLBACK;
            SET p_error_code = 'ERR_INVALID_CREDENTIALS';
            SET p_error_message = 'Invalid email or password.';
            LEAVE proc_label;
        END IF;

        IF v_user_locked_until IS NOT NULL AND v_user_locked_until > UTC_TIMESTAMP(6) THEN
            ROLLBACK;
            SET p_error_code = 'ERR_ACCOUNT_LOCKED';
            SET p_error_message = CONCAT('Account locked until ', DATE_FORMAT(v_user_locked_until, '%Y-%m-%d %H:%i:%s'), ' UTC.');
            LEAVE proc_label;
        END IF;

        IF NOT v_user_is_active THEN
            ROLLBACK;
            SET p_error_code = 'ERR_ACCOUNT_INACTIVE';
            SET p_error_message = 'Account is inactive.';
            LEAVE proc_label;
        END IF;

        IF NOT v_business_is_active THEN
            ROLLBACK;
            SET p_error_code = 'ERR_BUSINESS_INACTIVE';
            SET p_error_message = 'Business account is inactive.';
            LEAVE proc_label;
        END IF;

        IF v_stored_password_hash != p_password_hash THEN
            ROLLBACK;
            SET p_error_code = 'ERR_INVALID_CREDENTIALS';
            SET p_error_message = 'Invalid email or password.';
            LEAVE proc_label;
        END IF;

        UPDATE master_user
        SET last_login_at = UTC_TIMESTAMP(6), locked_until = NULL
        WHERE master_user_id = p_user_id;

    COMMIT;
    
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Login successful.';

END;

