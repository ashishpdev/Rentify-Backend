DROP PROCEDURE IF EXISTS sp_manage_session;
CREATE PROCEDURE sp_manage_session(
    IN p_action INT,
    IN p_user_id INT,
    IN p_session_token_hash CHAR(64),
    IN p_device_id VARCHAR(255),
    IN p_device_name VARCHAR(255),
    IN p_device_type_id TINYINT,
    IN p_ip_address VARCHAR(45),
    IN p_expiry_at DATETIME(6),
    
    OUT p_success BOOLEAN,
    OUT p_session_id CHAR(36),
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_label: BEGIN

    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;
    DECLARE v_old_token CHAR(64);

    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_FOREIGN_KEY_VIOLATION';
        SET p_error_message = 'Invalid user or device type reference.';
    END;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_DUPLICATE_KEY';
        SET p_error_message = 'Session already exists.';
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
        VALUES ('sp_manage_session', CONCAT('action=', p_action, ', user_id=', p_user_id), v_errno, v_sql_state, LEFT(v_error_msg, 2000));
        SET p_success = FALSE;
        SET p_error_code = 'ERR_SQL_EXCEPTION';
        SET p_error_message = 'Session operation failed.';
    END;

    SET p_success = FALSE;
    SET p_session_id = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_action = 1 THEN
        -- Action 1: Create new session
        IF p_user_id IS NULL OR p_user_id <= 0 THEN
            SET p_error_code = 'ERR_INVALID_INPUT';
            SET p_error_message = 'Invalid user ID.';
            LEAVE proc_label;
        END IF;

        IF p_session_token_hash IS NULL OR p_session_token_hash = '' THEN
            SET p_error_code = 'ERR_INVALID_INPUT';
            SET p_error_message = 'Session token is required.';
            LEAVE proc_label;
        END IF;

        IF p_device_type_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_INPUT';
            SET p_error_message = 'Device type is required.';
            LEAVE proc_label;
        END IF;

        START TRANSACTION;

            SET p_session_id = UUID();

            INSERT INTO master_user_session (
                id, user_id, session_token_hash, device_id, device_name,
                device_type_id, ip_address, expiry_at, last_active, is_active
            ) VALUES (
                p_session_id, p_user_id, p_session_token_hash, p_device_id, p_device_name,
                p_device_type_id, p_ip_address, p_expiry_at, UTC_TIMESTAMP(6), TRUE
            );

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Session created successfully.';

    ELSEIF p_action = 2 THEN
        -- Action 2: Extend/Rotate session (update token and expiry)
        START TRANSACTION;

            -- Find the most recent active session for this user
            SELECT id, session_token_hash
            INTO p_session_id, v_old_token
            FROM master_user_session
            WHERE user_id = p_user_id
              AND is_active = TRUE
              AND expiry_at > UTC_TIMESTAMP(6)
            ORDER BY last_active DESC
            LIMIT 1;

            IF p_session_id IS NULL THEN
                SET p_error_code = 'ERR_SESSION_NOT_FOUND';
                SET p_error_message = 'No active session found for this user.';
                ROLLBACK;
                LEAVE proc_label;
            END IF;

            -- Update the session with new token and expiry
            UPDATE master_user_session
            SET session_token_hash = p_session_token_hash,
                expiry_at = p_expiry_at,
                last_active = UTC_TIMESTAMP(6)
            WHERE id = p_session_id;

            IF ROW_COUNT() > 0 THEN
                SET p_success = TRUE;
                SET p_error_code = 'SUCCESS';
                SET p_error_message = 'Session extended successfully.';
            ELSE
                SET p_error_code = 'ERR_UPDATE_FAILED';
                SET p_error_message = 'Failed to update session.';
            END IF;

        COMMIT;

    ELSEIF p_action = 3 THEN
        -- Action 3: Delete session(s)
        START TRANSACTION;

            DELETE FROM master_user_session
            WHERE user_id = p_user_id
              AND (p_session_token_hash IS NULL OR session_token_hash = p_session_token_hash);

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Session(s) deleted successfully.';

    ELSEIF p_action = 4 THEN
        -- Action 4: Get active session
        SELECT id, session_token_hash
        INTO p_session_id, p_session_token_hash
        FROM master_user_session
        WHERE user_id = p_user_id
          AND is_active = TRUE
          AND expiry_at > UTC_TIMESTAMP(6)
        ORDER BY last_active DESC
        LIMIT 1;

        IF p_session_id IS NOT NULL THEN
            SET p_success = TRUE;
            SET p_error_code = 'SUCCESS';
            SET p_error_message = 'Session retrieved.';
        ELSE
            SET p_error_code = 'ERR_SESSION_NOT_FOUND';
            SET p_error_message = 'No active session found.';
        END IF;

    ELSE
        SET p_error_code = 'ERR_INVALID_ACTION';
        SET p_error_message = 'Invalid action. Use 1=Create, 2=Update, 3=Delete, 4=Get.';
    END IF;

END;

