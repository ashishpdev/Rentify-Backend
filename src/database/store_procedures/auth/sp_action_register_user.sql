DROP PROCEDURE IF EXISTS sp_action_register_user;

CREATE PROCEDURE sp_action_register_user(
    IN  p_business_id     INT,
    IN  p_branch_id       INT,
    IN  p_role_id         TINYINT,
    IN  p_name            VARCHAR(200),
    IN  p_email           VARCHAR(255),
    IN  p_password_hash   VARCHAR(255),
    IN  p_contact_number  VARCHAR(20),
    IN  p_employee_code   VARCHAR(50),
    IN  p_base_salary     DECIMAL(12,2),
    IN  p_joining_date    DATE,
    IN  p_created_by      VARCHAR(100),
    IN  p_ip_address      VARCHAR(45),
    
    OUT p_user_id         INT,
    OUT p_error_code      VARCHAR(50),
    OUT p_error_message   VARCHAR(500)
)
proc_label: BEGIN

    DECLARE v_email_exists INT DEFAULT 0;
    DECLARE v_business_active BOOLEAN DEFAULT FALSE;
    DECLARE v_role_exists INT DEFAULT 0;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_error_code = 'ERR_FOREIGN_KEY_VIOLATION';
        SET p_error_message = 'Invalid business, branch, or role reference.';
    END;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_error_code = 'ERR_DUPLICATE_EMAIL';
        SET p_error_message = 'Email already registered.';
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
        VALUES ('sp_action_register_user', CONCAT('email=', LEFT(p_email, 100)), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'Registration failed due to unexpected error.';
    END;

    SET p_user_id = NULL;
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

    IF p_name IS NULL OR p_name = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Name is required.';
        LEAVE proc_label;
    END IF;

    IF p_contact_number IS NULL OR p_contact_number = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Contact number is required.';
        LEAVE proc_label;
    END IF;

    SELECT COUNT(*) INTO v_email_exists
    FROM master_user
    WHERE email = p_email AND business_id = p_business_id AND deleted_at IS NULL;

    IF v_email_exists > 0 THEN
        SET p_error_code = 'ERR_EMAIL_EXISTS';
        SET p_error_message = 'Email already registered in this business.';
        LEAVE proc_label;
    END IF;

    SELECT is_active INTO v_business_active
    FROM master_business
    WHERE business_id = p_business_id;

    IF NOT v_business_active THEN
        SET p_error_code = 'ERR_BUSINESS_INACTIVE';
        SET p_error_message = 'Cannot register user for inactive business.';
        LEAVE proc_label;
    END IF;

    SELECT COUNT(*) INTO v_role_exists
    FROM master_role_type
    WHERE master_role_type_id = p_role_id;

    IF v_role_exists = 0 THEN
        SET p_error_code = 'ERR_INVALID_ROLE';
        SET p_error_message = 'Invalid role specified.';
        LEAVE proc_label;
    END IF;

    START TRANSACTION;

        INSERT INTO master_user (
            business_id, branch_id, role_id, name, email, hash_password,
            contact_number, employee_code, base_salary, joining_date,
            is_owner, created_by, created_at, is_active
        ) VALUES (
            p_business_id, p_branch_id, p_role_id, p_name, p_email, p_password_hash,
            p_contact_number, p_employee_code, p_base_salary, p_joining_date,
            FALSE, p_created_by, UTC_TIMESTAMP(6), TRUE
        );

        SET p_user_id = LAST_INSERT_ID();

    COMMIT;

    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'User registered successfully.';

END;

