DROP PROCEDURE IF EXISTS sp_manage_business;
CREATE PROCEDURE `sp_manage_business`(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete, 4=Get
    IN p_business_id INT,
    IN p_business_name VARCHAR(255),
    IN p_business_email VARCHAR(255),
    IN p_contact_person VARCHAR(255),
    IN p_contact_number VARCHAR(50),
    IN p_status_code VARCHAR(100),
    IN p_created_by VARCHAR(255),
    OUT p_id INT,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_business_status_id INT DEFAULT NULL;
    DECLARE v_existing_business INT DEFAULT NULL;
    DECLARE v_subscription_type_id INT DEFAULT NULL;
    DECLARE v_subscription_status_id INT DEFAULT NULL;
    DECLARE v_billing_cycle_id INT DEFAULT NULL;
    DECLARE v_user_role_id INT DEFAULT NULL;
    
    -- single-line error handler
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

        /* --------- Fetch role only when needed (for update/delete) --------- */
        IF p_action IN (2,3) THEN
            SELECT role_id INTO v_user_role_id
            FROM master_user
            WHERE email = p_created_by AND is_deleted = 0
            LIMIT 1;
            IF v_user_role_id IS NULL THEN
                SET p_error_message = 'Unauthorized user: Role not found.';
                LEAVE main_block;
            END IF;
        END IF;
        
        /* --------- Deny update/delete if role not allowed --------- */
        IF p_action IN (2,3) AND v_user_role_id != 1 THEN
            SET p_error_message = 'You are not authorized to perform this action.';
            LEAVE main_block;
        END IF;

        /* --------------------- CREATE --------------------- */
        IF p_action = 1 THEN
            -- Get business status (ACTIVE)
            SELECT master_business_status_id
              INTO v_business_status_id
              FROM master_business_status
             WHERE code = 'ACTIVE' AND is_deleted = 0
             LIMIT 1;
            IF v_business_status_id IS NULL THEN
                SET p_error_message = 'Business status ACTIVE not found';
                LEAVE main_block;
            END IF;
            
            -- Get subscription type (TRIAL)
            SELECT master_subscription_type_id
              INTO v_subscription_type_id
              FROM master_subscription_type
             WHERE code = 'TRIAL' AND is_deleted = 0
             LIMIT 1;
            IF v_subscription_type_id IS NULL THEN
                SET p_error_message = 'Invalid subscription type TRIAL';
                LEAVE main_block;
            END IF;
            
            -- Get subscription status (ACTIVE)
            SELECT master_subscription_status_id
              INTO v_subscription_status_id
              FROM master_subscription_status
             WHERE code = 'ACTIVE' AND is_deleted = 0
             LIMIT 1;
            IF v_subscription_status_id IS NULL THEN
                SET p_error_message = 'Subscription status ACTIVE not found';
                LEAVE main_block;
            END IF;
            
            -- Get billing cycle (MONTHLY)
            SELECT master_billing_cycle_id
              INTO v_billing_cycle_id
              FROM master_billing_cycle
             WHERE code = 'MONTHLY' AND is_deleted = 0
             LIMIT 1;
            IF v_billing_cycle_id IS NULL THEN
                SET p_error_message = 'Invalid billing cycle MONTHLY';
                LEAVE main_block;
            END IF;
            
            -- Check if email already exists
            SELECT COUNT(*) INTO v_existing_business
              FROM master_business
             WHERE email = p_business_email AND is_deleted = 0;
            IF v_existing_business > 0 THEN
                SET p_error_message = 'Business email already exists';
                LEAVE main_block;
            END IF;
            
            START TRANSACTION;
            INSERT INTO master_business (
                business_name, email, contact_person, contact_number,
                status_id, subscription_type_id, subscription_status_id, billing_cycle_id,
                created_by
            )
            VALUES (
                p_business_name, p_business_email, p_contact_person, p_contact_number,
                v_business_status_id, v_subscription_type_id, v_subscription_status_id, v_billing_cycle_id,
                p_created_by
            );
            SET p_id = LAST_INSERT_ID();
            COMMIT;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        /* --------------------- UPDATE --------------------- */
        IF p_action = 2 THEN
            -- Get business status
            SELECT master_business_status_id
              INTO v_business_status_id
              FROM master_business_status
             WHERE code = p_status_code AND is_deleted = 0
             LIMIT 1;
            IF v_business_status_id IS NULL THEN
                SET p_error_message = 'Invalid business status code';
                LEAVE main_block;
            END IF;
            
            START TRANSACTION;
            UPDATE master_business
            SET 
                business_name = p_business_name,
                email = p_business_email,
                contact_person = p_contact_person,
                contact_number = p_contact_number,
                status_id = v_business_status_id,
                updated_by = p_created_by,
                updated_at = CURRENT_TIMESTAMP(6)
            WHERE business_id = p_business_id AND is_deleted = 0;
            COMMIT;
            SET p_id = p_business_id;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        /* --------------------- DELETE (soft) --------------------- */
        IF p_action = 3 THEN
            START TRANSACTION;
            UPDATE master_business
            SET 
                is_deleted = 1,
                deleted_at = CURRENT_TIMESTAMP(6),
                updated_by = p_created_by,
                updated_at = CURRENT_TIMESTAMP(6)
            WHERE business_id = p_business_id AND is_deleted = 0;
            COMMIT;
            SET p_id = p_business_id;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        /* --------------------- GET --------------------- */
        IF p_action = 4 THEN
            SELECT 
                business_id, business_name, email, contact_person, contact_number,
                status_id, subscription_type_id, subscription_status_id, billing_cycle_id,
                created_by, created_at, updated_by, updated_at, is_deleted
            FROM master_business
            WHERE business_id = p_business_id AND is_deleted = 0
            LIMIT 1;
            SET p_id = p_business_id;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        -- If action not matched
        SET p_error_message = 'Invalid action.';
    END; -- end main_block

END
