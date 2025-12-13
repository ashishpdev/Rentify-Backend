DROP PROCEDURE IF EXISTS sp_manage_session;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_session`(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete, 4=Get
    IN p_user_id INT,
    IN p_session_token TEXT,            -- New encrypted session token (can be long)
    IN p_ip_address VARCHAR(255),
    IN p_expiry_at_in DATETIME(6),      -- Expiry time from encrypted token (UTC)
    IN p_old_session_token TEXT,        -- Old session token for validation (only for Update)
    
    OUT p_success BOOLEAN,
    OUT p_session_token_out TEXT,
    OUT p_expiry_at DATETIME(6),
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    -- DECLARATIONS
    DECLARE v_session_id CHAR(36);
    DECLARE v_device_id VARCHAR(255);
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- =============================================
    /* Exception Handling */
    -- =============================================
    
    -- Specific Handler: Foreign Key Violation
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_error_message = 'Foreign key violation (likely missing reference).';
    END;

    -- Specific Handler: Duplicate Key
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_error_message = 'Duplicate key error (unique constraint).';
    END;

    -- Generic Handler: SQLEXCEPTION
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;

        IF v_cno > 0 THEN
            GET DIAGNOSTICS CONDITION 1
                v_errno     = MYSQL_ERRNO,
                v_sql_state = RETURNED_SQLSTATE,
                v_error_msg = MESSAGE_TEXT;
        ELSE
            SET v_errno = NULL;
            SET v_sql_state = NULL;
            SET v_error_msg = 'No diagnostics available';
        END IF;

        ROLLBACK;

        -- Log error details
        INSERT INTO proc_error_log(
            proc_name, 
            proc_args, 
            mysql_errno, 
            sql_state, 
            error_message
        )
        VALUES (
            'sp_manage_session',
            CONCAT('p_user_id=', LEFT(p_user_id, 200), ', p_ip=', IFNULL(p_ip_address, 'NULL')),
            v_errno,
            v_sql_state,
            LEFT(v_error_msg, 2000)
        );

        -- Safe return message
        SET p_error_message = CONCAT(
            'Error logged (errno=', IFNULL(CAST(v_errno AS CHAR), '?'),
            ', sqlstate=', IFNULL(v_sql_state, '?'), '). See proc_error_log.'
        );
    END;

    -- RESET OUTPUT PARAMETERS
    SET p_success = FALSE;
    SET p_session_token_out = NULL;
    SET p_expiry_at = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    /* 1: CREATE */
    IF p_action = 1 THEN

        -- Validate Inputs
        IF p_user_id IS NULL OR p_user_id <= 0 THEN
            SET p_error_code = 'ERR_INVALID_USER_ID';
            SET p_error_message = 'Invalid user ID for session creation';
            LEAVE proc_body;
        END IF;

        IF p_session_token IS NULL OR p_session_token = '' THEN
            SET p_error_code = 'ERR_INVALID_SESSION_TOKEN';
            SET p_error_message = 'Session token is required for create operation';
            LEAVE proc_body;
        END IF;

        IF p_expiry_at_in IS NULL THEN
            SET p_error_code = 'ERR_INVALID_EXPIRY_TIME';
            SET p_error_message = 'Expiry time is required for create operation';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        -- Generate IDs
        SET v_session_id = UUID();
        SET v_device_id = CONCAT('device_', p_user_id, '_', DATE_FORMAT(UTC_TIMESTAMP(6), '%Y%m%d%H%i%s%f'));

        -- Insert New Session
        INSERT INTO master_user_session (
            id,
            user_id,
            device_id,
            device_name,
            session_token,
            ip_address,
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
            p_expiry_at_in,
            UTC_TIMESTAMP(6),
            TRUE
        );

        COMMIT;

        SET p_session_token_out = p_session_token;
        SET p_expiry_at = p_expiry_at_in;
        SET p_success = TRUE;
        SET p_error_code = NULL;
        SET p_error_message = 'Session created successfully';
        LEAVE proc_body;

    END IF;

    /* 2: UPDATE */
    IF p_action = 2 THEN

        -- Validate Inputs
        IF p_session_token IS NULL OR p_session_token = '' THEN
            SET p_error_code = 'ERR_INVALID_SESSION_TOKEN';
            SET p_error_message = 'New session token is required for update operation';
            LEAVE proc_body;
        END IF;

        IF p_old_session_token IS NULL OR p_old_session_token = '' THEN
            SET p_error_code = 'ERR_INVALID_OLD_SESSION_TOKEN';
            SET p_error_message = 'Old session token is required for update operation';
            LEAVE proc_body;
        END IF;

        IF p_expiry_at_in IS NULL THEN
            SET p_error_code = 'ERR_INVALID_EXPIRY_TIME';
            SET p_error_message = 'Expiry time is required for update operation';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        -- Update session only if old token matches exactly (BINARY)
        UPDATE master_user_session
           SET session_token = p_session_token,
               expiry_at = p_expiry_at_in,
               last_active = UTC_TIMESTAMP(6)
         WHERE user_id = p_user_id
           AND BINARY session_token = BINARY p_old_session_token
           AND is_active = TRUE
           AND expiry_at > UTC_TIMESTAMP(6);

        IF ROW_COUNT() > 0 THEN
            COMMIT;
            SET p_session_token_out = p_session_token;
            SET p_expiry_at = p_expiry_at_in;
            SET p_success = TRUE;
            SET p_error_code = NULL;
            SET p_error_message = 'Session updated successfully';
        ELSE
            ROLLBACK;
            SET p_error_code = 'ERR_SESSION_MISMATCH';
            SET p_error_message = 'Session token mismatch or session expired. Please login again.';
        END IF;

        LEAVE proc_body;

    END IF;

    /* 3: DELETE */
    IF p_action = 3 THEN

        -- Validate Inputs
        IF p_user_id IS NULL OR p_user_id <= 0 THEN
            SET p_error_code = 'ERR_INVALID_USER_ID';
            SET p_error_message = 'Invalid user ID';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        DELETE FROM master_user_session
        WHERE user_id = p_user_id;

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = NULL;
        SET p_error_message = 'Logout successful';
        LEAVE proc_body;

    END IF;

    /* 4: GET */
    IF p_action = 4 THEN

        -- Validate Inputs
        IF p_user_id IS NULL OR p_user_id <= 0 THEN
            SET p_error_code = 'ERR_INVALID_USER_ID';
            SET p_error_message = 'User ID is required for get operation';
            LEAVE proc_body;
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
            SET p_success = TRUE;
            SET p_error_code = NULL;
            SET p_error_message = 'Session retrieved successfully';
        ELSE
            SET p_error_code = 'ERR_SESSION_NOT_FOUND';
            SET p_error_message = 'Session not found or expired';
        END IF;

        LEAVE proc_body;

    END IF;

    -- INVALID ACTION
    SET p_success = FALSE;
    SET p_error_message = 'Invalid operation. Supported operations: 1 (Create), 2 (Update), 3 (Delete), 4 (Get)';

END;