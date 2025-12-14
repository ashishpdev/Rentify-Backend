DROP PROCEDURE IF EXISTS sp_action_login_with_otp;
CREATE PROCEDURE sp_action_login_with_otp(
    IN  p_email           VARCHAR(255),
    IN  p_otp_code_hash   VARCHAR(255),
    IN  p_ip_address      VARCHAR(255),
    OUT p_user_id         INT,
    OUT p_business_id     INT,
    OUT p_branch_id       INT,
    OUT p_role_id         INT,
    OUT p_contact_number  VARCHAR(50),
    OUT p_user_name       VARCHAR(255),
    OUT p_business_name   VARCHAR(255),
    OUT p_branch_name     VARCHAR(255),
    OUT p_role_name       VARCHAR(255),
    OUT p_is_owner        BOOLEAN,
    OUT p_error_message   VARCHAR(500)
)
proc_label: BEGIN

    -- Variable Declarations    
    DECLARE v_otp_record_id      CHAR(36) DEFAULT NULL;
    DECLARE v_otp_status_id      INT DEFAULT NULL;
    DECLARE v_expires_at         DATETIME(6) DEFAULT NULL;
    DECLARE v_verified_status_id INT DEFAULT NULL;
    DECLARE v_attempts           INT DEFAULT 0;
    DECLARE v_max_attempts       INT DEFAULT 3;
    DECLARE v_stored_otp_hash    VARCHAR(255) DEFAULT NULL;
    
    -- Constants (Reflected as variables for logic clarity)
    DECLARE v_otp_type_login     INT DEFAULT 1; 
    DECLARE v_status_code_ver    VARCHAR(50) DEFAULT 'VERIFIED';

    -- Error Handling Variables
    DECLARE v_cno                INT DEFAULT 0;
    DECLARE v_errno              INT DEFAULT 0;
    DECLARE v_sql_state          CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg          TEXT;

    -- ==================================================================================
    /* Exception Handling */
    -- ==================================================================================

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
            'sp_action_login_with_otp',
            CONCAT('p_email=', LEFT(p_email, 200), ', p_ip=', IFNULL(p_ip_address, 'NULL')),
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

    -- Initialization
    SET p_user_id        = NULL;
    SET p_business_id    = NULL;
    SET p_branch_id      = NULL;
    SET p_role_id        = NULL;
    SET p_contact_number = NULL;
    SET p_user_name      = NULL;
    SET p_business_name  = NULL;
    SET p_branch_name    = NULL;
    SET p_role_name      = NULL;
    SET p_is_owner       = FALSE;
    SET p_error_message  = NULL;

    -- =============================================
    /* Main Logic */
    -- =============================================
    START TRANSACTION;

        -- 1. Fetch Reference Data (Verified Status ID)
        SELECT master_otp_status_id
        INTO v_verified_status_id
        FROM master_otp_status
        WHERE code = v_status_code_ver
          AND is_deleted = 0
        LIMIT 1;

        -- 2. Validate OTP
        -- Using FOR UPDATE to lock the row and prevent race conditions (double login)
        -- First, find the latest OTP record by email and type (not by hash)
        SELECT id, otp_status_id, expires_at, attempts, max_attempts, otp_code_hash
        INTO v_otp_record_id, v_otp_status_id, v_expires_at, v_attempts, v_max_attempts, v_stored_otp_hash
        FROM master_otp
        WHERE target_identifier = p_email
          AND otp_type_id = v_otp_type_login
        ORDER BY created_at DESC
        LIMIT 1
        FOR UPDATE;

        -- Validation: Existence (no OTP record found for this email)
        IF v_otp_record_id IS NULL THEN
            SET p_error_message = 'No OTP found for this email';
            ROLLBACK; -- Must rollback before leaving
            LEAVE proc_label;
        END IF;

        -- Validation: Max Attempts Exceeded (check before incrementing)
        IF v_attempts >= v_max_attempts THEN
            SET p_error_message = 'Maximum OTP attempts exceeded';
            ROLLBACK; -- Must rollback before leaving
            LEAVE proc_label;
        END IF;

        -- Increment attempts counter BEFORE validating the hash
        UPDATE master_otp
        SET attempts = attempts + 1
        WHERE id = v_otp_record_id;

        -- Validation: Expiry
        IF UTC_TIMESTAMP() > v_expires_at THEN
            SET p_error_message = 'OTP has expired';
            ROLLBACK; -- Must rollback before leaving
            LEAVE proc_label;
        END IF;

        -- Validation: OTP Code Hash Match
        IF v_stored_otp_hash != p_otp_code_hash THEN
            -- Commit the attempt increment before leaving
            COMMIT;
            SET p_error_message = 'Invalid OTP code';
            LEAVE proc_label;
        END IF;

        -- 3. Fetch User Data
        SELECT
            u.master_user_id,
            u.business_id,
            u.branch_id,
            u.role_id,
            u.is_owner,
            u.name,
            u.contact_number,
            b.business_name,
            br.branch_name,
            r.name
        INTO
            p_user_id,
            p_business_id,
            p_branch_id,
            p_role_id,
            p_is_owner,
            p_user_name,
            p_contact_number,
            p_business_name,
            p_branch_name,
            p_role_name
        FROM master_user u
        JOIN master_business b        ON u.business_id = b.business_id
        LEFT JOIN master_branch br    ON u.branch_id = br.branch_id
        JOIN master_role_type r       ON u.role_id = r.master_role_type_id
        WHERE u.email = p_email
          AND u.is_deleted = 0
          AND u.is_active = TRUE
          AND b.is_deleted = 0
          AND b.is_active = TRUE
        LIMIT 1;

        -- Validation: User Active/Found
        IF p_user_id IS NULL THEN
            SET p_error_message = 'User not found or inactive';
            ROLLBACK;
            LEAVE proc_label;
        END IF;

        -- 4. Execute Updates
        
        -- Update OTP to verified (if not already)
        -- Note: We rely on the subsequent DELETE, but this audit step was in original logic
        IF v_otp_status_id != v_verified_status_id THEN
            UPDATE master_otp
            SET verified_at = UTC_TIMESTAMP(6),
                otp_status_id = v_verified_status_id
            WHERE id = v_otp_record_id;
        END IF;

        -- Clean up existing sessions
        DELETE FROM master_user_session
        WHERE user_id = p_user_id;

        -- Delete the used OTP (Consider soft delete in future, but functionality preserved)
        DELETE FROM master_otp
        WHERE id = v_otp_record_id;

    COMMIT;
    
    SET p_error_message = 'Login successful';

END;