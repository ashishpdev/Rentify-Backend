DROP PROCEDURE sp_manage_otp;
CREATE PROCEDURE `sp_manage_otp`(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete, 4=Get
    IN target_identifier CHAR(36),
    IN p_target_identifier VARCHAR(255),
    IN p_otp_code_hash VARCHAR(255),
    IN p_otp_type_id INT,
    IN p_otp_status_id INT,
    IN p_expiry_minutes INT,
    IN p_ip_address VARCHAR(100),
    IN p_created_by VARCHAR(255),
    OUT p_id CHAR(36),
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_otp_type_id INT DEFAULT NULL;
    DECLARE v_otp_status_id INT DEFAULT NULL;
    DECLARE v_business_exists INT DEFAULT 0;
    DECLARE v_owner_exists INT DEFAULT 0;
    DECLARE v_pending_status_id INT DEFAULT NULL;
    
    -- Generic error handler for SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Rollback if a transaction is open and return a simple message
        ROLLBACK;
        SET p_error_message = 'Error: Unable to process request.';
    END;
    
    SET p_id = NULL;
    SET p_error_message = NULL;
    
    /* Labeled inner block to allow LEAVE for early exits (portable) */
    main_block: BEGIN

        /* --------------------- CREATE --------------------- */
        IF p_action = 1 THEN
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
            
            -- Check if email exists in master_user if OTP type ID is 1 (LOGIN)
            IF p_otp_type_id = 1 THEN
                -- Check if email exists in master_user
                SELECT COUNT(*) INTO v_owner_exists
                  FROM master_user
                 WHERE email = p_target_identifier AND is_deleted = 0;
                
                IF v_owner_exists = 0 THEN
                    SET p_error_message = 'Email not found';
                    LEAVE main_block;
                END IF;
            END IF;
            
            -- Check for duplicate email if OTP type ID is 2 (REGISTER)
            IF p_otp_type_id = 2 THEN
                -- Check if email already exists in master_business
                SELECT COUNT(*) INTO v_business_exists
                  FROM master_business
                 WHERE email = p_target_identifier AND is_deleted = 0;
                
                IF v_business_exists > 0 THEN
                    SET p_error_message = 'Business email already registered';
                    LEAVE main_block;
                END IF;
                
                -- Check if email already exists in master_user
                SELECT COUNT(*) INTO v_owner_exists
                  FROM master_user
                 WHERE email = p_target_identifier AND is_deleted = 0;
                
                IF v_owner_exists > 0 THEN
                    SET p_error_message = 'Owner email already registered';
                    LEAVE main_block;
                END IF;
            END IF;
            
            -- Get PENDING status ID
            SELECT master_otp_status_id
              INTO v_pending_status_id
              FROM master_otp_status
             WHERE code = 'PENDING' AND is_deleted = 0
             LIMIT 1;
            IF v_pending_status_id IS NULL THEN
                SET p_error_message = 'OTP status configuration error';
                LEAVE main_block;
            END IF;
            
            SET p_id = UUID();
            
            -- Start transaction
            START TRANSACTION;
            
            -- Delete ALL existing OTPs with same target_identifier and otp_type_id
            DELETE FROM master_otp
             WHERE target_identifier = p_target_identifier
               AND otp_type_id = p_otp_type_id;
            
            -- Insert the new OTP record
            INSERT INTO master_otp (
                id, target_identifier, otp_code_hash, otp_type_id, otp_status_id,
                expires_at, ip_address, created_by
            )
            VALUES (
                p_id, p_target_identifier, p_otp_code_hash, p_otp_type_id, v_pending_status_id,
                DATE_ADD(UTC_TIMESTAMP(), INTERVAL p_expiry_minutes MINUTE), p_ip_address, p_created_by
            );
            
            -- Commit transaction
            COMMIT;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        /* --------------------- UPDATE --------------------- */
        IF p_action = 2 THEN
            -- Validate target identifier is provided
            IF target_identifier IS NULL OR target_identifier = '' THEN
                SET p_error_message = 'Target identifier is required for update operation';
                LEAVE main_block;
            END IF;
            
            -- Validate OTP status ID is valid if provided
            IF p_otp_status_id IS NOT NULL THEN
                SELECT master_otp_status_id
                  INTO v_otp_status_id
                  FROM master_otp_status
                 WHERE master_otp_status_id = p_otp_status_id AND is_deleted = 0
                 LIMIT 1;
                IF v_otp_status_id IS NULL THEN
                    SET p_error_message = 'Invalid OTP status';
                    LEAVE main_block;
                END IF;
            END IF;
            
            START TRANSACTION;
            UPDATE master_otp
            SET 
                otp_code_hash = COALESCE(p_otp_code_hash, otp_code_hash),
                otp_status_id = COALESCE(p_otp_status_id, otp_status_id),
                updated_at = UTC_TIMESTAMP(6)
            WHERE target_identifier = target_identifier;
            COMMIT;
            SET target_identifier = target_identifier;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        /* --------------------- DELETE (soft) --------------------- */
        IF p_action = 3 THEN
            -- Validate target identifier is provided
            IF target_identifier IS NULL OR target_identifier = '' THEN
                SET p_error_message = 'Target identifier is required for delete operation';
                LEAVE main_block;
            END IF;
            
            START TRANSACTION;
            DELETE FROM master_otp
             WHERE target_identifier = target_identifier;
            COMMIT;
            SET target_identifier = target_identifier;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        /* --------------------- GET --------------------- */
        IF p_action = 4 THEN
            -- Validate target identifier is provided
            IF target_identifier IS NULL OR target_identifier = '' THEN
                SET p_error_message = 'Target identifier is required for get operation';
                LEAVE main_block;
            END IF;
            
            SELECT 
                id, target_identifier, otp_code_hash, otp_type_id, otp_status_id,
                expires_at, verified_at, attempts, ip_address, created_by, created_at,
                updated_by, updated_at
            FROM master_otp
            WHERE target_identifier = p_target_identifier
            LIMIT 1;
            SET target_identifier = target_identifier;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        -- If action not matched
        SET p_error_message = 'Invalid action. Supported operations: 1 (Create), 2 (Update), 3 (Delete), 4 (Get)';
    END; -- end main_block

END
