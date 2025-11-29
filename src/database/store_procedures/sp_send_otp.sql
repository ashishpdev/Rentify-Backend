DROP PROCEDURE IF EXISTS sp_send_otp;
DELIMITER $$

CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_send_otp`(
    IN p_email VARCHAR(255),
    IN p_otp_code_hash VARCHAR(255),
    IN p_otp_type_id INT,          -- 1 = LOGIN, 2 = REGISTER
    IN p_expiry_minutes INT,
    IN p_ip_address VARCHAR(100),
    OUT p_otp_id CHAR(36),
    OUT p_expires_at DATETIME,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_otp_type_id INT DEFAULT NULL;
    DECLARE v_pending_status_id INT DEFAULT NULL;
    DECLARE v_business_exists INT DEFAULT 0;
    DECLARE v_owner_exists INT DEFAULT 0;
    
    SET p_otp_id = NULL;
    SET p_expires_at = NULL;
    SET p_error_message = NULL;
    
    /* Labeled inner block to allow LEAVE for early exits (portable) */
    main_block: BEGIN

        /* --------- Validate OTP type ID is valid --------- */
        SELECT master_otp_type_id
          INTO v_otp_type_id
          FROM master_otp_type
         WHERE master_otp_type_id = p_otp_type_id AND is_deleted = 0
         LIMIT 1;
        IF v_otp_type_id IS NULL THEN
            SET p_error_message = 'Invalid OTP type';
            LEAVE main_block;
        END IF;
        
        /* --------- Check for duplicate email if OTP type ID is 2 (REGISTER) --------- */
        IF p_otp_type_id = 2 THEN
            -- Check if email already exists in master_business
            SELECT COUNT(*) INTO v_business_exists
              FROM master_business
             WHERE email = p_email AND is_deleted = 0;
            
            IF v_business_exists > 0 THEN
                SET p_error_message = 'Email already registered';
                LEAVE main_block;
            END IF;
            
            -- Check if email already exists in master_user
            SELECT COUNT(*) INTO v_owner_exists
              FROM master_user
             WHERE email = p_email AND is_deleted = 0;
            
            IF v_owner_exists > 0 THEN
                SET p_error_message = 'Email already registered';
                LEAVE main_block;
            END IF;
        END IF;
        
        /* --------- Get PENDING status ID --------- */
        SELECT master_otp_status_id
          INTO v_pending_status_id
          FROM master_otp_status
         WHERE code = 'PENDING'
           AND is_deleted = 0
         LIMIT 1;

        IF v_pending_status_id IS NULL THEN
            SET p_error_message = 'OTP status configuration error';
            LEAVE main_block;
        END IF;
<<<<<<< HEAD
    END IF;

    -- Generate and save OTP
    IF v_ok = 1 THEN
        -- Delete old unverified OTP for this email and type
=======
        
        /* --------- Delete old unverified OTP and create new record --------- */
>>>>>>> 43d3cb138dd87a69cc4a0fd34a6cc2d53f16c4d1
        DELETE FROM master_otp
         WHERE target_identifier = p_email
           AND otp_type_id = p_otp_type_id
           AND verified_at IS NULL;
<<<<<<< HEAD

        -- Generate new OTP ID and expiry
        SET p_otp_id = UUID();
        SET p_expires_at = DATE_ADD(NOW(), INTERVAL p_expiry_minutes MINUTE);

        -- Insert new OTP record with PENDING status
=======
        
        SET p_otp_id = UUID();
        SET p_expires_at = DATE_ADD(NOW(), INTERVAL p_expiry_minutes MINUTE);
        
>>>>>>> 43d3cb138dd87a69cc4a0fd34a6cc2d53f16c4d1
        INSERT INTO master_otp (
            id,
            target_identifier,
            otp_code_hash,
            otp_type_id,
            otp_status_id,
            expires_at,
            ip_address,
            created_by
        )
        VALUES (
            p_otp_id,
            p_email,
            p_otp_code_hash,
            p_otp_type_id,
            v_pending_status_id,
            p_expires_at,
            p_ip_address,
            'system'
        );

        SET p_error_message = 'Success';
<<<<<<< HEAD
    END IF;
END

DELIMITER ;
=======
        
    END; -- end main_block

END
>>>>>>> 43d3cb138dd87a69cc4a0fd34a6cc2d53f16c4d1
