DROP PROCEDURE IF EXISTS sp_owner_manage;
CREATE PROCEDURE `sp_owner_manage`(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete, 4=Get
    IN p_owner_id INT,
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_owner_name VARCHAR(255),
    IN p_owner_email VARCHAR(255),
    IN p_owner_contact_number VARCHAR(50),
    IN p_created_by VARCHAR(255),
    OUT p_id INT,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_owner_role_id INT DEFAULT NULL;
    DECLARE v_existing_owner INT DEFAULT NULL;
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
            -- Get owner role (OWNER)
            SELECT master_role_type_id
              INTO v_owner_role_id
              FROM master_role_type
             WHERE code = 'OWNER' AND is_deleted = 0
             LIMIT 1;
            IF v_owner_role_id IS NULL THEN
                SET p_error_message = 'Invalid owner role type OWNER';
                LEAVE main_block;
            END IF;
            
            -- Check if email already exists for this owner
            SELECT COUNT(*) INTO v_existing_owner
              FROM master_user
             WHERE email = p_owner_email AND is_deleted = 0;
            IF v_existing_owner > 0 THEN
                SET p_error_message = 'Owner email already exists';
                LEAVE main_block;
            END IF;
            
            START TRANSACTION;
            INSERT INTO master_user (
                business_id, branch_id, role_id, name, email, contact_number, is_owner, created_by
            )
            VALUES (
                p_business_id, p_branch_id, v_owner_role_id, p_owner_name, p_owner_email, 
                p_owner_contact_number, TRUE, p_created_by
            );
            SET p_id = LAST_INSERT_ID();
            COMMIT;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        /* --------------------- UPDATE --------------------- */
        IF p_action = 2 THEN
            START TRANSACTION;
            UPDATE master_user
            SET 
                name = p_owner_name,
                email = p_owner_email,
                contact_number = p_owner_contact_number,
                updated_by = p_created_by,
                updated_at = CURRENT_TIMESTAMP(6)
            WHERE user_id = p_owner_id AND is_owner = TRUE AND is_deleted = 0;
            COMMIT;
            SET p_id = p_owner_id;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        /* --------------------- DELETE (soft) --------------------- */
        IF p_action = 3 THEN
            START TRANSACTION;
            UPDATE master_user
            SET 
                is_deleted = 1,
                is_active = 0,
                deleted_at = CURRENT_TIMESTAMP(6),
                updated_by = p_created_by,
                updated_at = CURRENT_TIMESTAMP(6)
            WHERE user_id = p_owner_id AND is_owner = TRUE AND is_deleted = 0;
            COMMIT;
            SET p_id = p_owner_id;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        /* --------------------- GET --------------------- */
        IF p_action = 4 THEN
            SELECT 
                user_id, business_id, branch_id, role_id, name, email, contact_number,
                is_owner, is_active, created_by, created_at, updated_by, updated_at, is_deleted
            FROM master_user
            WHERE user_id = p_owner_id AND is_owner = TRUE AND is_deleted = 0
            LIMIT 1;
            SET p_id = p_owner_id;
            SET p_error_message = 'Success';
            LEAVE main_block;
        END IF;
        
        -- If action not matched
        SET p_error_message = 'Invalid action.';
    END; -- end main_block

END
