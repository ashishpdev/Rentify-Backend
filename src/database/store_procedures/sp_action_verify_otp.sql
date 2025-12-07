DROP PROCEDURE IF EXISTS sp_action_verify_otp;

CREATE PROCEDURE `sp_action_verify_otp`(
    IN  p_target_identifier VARCHAR(255),
    IN  p_otp_code_hash VARCHAR(255),
    IN  p_otp_type_id INT,
    
    OUT p_success BOOLEAN,
    OUT p_otp_id CHAR(36),
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    /* ================================================================
       DECLARATIONS
       ================================================================ */
    DECLARE v_otp_id CHAR(36) DEFAULT NULL;
    DECLARE v_expires_at DATETIME(6) DEFAULT NULL;
    DECLARE v_verified_at DATETIME(6) DEFAULT NULL;
    DECLARE v_otp_type_id INT DEFAULT NULL;
    DECLARE v_current_otp_status_id INT DEFAULT NULL;
    
    DECLARE v_pending_status_id INT DEFAULT NULL;
    DECLARE v_verified_status_id INT DEFAULT NULL;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    /* ================================================================
       SPECIFIC ERROR HANDLER FOR FOREIGN KEY VIOLATIONS (Error 1452)
       ================================================================ */
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_INVALID_REFERENCE';
        SET p_error_message = 'Operation failed: Invalid Segment, Category or Model name provided.';
    END;

    /* ================================================================
       ERROR HANDLER
       ================================================================ */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;
            GET DIAGNOSTICS CONDITION v_cno
            v_errno = MYSQL_ERRNO,
            v_sql_state = RETURNED_SQLSTATE,
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_success = FALSE;

        IF p_error_code IS NULL THEN
            SET p_error_code = 'ERR_SQL_EXCEPTION';
            SET p_error_message = 'Unexpected database error occurred.';
        END IF;
    END;

    /* ================================================================
       RESET OUTPUT PARAMETERS
       ================================================================ */
    SET p_success = FALSE;
    SET p_otp_id = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    /* ================================================================
       INPUT VALIDATION
       ================================================================ */
    IF p_target_identifier IS NULL OR p_target_identifier = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'Target identifier is required.';
        LEAVE proc_body;
    END IF;

    IF p_otp_code_hash IS NULL OR p_otp_code_hash = '' THEN
        SET p_error_code = 'ERR_INVALID_INPUT';
        SET p_error_message = 'OTP code is required.';
        LEAVE proc_body;
    END IF;

    /* ================================================================
       FETCH CONFIGURATION DATA (Statuses & Types)
       ================================================================ */
    
    -- Validate OTP Type
    SELECT master_otp_type_id INTO v_otp_type_id
    FROM master_otp_type
    WHERE master_otp_type_id = p_otp_type_id AND is_deleted = 0 AND is_active = TRUE
    LIMIT 1;

    IF v_otp_type_id IS NULL THEN
        SET p_error_code = 'ERR_INVALID_TYPE';
        SET p_error_message = 'Invalid OTP type provided.';
        LEAVE proc_body;
    END IF;

    -- Get PENDING status ID
    SELECT master_otp_status_id INTO v_pending_status_id
    FROM master_otp_status
    WHERE code = 'PENDING' AND is_deleted = 0
    LIMIT 1;

    IF v_pending_status_id IS NULL THEN
        SET p_error_code = 'ERR_CONFIG_MISSING';
        SET p_error_message = 'System configuration error: PENDING status not found.';
        LEAVE proc_body;
    END IF;

    -- Get VERIFIED status ID
    SELECT master_otp_status_id INTO v_verified_status_id
    FROM master_otp_status
    WHERE code = 'VERIFIED' AND is_deleted = 0
    LIMIT 1;

    IF v_verified_status_id IS NULL THEN
        SET p_error_code = 'ERR_CONFIG_MISSING';
        SET p_error_message = 'System configuration error: VERIFIED status not found.';
        LEAVE proc_body;
    END IF;

    /* ================================================================
       FETCH OTP RECORD
       ================================================================ */
    SELECT id, expires_at, verified_at, otp_status_id
    INTO v_otp_id, v_expires_at, v_verified_at, v_current_otp_status_id
    FROM master_otp
    WHERE target_identifier = p_target_identifier
      AND otp_code_hash = p_otp_code_hash
      AND otp_type_id = p_otp_type_id
    ORDER BY created_at DESC
    LIMIT 1;

    /* ================================================================
       VERIFICATION LOGIC
       ================================================================ */
    
    -- 1. Check if OTP exists
    IF v_otp_id IS NULL THEN
        SET p_error_code = 'ERR_INVALID_OTP';
        SET p_error_message = 'Invalid OTP or Identifier.';
        LEAVE proc_body;
    END IF;

    -- 2. Check if already verified
    IF v_verified_at IS NOT NULL OR v_current_otp_status_id = v_verified_status_id THEN
        SET p_error_code = 'ERR_OTP_USED';
        SET p_error_message = 'This OTP has already been used.';
        LEAVE proc_body;
    END IF;

    -- 3. Check expiration
    IF UTC_TIMESTAMP() > v_expires_at THEN
        SET p_error_code = 'ERR_OTP_EXPIRED';
        SET p_error_message = 'This OTP has expired.';
        LEAVE proc_body;
    END IF;

    -- 4. Check if status is PENDING (Strict state check)
    IF v_current_otp_status_id != v_pending_status_id THEN
        SET p_error_code = 'ERR_INVALID_STATE';
        SET p_error_message = 'OTP is not in a valid pending state.';
        LEAVE proc_body;
    END IF;

    /* ================================================================
       UPDATE OTP (Mark as Verified)
       ================================================================ */
    START TRANSACTION;

    UPDATE master_otp
    SET 
        verified_at = UTC_TIMESTAMP(6),
        otp_status_id = v_verified_status_id,
        updated_at = UTC_TIMESTAMP(6)
    WHERE id = v_otp_id;

    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SET p_error_code = 'ERR_UPDATE_FAILED';
        SET p_error_message = 'Failed to update OTP status.';
        LEAVE proc_body;
    END IF;

    COMMIT;

    /* ================================================================
       SUCCESS RESPONSE
       ================================================================ */
    SET p_success = TRUE;
    SET p_otp_id = v_otp_id;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'OTP verified successfully.';

END;