DROP PROCEDURE sp_action_verify_otp;
CREATE PROCEDURE `sp_action_verify_otp`(
    IN p_target_identifier VARCHAR(255),
    IN p_otp_code_hash VARCHAR(255),
    IN p_otp_type_id INT,
    OUT p_verified BOOLEAN,
    OUT p_otp_id CHAR(36),
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_otp_id CHAR(36);
    DECLARE v_expires_at DATETIME(6);
    DECLARE v_verified_at DATETIME(6);
    DECLARE v_otp_type_id INT;
    DECLARE v_otp_status_id INT;
    DECLARE v_pending_status_id INT;
    DECLARE v_verified_status_id INT;
    
    -- Error handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_verified = FALSE;
        SET p_error_message = 'Database error occurred during OTP verification';
    END;
    
    SET p_verified = FALSE;
    SET p_otp_id = NULL;
    SET p_error_message = NULL;
    
    main_block: BEGIN
        -- Validate OTP type ID is valid
        SELECT master_otp_type_id
          INTO v_otp_type_id
          FROM master_otp_type
         WHERE master_otp_type_id = p_otp_type_id AND is_deleted = 0
         LIMIT 1;
        IF v_otp_type_id IS NULL THEN
            SET p_error_message = 'Invalid OTP type';
            LEAVE main_block;
        END IF;
        
        -- Get PENDING status ID to check current OTP status
        SELECT master_otp_status_id
          INTO v_pending_status_id
          FROM master_otp_status
         WHERE code = 'PENDING' AND is_deleted = 0
         LIMIT 1;
        
        -- Get VERIFIED status ID for updating OTP after successful verification
        SELECT master_otp_status_id
          INTO v_verified_status_id
          FROM master_otp_status
         WHERE code = 'VERIFIED' AND is_deleted = 0
         LIMIT 1;
        
        -- Find the OTP record
        SELECT id, expires_at, verified_at, otp_status_id
          INTO v_otp_id, v_expires_at, v_verified_at, v_otp_status_id
          FROM master_otp
         WHERE target_identifier = p_target_identifier
           AND otp_code_hash = p_otp_code_hash
           AND otp_type_id = p_otp_type_id
         ORDER BY created_at DESC
         LIMIT 1;
        
        -- Check if OTP record was found
        IF v_otp_id IS NULL THEN
            SET p_error_message = 'Invalid OTP';
            LEAVE main_block;
        END IF;
        
        -- Check if OTP has already been verified
        IF v_verified_at IS NOT NULL THEN
            SET p_error_message = 'OTP already used';
            LEAVE main_block;
        END IF;
        
        -- Check if OTP has expired (using UTC for consistent timezone handling)
        IF UTC_TIMESTAMP() > v_expires_at THEN
            SET p_error_message = 'OTP expired';
            LEAVE main_block;
        END IF;
        
        -- Check if OTP status is still PENDING
        IF v_otp_status_id != v_pending_status_id THEN
            SET p_error_message = 'OTP is not in valid state';
            LEAVE main_block;
        END IF;
        
        -- OTP is valid - mark it as verified
        START TRANSACTION;
        UPDATE master_otp
        SET 
            verified_at = UTC_TIMESTAMP(6),
            otp_status_id = v_verified_status_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE id = v_otp_id;
        COMMIT;
        
        -- Return success
        SET p_verified = TRUE;
        SET p_otp_id = v_otp_id;
        SET p_error_message = 'Success';
        
    END; -- end main_block

END;