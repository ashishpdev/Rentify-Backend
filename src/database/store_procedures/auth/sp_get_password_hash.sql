DROP PROCEDURE IF EXISTS sp_get_password_hash;
CREATE PROCEDURE sp_get_password_hash(
    IN  p_user_id INT,
    
    OUT p_hash_password VARCHAR(255),
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
        VALUES ('sp_get_password_hash', CONCAT('user_id=', p_user_id), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'Failed to retrieve password hash.';
    END;

    SET p_hash_password = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_user_id IS NULL OR p_user_id <= 0 THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Invalid user ID.';
        LEAVE proc_label;
    END IF;

    SELECT hash_password, is_active
    INTO p_hash_password, p_is_active
    FROM master_user
    WHERE master_user_id = p_user_id AND deleted_at IS NULL
    LIMIT 1;

    IF p_hash_password IS NULL THEN
        SET p_error_code = 'ERR_USER_NOT_FOUND';
        SET p_error_message = 'User not found.';
        LEAVE proc_label;
    END IF;

    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Password hash retrieved successfully.';

END;