DROP PROCEDURE IF EXISTS sp_log_proc_error;
CREATE PROCEDURE sp_log_proc_error(
    IN p_proc_name VARCHAR(255),
    IN p_proc_args TEXT,
    IN p_mysql_errno INT,
    IN p_sql_state CHAR(5),
    IN p_error_message TEXT
)
proc_body: BEGIN
    DECLARE v_has_mysql_errno INT DEFAULT 0;
    DECLARE v_has_sql_state INT DEFAULT 0;
    DECLARE v_has_created_at INT DEFAULT 0;

    -- Check which columns exist in proc_error_log in current DB
    SELECT COUNT(*) INTO v_has_mysql_errno
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'proc_error_log'
      AND COLUMN_NAME = 'mysql_errno';

    SELECT COUNT(*) INTO v_has_sql_state
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'proc_error_log'
      AND COLUMN_NAME = 'sql_state';

    SELECT COUNT(*) INTO v_has_created_at
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'proc_error_log'
      AND COLUMN_NAME = 'created_at';

    IF v_has_mysql_errno = 1 AND v_has_sql_state = 1 THEN
        -- table has both diagnostic columns
        IF v_has_created_at = 1 THEN
            INSERT INTO proc_error_log(proc_name, proc_args, mysql_errno, sql_state, error_message, created_at)
            VALUES(p_proc_name, p_proc_args, p_mysql_errno, p_sql_state, LEFT(p_error_message,2000), UTC_TIMESTAMP(6));
        ELSE
            INSERT INTO proc_error_log(proc_name, proc_args, mysql_errno, sql_state, error_message)
            VALUES(p_proc_name, p_proc_args, p_mysql_errno, p_sql_state, LEFT(p_error_message,2000));
        END IF;
    ELSEIF v_has_mysql_errno = 1 AND v_has_sql_state = 0 THEN
        -- only mysql_errno present
        IF v_has_created_at = 1 THEN
            INSERT INTO proc_error_log(proc_name, proc_args, mysql_errno, error_message, created_at)
            VALUES(p_proc_name, p_proc_args, p_mysql_errno, LEFT(p_error_message,2000), UTC_TIMESTAMP(6));
        ELSE
            INSERT INTO proc_error_log(proc_name, proc_args, mysql_errno, error_message)
            VALUES(p_proc_name, p_proc_args, p_mysql_errno, LEFT(p_error_message,2000));
        END IF;
    ELSE
        -- fallback: insert minimal columns (proc_name, proc_args, error_message)
        IF v_has_created_at = 1 THEN
            INSERT INTO proc_error_log(proc_name, proc_args, error_message, created_at)
            VALUES(p_proc_name, p_proc_args, LEFT(p_error_message,2000), UTC_TIMESTAMP(6));
        ELSE
            INSERT INTO proc_error_log(proc_name, proc_args, error_message)
            VALUES(p_proc_name, p_proc_args, LEFT(p_error_message,2000));
        END IF;
    END IF;
END;