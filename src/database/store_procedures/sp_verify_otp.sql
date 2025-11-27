DROP PROCEDURE sp_verify_otp;
CREATE PROCEDURE `sp_verify_otp`(
    IN p_email VARCHAR(255),
    IN p_otp_code_hash VARCHAR(255),
    IN p_otp_type_id INT,
    OUT p_verified BOOLEAN,
    OUT p_otp_id CHAR(36),
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_ok INT DEFAULT 1;
    DECLARE v_otp_record_id CHAR(36) DEFAULT NULL;
    DECLARE v_stored_hash VARCHAR(255) DEFAULT NULL;
    DECLARE v_attempts INT DEFAULT 0;
    DECLARE v_max_attempts INT DEFAULT 3;
    DECLARE v_verified_status_id INT DEFAULT NULL;
    DECLARE v_failed_status_id INT DEFAULT NULL;
    SET p_verified = FALSE;
    SET p_otp_id = NULL;
    SET p_error_message = NULL;
    -- Get VERIFIED and FAILED status IDs
    SELECT master_otp_status_id
      INTO v_verified_status_id
      FROM master_otp_status
     WHERE code = 'VERIFIED' AND is_deleted = 0
     LIMIT 1;
    SELECT master_otp_status_id
      INTO v_failed_status_id
      FROM master_otp_status
     WHERE code = 'FAILED' AND is_deleted = 0
     LIMIT 1;
    IF v_verified_status_id IS NULL OR v_failed_status_id IS NULL THEN
        SET p_error_message = 'OTP status configuration error';
        SET v_ok = 0;
    END IF;
    IF v_ok = 1 THEN
        -- Get most recent PENDING OTP for this email and type
        SELECT id, otp_code_hash, attempts
          INTO v_otp_record_id, v_stored_hash, v_attempts
          FROM master_otp
         WHERE target_identifier = p_email
           AND otp_type_id = p_otp_type_id
           AND otp_status_id = (SELECT master_otp_status_id FROM master_otp_status WHERE code = 'PENDING' AND is_deleted = 0 LIMIT 1)
           AND expires_at > NOW()
           AND attempts < v_max_attempts
         ORDER BY created_at DESC
         LIMIT 1;
        IF v_otp_record_id IS NULL THEN
            SET p_error_message = 'No valid OTP found for this email and type';
            SET v_ok = 0;
        END IF;
    END IF;
    IF v_ok = 1 THEN
        -- Check if hash matches
        IF v_stored_hash = p_otp_code_hash THEN
            -- Mark OTP as verified
            UPDATE master_otp
               SET verified_at = NOW(),
                   otp_status_id = v_verified_status_id,
                   attempts = attempts + 1,
                   updated_at = NOW()
             WHERE id = v_otp_record_id;
            SET p_verified = TRUE;
            SET p_otp_id = v_otp_record_id;
            SET p_error_message = 'Success';
        ELSE
            -- Increment attempt counter
            UPDATE master_otp
               SET attempts = attempts + 1,
                   updated_at = NOW()
             WHERE id = v_otp_record_id;
            -- Mark as FAILED if max attempts reached
            IF (v_attempts + 1) >= v_max_attempts THEN
                UPDATE master_otp
                   SET otp_status_id = v_failed_status_id
                 WHERE id = v_otp_record_id;
            END IF;
            SET p_error_message = 'Invalid OTP code';
            SET v_ok = 0;
        END IF;
    END IF;
END