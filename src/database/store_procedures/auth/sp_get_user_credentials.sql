DROP PROCEDURE IF EXISTS sp_get_user_credentials;
CREATE PROCEDURE sp_get_user_credentials(
    IN  p_email VARCHAR(255),
    
    OUT p_user_id INT,
    OUT p_business_id INT,
    OUT p_branch_id INT,
    OUT p_role_id TINYINT,
    OUT p_hash_password VARCHAR(255),
    OUT p_contact_number VARCHAR(20),
    OUT p_user_name VARCHAR(200),
    OUT p_locked_until TIMESTAMP(6),
    OUT p_user_active BOOLEAN,
    OUT p_is_owner BOOLEAN,
    OUT p_business_name VARCHAR(200),
    OUT p_business_active BOOLEAN,
    OUT p_branch_name VARCHAR(200),
    OUT p_role_name VARCHAR(100),
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_label: BEGIN
    
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
        INSERT INTO proc_error_log(proc_name, proc_args, mysql_errno, sql_state, error_message)
        VALUES ('sp_get_user_credentials', CONCAT('email=', LEFT(p_email, 100)), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'Failed to retrieve user credentials.';
    END;

    SET p_user_id = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_email IS NULL OR p_email = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Email is required.';
        LEAVE proc_label;
    END IF;

    SELECT 
        u.master_user_id,
        u.business_id,
        u.branch_id,
        u.role_id,
        u.hash_password,
        u.contact_number,
        u.name,
        u.locked_until,
        u.is_active,
        u.is_owner,
        b.business_name,
        b.is_active,
        br.branch_name,
        r.name
    INTO
        p_user_id,
        p_business_id,
        p_branch_id,
        p_role_id,
        p_hash_password,
        p_contact_number,
        p_user_name,
        p_locked_until,
        p_user_active,
        p_is_owner,
        p_business_name,
        p_business_active,
        p_branch_name,
        p_role_name
    FROM master_user u
    JOIN master_business b ON u.business_id = b.business_id
    LEFT JOIN master_branch br ON u.branch_id = br.branch_id
    JOIN master_role_type r ON u.role_id = r.master_role_type_id
    WHERE u.email = p_email AND u.deleted_at IS NULL
    LIMIT 1;

    IF p_user_id IS NULL THEN
        SET p_error_code = 'ERR_USER_NOT_FOUND';
        SET p_error_message = 'User not found.';
        LEAVE proc_label;
    END IF;

    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'User credentials retrieved successfully.';

END;