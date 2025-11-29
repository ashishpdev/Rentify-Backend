DROP PROCEDURE IF EXISTS sp_register_business_branch_owner;
CREATE PROCEDURE `sp_register_business_branch_owner`(
    IN p_business_name VARCHAR(255),
    IN p_business_email VARCHAR(255),
    IN p_contact_person VARCHAR(255),
    IN p_contact_number VARCHAR(50),
    IN p_owner_name VARCHAR(255),
    IN p_owner_email VARCHAR(255),
    IN p_owner_contact_number VARCHAR(50),
    IN p_created_by VARCHAR(255),
    OUT p_business_id INT,
    OUT p_branch_id INT,
    OUT p_owner_id INT,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_register_otp_type_id INT DEFAULT NULL;
    DECLARE v_verified_status_id INT DEFAULT NULL;
    DECLARE v_owner_otp_verified INT DEFAULT 0;
    DECLARE v_business_temp_id INT DEFAULT NULL;
    DECLARE v_branch_temp_id INT DEFAULT NULL;
    DECLARE v_owner_temp_id INT DEFAULT NULL;
    DECLARE v_business_error VARCHAR(500) DEFAULT NULL;
    DECLARE v_owner_error VARCHAR(500) DEFAULT NULL;
    -- DECLARE v_branch_error VARCHAR(500) DEFAULT NULL;
    
    -- -- single-line error handler
    -- DECLARE EXIT HANDLER FOR SQLEXCEPTION
    -- BEGIN
    --     -- Rollback if a transaction is open and return a simple message
    --     ROLLBACK;
    --     SET p_error_message = 'Error: Unable to process request.';
    -- END;
    
    SET p_business_id = NULL;
    SET p_branch_id = NULL;
    SET p_owner_id = NULL;
    SET p_error_message = NULL;
    
    /* Labeled inner block to allow LEAVE for early exits (portable) */
    main_block: BEGIN

        /* --------- Validate that business email and owner email are different --------- */
        IF p_business_email = p_owner_email THEN
            SET p_error_message = 'Business email and owner email must be different';
            LEAVE main_block;
        END IF;
        
        /* --------- Get REGISTER OTP type ID --------- */
        SELECT master_otp_type_id
          INTO v_register_otp_type_id
          FROM master_otp_type
         WHERE code = 'REGISTER' AND is_deleted = 0
         LIMIT 1;
        IF v_register_otp_type_id IS NULL THEN
            SET p_error_message = 'OTP type configuration error';
            LEAVE main_block;
        END IF;
        
        /* --------- Get VERIFIED status ID --------- */
        SELECT master_otp_status_id
          INTO v_verified_status_id
          FROM master_otp_status
         WHERE code = 'VERIFIED' AND is_deleted = 0
         LIMIT 1;
        IF v_verified_status_id IS NULL THEN
            SET p_error_message = 'OTP status configuration error';
            LEAVE main_block;
        END IF;
        
        /* --------- Check if owner email has verified OTP --------- */
        SELECT COUNT(*) INTO v_owner_otp_verified
        FROM master_otp
        WHERE target_identifier = p_owner_email
          AND otp_type_id = v_register_otp_type_id
          AND otp_status_id = v_verified_status_id
          AND expires_at > NOW();
        
        IF v_owner_otp_verified = 0 THEN
            SET p_error_message = 'Owner email OTP not verified';
            LEAVE main_block;
        END IF;
        
        /* --------- Create business using sp_business_manage --------- */
        CALL sp_business_manage(
            1,                          -- p_action = CREATE
            NULL,                       -- p_business_id
            p_business_name,
            p_business_email,
            p_contact_person,
            p_contact_number,
            NULL,                       -- p_status_code
            p_created_by,
            v_business_temp_id,
            v_business_error
        );
        
        IF v_business_error != 'Success' THEN
            SET p_error_message = CONCAT('Business creation failed: ', v_business_error);
            LEAVE main_block;
        END IF;
        
        SET p_business_id = v_business_temp_id;
        
        /* --------- Insert HQ branch --------- */
        START TRANSACTION;
        INSERT INTO master_branch (
            business_id, branch_name, branch_code, contact_number, created_by
        )
        VALUES (
            p_business_id, CONCAT(p_business_name, ' - HQ'), 'HQ-001',
            p_contact_number, p_created_by
        );
        SET v_branch_temp_id = LAST_INSERT_ID();
        COMMIT;
        
        SET p_branch_id = v_branch_temp_id;
        
        /* --------- Create owner using sp_owner_manage --------- */
        CALL sp_owner_manage(
            1,                          -- p_action = CREATE
            NULL,                       -- p_owner_id
            p_business_id,
            p_branch_id,
            p_owner_name,
            p_owner_email,
            p_owner_contact_number,
            p_created_by,
            v_owner_temp_id,
            v_owner_error
        );
        
        IF v_owner_error != 'Success' THEN
            SET p_error_message = CONCAT('Owner creation failed: ', v_owner_error);
            LEAVE main_block;
        END IF;
        
        SET p_owner_id = v_owner_temp_id;
        
        /* --------- Delete OTP entries for both emails after successful registration --------- */
        DELETE FROM master_otp
         WHERE target_identifier IN (p_business_email, p_owner_email)
           AND otp_type_id = v_register_otp_type_id;
        
        SET p_error_message = 'Success';
        
    END; -- end main_block

END
