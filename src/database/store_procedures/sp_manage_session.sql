DROP PROCEDURE IF EXISTS sp_manage_session;
CREATE PROCEDURE `sp_manage_session`(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete, 4=Get
    IN p_user_id INT,
    IN p_session_token TEXT,            -- Encrypted session token (can be long)
    IN p_ip_address VARCHAR(255),
    IN p_expiry_at_in DATETIME(6),      -- Expiry time from encrypted token (UTC)
    OUT p_is_success BOOLEAN,
    OUT p_session_token_out TEXT,
    OUT p_expiry_at DATETIME(6),
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_session_id CHAR(36);
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

        -- Operation 1: Create session (store encrypted token)
        IF p_action = 1 THEN
            -- Validate user_id
            IF p_user_id IS NULL OR p_user_id <= 0 THEN
                SET p_error_message = 'Invalid user ID for session creation';
                LEAVE main_block;
            END IF;

            -- Validate session token is provided
            IF p_session_token IS NULL OR p_session_token = '' THEN
                SET p_error_message = 'Session token is required for create operation';
                LEAVE main_block;
            END IF;

            -- Validate expiry time is provided
            IF p_expiry_at_in IS NULL THEN
                SET p_error_message = 'Expiry time is required for create operation';
                LEAVE main_block;
            END IF;

            START TRANSACTION;
            
            -- Generate UUID for record id
            SET v_session_id = UUID();
            
            -- Generate device ID using UTC timestamp
            SET v_device_id = CONCAT('device_', p_user_id, '_', DATE_FORMAT(UTC_TIMESTAMP(6), '%Y%m%d%H%i%s%f'));

            -- Insert new session record with encrypted token and provided expiry (UTC)
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
                v_session_id,
                p_user_id,
                v_device_id,
                'Web Browser',
                p_session_token,
                p_ip_address,
                UTC_TIMESTAMP(6),
                p_expiry_at_in,
                UTC_TIMESTAMP(6),
                TRUE
            );
            COMMIT;

            SET p_session_token_out = p_session_token;
            SET p_expiry_at = p_expiry_at_in;
            SET p_is_success = TRUE;
            SET p_error_message = 'Session created successfully';
            LEAVE main_block;
        END IF;

        -- Operation 2: Update session (store new encrypted token)
        IF p_action = 2 THEN
            -- Check if session token is provided
            IF p_session_token IS NULL OR p_session_token = '' THEN
                SET p_error_message = 'Session token is required for update operation';
                LEAVE main_block;
            END IF;

            -- Validate expiry time is provided
            IF p_expiry_at_in IS NULL THEN
                SET p_error_message = 'Expiry time is required for update operation';
                LEAVE main_block;
            END IF;

            START TRANSACTION;
            -- Update session with new encrypted token and expiry (UTC)
            UPDATE master_user_session
               SET session_token = p_session_token,
                   expiry_at = p_expiry_at_in,
                   last_active = UTC_TIMESTAMP(6),
                   updated_at = UTC_TIMESTAMP(6)
             WHERE user_id = p_user_id
               AND is_active = TRUE;

            IF ROW_COUNT() > 0 THEN
                COMMIT;
                SET p_session_token_out = p_session_token;
                SET p_expiry_at = p_expiry_at_in;
                SET p_is_success = TRUE;
                SET p_error_message = 'Session updated successfully';
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

        -- Operation 4: Get session details (for verification when needed)
        IF p_action = 4 THEN
            -- Check if user_id is provided
            IF p_user_id IS NULL OR p_user_id <= 0 THEN
                SET p_error_message = 'User ID is required for get operation';
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
                user_id = p_user_id
                AND is_active = TRUE
                AND expiry_at > UTC_TIMESTAMP(6)
            LIMIT 1;

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
