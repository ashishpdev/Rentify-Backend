DROP PROCEDURE sp_manage_session;
CREATE PROCEDURE `sp_manage_session`(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete, 4=Get
    IN p_user_id INT,
    IN p_session_token VARCHAR(255),
    IN p_ip_address VARCHAR(255),
    OUT p_is_success BOOLEAN,
    OUT p_session_token_out VARCHAR(255),
    OUT p_expiry_at DATETIME,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_new_session_token VARCHAR(255);
    DECLARE v_device_id VARCHAR(255);

    -- Error handler for rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_is_success = FALSE;
        SET p_session_token_out = NULL;
        SET p_error_message = 'An error occurred. Transaction rolled back.';
    END;

    SET p_is_success = FALSE;
    SET p_session_token_out = NULL;
    SET p_expiry_at = NULL;
    SET p_error_message = NULL;

    /* Labeled block to control flow with LEAVE for early exits */
    main_block: BEGIN

        -- Operation 1: Create session
        IF p_action = 1 THEN
            -- Validate user_id
            IF p_user_id IS NULL OR p_user_id <= 0 THEN
                SET p_error_message = 'Invalid user ID for session creation';
                LEAVE main_block;
            END IF;

            START TRANSACTION;
            -- Generate new session token (UUID)
            SET v_new_session_token = UUID();
            
            -- Generate device ID using UTC timestamp
            SET v_device_id = CONCAT('device_', p_user_id, '_', DATE_FORMAT(UTC_TIMESTAMP(), '%Y%m%d%H%i%s'));

            -- Insert new session record with 1-hour expiry from now (UTC)
            INSERT INTO master_user_session (
                id,
                user_id,
                device_id,
                device_name,
                session_token,
                ip_address,
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
                UTC_TIMESTAMP(),
                DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR),
                UTC_TIMESTAMP(),
                TRUE
            );
            COMMIT;

            SET p_session_token_out = v_new_session_token;
            SET p_expiry_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR);
            SET p_is_success = TRUE;
            SET p_error_message = 'Session created successfully';
            LEAVE main_block;
        END IF;

        -- Operation 2: Update session expiry by 1 hour
        IF p_action = 2 THEN
            -- Check if session token is provided
            IF p_session_token IS NULL OR p_session_token = '' THEN
                SET p_error_message = 'Session token is required for update operation';
                LEAVE main_block;
            END IF;

            START TRANSACTION;
            -- Update expiry_at to 1 hour from now (UTC)
            UPDATE master_user_session
             SET expiry_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR),
                 updated_at = UTC_TIMESTAMP()
             WHERE session_token = p_session_token AND user_id = p_user_id;

            IF ROW_COUNT() > 0 THEN
                COMMIT;
                SET p_expiry_at = DATE_ADD(UTC_TIMESTAMP(), INTERVAL 1 HOUR);
                SET p_is_success = TRUE;
                SET p_error_message = 'Session expiry extended successfully';
            ELSE
                ROLLBACK;
                SET p_error_message = 'Session not found or update failed';
                LEAVE main_block;
            END IF;
            LEAVE main_block;
        END IF;

        -- Operation 3: Delete session (logout)
        IF p_action = 3 THEN
            -- Check if user_id is provided
            IF p_user_id IS NULL OR p_user_id <= 0 THEN
                SET p_error_message = 'Invalid user ID';
                LEAVE main_block;
            END IF;

            START TRANSACTION;
            DELETE FROM master_user_session
             WHERE user_id = p_user_id;
            COMMIT;

            SET p_is_success = TRUE;
            SET p_error_message = 'Logout successful';
            LEAVE main_block;
        END IF;

        -- Operation 4: Get session details
        IF p_action = 4 THEN
            -- Check if session token is provided
            IF p_session_token IS NULL OR p_session_token = '' THEN
                SET p_error_message = 'Session token is required for get operation';
                LEAVE main_block;
            END IF;

                SELECT 
                    session_token,
                    expiry_at
                INTO 
                    p_session_token_out,
                    p_expiry_at
                FROM 
                    master_user_session
                WHERE 
                    session_token = p_session_token
                    AND is_active = TRUE
                    AND expiry_at > UTC_TIMESTAMP();

            IF p_session_token_out IS NOT NULL THEN
                SET p_is_success = TRUE;
                SET p_error_message = 'Session retrieved successfully';
            ELSE
                SET p_error_message = 'Session not found or expired';
                LEAVE main_block;
            END IF;
            LEAVE main_block;
        END IF;

        -- If operation is not recognized
        SET p_error_message = 'Invalid operation. Supported operations: 1 (Create), 2 (Update), 3 (Delete), 4 (Get)';

    END; /* end main_block */
END;
