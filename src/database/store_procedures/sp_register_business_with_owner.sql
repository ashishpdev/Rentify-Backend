DROP PROCEDURE sp_register_business_with_owner;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_register_business_with_owner`(
    IN p_business_name VARCHAR(255),
    IN p_business_email VARCHAR(255),
    IN p_website VARCHAR(255),
    IN p_contact_person VARCHAR(255),
    IN p_contact_number VARCHAR(50),
    IN p_address_line VARCHAR(255),
    IN p_city VARCHAR(100),
    IN p_state VARCHAR(100),
    IN p_country VARCHAR(100),
    IN p_pincode VARCHAR(20),
    IN p_subscription_type_code VARCHAR(100),
    IN p_billing_cycle_code VARCHAR(100),
    IN p_owner_name VARCHAR(255),
    IN p_owner_email VARCHAR(255),
    IN p_owner_contact_number VARCHAR(50),
    IN p_owner_role_code VARCHAR(100),
    IN p_created_by VARCHAR(255),
    OUT p_business_id INT,
    OUT p_branch_id INT,
    OUT p_owner_id INT,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_ok INT DEFAULT 1;
    DECLARE v_existing_business INT DEFAULT NULL;
    DECLARE v_subscription_type_id INT DEFAULT NULL;
    DECLARE v_subscription_status_id INT DEFAULT NULL;
    DECLARE v_billing_cycle_id INT DEFAULT NULL;
    DECLARE v_business_status_id INT DEFAULT NULL;
    DECLARE v_owner_role_id INT DEFAULT NULL;
    DECLARE v_register_otp_type_id INT DEFAULT NULL;
    DECLARE v_verified_status_id INT DEFAULT NULL;
    DECLARE v_business_otp_verified INT DEFAULT 0;
    DECLARE v_owner_otp_verified INT DEFAULT 0;
    
    SET p_business_id = NULL;
    SET p_branch_id = NULL;
    SET p_owner_id = NULL;
    SET p_error_message = NULL;
    
    -- Get REGISTER OTP type ID
    SELECT master_otp_type_id
      INTO v_register_otp_type_id
      FROM master_otp_type
     WHERE code = 'REGISTER' AND is_deleted = 0
     LIMIT 1;
    IF v_register_otp_type_id IS NULL THEN
        SET p_error_message = 'OTP type configuration error';
        SET v_ok = 0;
    END IF;
    
    -- Get VERIFIED status ID
    IF v_ok = 1 THEN
        SELECT master_otp_status_id
          INTO v_verified_status_id
          FROM master_otp_status
         WHERE code = 'VERIFIED' AND is_deleted = 0
         LIMIT 1;
        IF v_verified_status_id IS NULL THEN
            SET p_error_message = 'OTP status configuration error';
            SET v_ok = 0;
        END IF;
    END IF;
    
    -- Check if business email has verified OTP
    IF v_ok = 1 THEN
        SELECT COUNT(*) INTO v_business_otp_verified
        FROM master_otp
        WHERE target_identifier = p_business_email
          AND otp_type_id = v_register_otp_type_id
          AND otp_status_id = v_verified_status_id
          AND expires_at > NOW();
        
        IF v_business_otp_verified = 0 THEN
            SET p_error_message = 'Business email OTP not verified';
            SET v_ok = 0;
        END IF;
    END IF;
    
    -- Check if owner email has verified OTP
    IF v_ok = 1 THEN
        SELECT COUNT(*) INTO v_owner_otp_verified
        FROM master_otp
        WHERE target_identifier = p_owner_email
          AND otp_type_id = v_register_otp_type_id
          AND otp_status_id = v_verified_status_id
          AND expires_at > NOW();
        
        IF v_owner_otp_verified = 0 THEN
            SET p_error_message = 'Owner email OTP not verified';
            SET v_ok = 0;
        END IF;
    END IF;
    
    -- Check for existing business
    IF v_ok = 1 THEN
        SELECT business_id
          INTO v_existing_business
          FROM master_business
         WHERE email = p_business_email
         LIMIT 1;
        IF v_existing_business IS NOT NULL THEN
            SET p_error_message = 'Business email already exists';
            SET v_ok = 0;
        END IF;
    END IF;
    
    -- Get subscription type
    IF v_ok = 1 THEN
        SELECT master_subscription_type_id
          INTO v_subscription_type_id
          FROM master_subscription_type
         WHERE code = p_subscription_type_code AND is_deleted = 0
         LIMIT 1;
        IF v_subscription_type_id IS NULL THEN
            SET p_error_message = 'Invalid subscription type';
            SET v_ok = 0;
        END IF;
    END IF;
    
    -- Get subscription status (ACTIVE)
    IF v_ok = 1 THEN
        SELECT master_subscription_status_id
          INTO v_subscription_status_id
          FROM master_subscription_status
         WHERE code = 'ACTIVE' AND is_deleted = 0
         LIMIT 1;
    END IF;
    
    -- Get billing cycle
    IF v_ok = 1 THEN
        SELECT master_billing_cycle_id
          INTO v_billing_cycle_id
          FROM master_billing_cycle
         WHERE code = p_billing_cycle_code AND is_deleted = 0
         LIMIT 1;
        IF v_billing_cycle_id IS NULL THEN
            SET p_error_message = 'Invalid billing cycle';
            SET v_ok = 0;
        END IF;
    END IF;
    
    -- Get business status (TRIAL)
    IF v_ok = 1 THEN
        SELECT master_business_status_id
          INTO v_business_status_id
          FROM master_business_status
         WHERE code = 'TRIAL' AND is_deleted = 0
         LIMIT 1;
        IF v_business_status_id IS NULL THEN
            SET p_error_message = 'Business status TRIAL not found';
            SET v_ok = 0;
        END IF;
    END IF;
    
    -- Get owner role
    IF v_ok = 1 THEN
        SELECT master_role_type_id
          INTO v_owner_role_id
          FROM master_role_type
         WHERE code = p_owner_role_code AND is_deleted = 0
         LIMIT 1;
        IF v_owner_role_id IS NULL THEN
            SET p_error_message = 'Invalid owner role type';
            SET v_ok = 0;
        END IF;
    END IF;
    
    -- If all validations passed, start transaction
    IF v_ok = 0 THEN
        -- must include at least one statement here (no-op)
        SET p_business_id = p_business_id;
    ELSE
        START TRANSACTION;
        
        -- Insert business
        INSERT INTO master_business (
            business_name, email, website, contact_person, contact_number,
            address_line, city, state, country, pincode,
            status_id, subscription_type_id, subscription_status_id, billing_cycle_id,
            created_by
        )
        VALUES (
            p_business_name, p_business_email, p_website, p_contact_person, p_contact_number,
            p_address_line, p_city, p_state, p_country, p_pincode,
            v_business_status_id, v_subscription_type_id, v_subscription_status_id, v_billing_cycle_id,
            p_created_by
        );
        SET p_business_id = LAST_INSERT_ID();
        
        -- Insert branch
        INSERT INTO master_branch (
            business_id, branch_name, branch_code, address_line, city, state, country, pincode,
            contact_number, created_by
        )
        VALUES (
            p_business_id, CONCAT(p_business_name, ' - HQ'), 'HQ-001',
            p_address_line, p_city, p_state, p_country, p_pincode,
            p_contact_number, p_created_by
        );
        SET p_branch_id = LAST_INSERT_ID();
        
        -- Insert owner
        INSERT INTO master_owner (
            business_id, role_id, name, email, contact_number, created_by
        )
        VALUES (
            p_business_id, v_owner_role_id, p_owner_name, p_owner_email, p_owner_contact_number, p_created_by
        );
        SET p_owner_id = LAST_INSERT_ID();
        
        -- Delete OTP entries for both emails after successful registration
        DELETE FROM master_otp
         WHERE target_identifier IN (p_business_email, p_owner_email)
           AND otp_type_id = v_register_otp_type_id;
        
        COMMIT;
        SET p_error_message = 'Success';
    END IF;
END