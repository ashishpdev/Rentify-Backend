DROP PROCEDURE IF EXISTS sp_session_manage;
CREATE PROCEDURE sp_session_manage(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete
    IN p_user_id INT,
    IN p_session_token VARCHAR(255),
    IN p_ip_address VARCHAR(255),
    IN p_user_agent VARCHAR(255),
    OUT p_is_success BOOLEAN,
    OUT p_session_token_out VARCHAR(255),
    OUT p_expiry_at DATETIME,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_ok INT DEFAULT 1;
    DECLARE v_new_session_token VARCHAR(255);
    DECLARE v_device_id VARCHAR(255);

    -- Error handler for rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_is_success = FALSE;
        SET p_session_token_out = NULL;
        SET p_error_message = 'An error occurred. Transaction rolled back.';
        SET v_ok = 0;
    END;

    START TRANSACTION;

    SET p_is_success = FALSE;
    SET p_session_token_out = NULL;
    SET p_expiry_at = NULL;
    SET p_error_message = NULL;

    -- Operation 1: Create session
    IF p_action = 1 THEN
        -- Validate user_id
        IF p_user_id IS NULL OR p_user_id <= 0 THEN
            SET p_error_message = 'Invalid user ID for session creation';
            SET v_ok = 0;
        END IF;

        IF v_ok = 1 THEN
            -- Generate new session token (UUID)
            SET v_new_session_token = UUID();
            
            -- Generate device ID
            SET v_device_id = CONCAT('device_', p_user_id, '_', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'));

            -- Insert new session record with 1-hour expiry from now
            INSERT INTO master_user_session (
                id,
                user_id,
                device_id,
                device_name,
                session_token,
                ip_address,
                user_agent,
                created_at,
                expiry_at,
                last_active,
                is_active
            ) VALUES (
                v_new_session_token,
                p_user_id,
                v_device_id,
                'Web Browser',
                v_new_session_token,
                p_ip_address,
                p_user_agent,
                NOW(),
                DATE_ADD(NOW(), INTERVAL 1 HOUR),
                NOW(),
                TRUE
            );

            SET p_session_token_out = v_new_session_token;
            SET p_expiry_at = DATE_ADD(NOW(), INTERVAL 1 HOUR);
            SET p_is_success = TRUE;
            SET p_error_message = 'Session created successfully';
        END IF;
    END IF;

    -- Operation 2: Update session expiry by 1 hour
    IF p_action = 2 THEN
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

            IF ROW_COUNT() > 0 THEN
                SET p_expiry_at = DATE_ADD(NOW(), INTERVAL 1 HOUR);
                SET p_is_success = TRUE;
                SET p_error_message = 'Session expiry extended successfully';
            ELSE
                SET p_error_message = 'Session not found or update failed';
                SET v_ok = 0;
            END IF;
        END IF;
    END IF;

    -- Operation 3: Delete session (logout)
    IF p_action = 3 THEN
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
    IF p_action NOT IN (1, 2, 3) THEN
        SET p_error_message = 'Invalid operation. Supported operations: 1 (Create), 2 (Update), 3 (Delete)';
        SET v_ok = 0;
    END IF;

    -- Commit or rollback
    IF v_ok = 1 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;
END;
