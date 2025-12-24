DROP PROCEDURE IF EXISTS sp_get_user_by_email;
CREATE PROCEDURE sp_get_user_by_email(
    IN  p_email VARCHAR(255),
    
    OUT p_user_id INT,
    OUT p_is_active BOOLEAN,
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
        VALUES ('sp_get_user_by_email', CONCAT('email=', LEFT(p_email, 100)), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'Failed to retrieve user.';
    END;

    SET p_user_id = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_email IS NULL OR p_email = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Email is required.';
        LEAVE proc_label;
    END IF;

    SELECT master_user_id, is_active
    INTO p_user_id, p_is_active
    FROM master_user
    WHERE email = p_email AND deleted_at IS NULL
    LIMIT 1;

    IF p_user_id IS NULL THEN
        SET p_error_code = 'ERR_USER_NOT_FOUND';
        SET p_error_message = 'User not found.';
        LEAVE proc_label;
    END IF;

    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'User retrieved successfully.';

END;