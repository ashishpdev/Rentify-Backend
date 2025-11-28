DROP PROCEDURE IF EXISTS sp_session_manage;
CREATE PROCEDURE sp_session_manage(
    IN p_operation INT,
    IN p_user_id INT,
    IN p_session_token VARCHAR(255),
    OUT p_is_success BOOLEAN,
    OUT p_new_expiry_at DATETIME,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_ok INT DEFAULT 1;

    -- Error handler for rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_is_success = FALSE;
        SET p_new_expiry_at = NULL;
        SET p_error_message = 'An error occurred. Transaction rolled back.';
        SET v_ok = 0;
    END;

    START TRANSACTION;

    SET p_is_success = FALSE;
    SET p_new_expiry_at = NULL;
    SET p_error_message = NULL;

    -- Operation 2: Update session expiry by 1 hour
    IF p_operation = 2 THEN
        -- Check if session token is provided
        IF p_session_token IS NULL OR p_session_token = '' THEN
            SET p_error_message = 'Session token is required for update operation';
            SET v_ok = 0;
        END IF;

        IF v_ok = 1 THEN
            -- Update expiry_at to 1 hour from now
            UPDATE master_user_session
             SET expiry_at = DATE_ADD(NOW(), INTERVAL 1 HOUR),
                 updated_at = NOW()
             WHERE session_token = p_session_token AND user_id = p_user_id;

            -- Get the new expiry time
            SELECT expiry_at INTO p_new_expiry_at
             FROM master_user_session
             WHERE session_token = p_session_token AND user_id = p_user_id;

            IF p_new_expiry_at IS NOT NULL THEN
                SET p_is_success = TRUE;
                SET p_error_message = 'Session expiry extended successfully';
            ELSE
                SET p_error_message = 'Session not found or update failed';
                SET v_ok = 0;
            END IF;
        END IF;
    END IF;

    -- Operation 3: Delete session (logout)
    IF p_operation = 3 THEN
        -- Check if user_id is provided
        IF p_user_id IS NULL OR p_user_id <= 0 THEN
            SET p_error_message = 'Invalid user ID';
            SET v_ok = 0;
        END IF;

        IF v_ok = 1 THEN
            DELETE FROM master_user_session
             WHERE user_id = p_user_id;

            SET p_is_success = TRUE;
            SET p_error_message = 'Logout successful';
        END IF;
    END IF;

    -- If operation is not recognized
    IF p_operation NOT IN (2, 3) THEN
        SET p_error_message = 'Invalid operation. Supported operations: 2 (Update), 3 (Delete)';
        SET v_ok = 0;
    END IF;

    -- Commit or rollback
    IF v_ok = 1 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;
END;
