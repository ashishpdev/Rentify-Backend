DROP PROCEDURE sp_customer_manage;
CREATE PROCEDURE `sp_customer_manage`(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete, 4=Get List, 5=Get List Based On Role
    IN p_customer_id INT,
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_first_name VARCHAR(200),
    IN p_last_name VARCHAR(200),
    IN p_email VARCHAR(255),
    IN p_contact_number VARCHAR(80),
    IN p_address_line VARCHAR(255),
    IN p_city VARCHAR(100),
    IN p_state VARCHAR(100),
    IN p_country VARCHAR(100),
    IN p_pincode VARCHAR(20),
    IN p_user VARCHAR(255),
    IN p_role_user VARCHAR(255)         -- username to lookup role in master_user
)
BEGIN
    DECLARE v_role_id INT DEFAULT NULL;
    DECLARE v_last_id INT DEFAULT NULL;
    -- single-line error handler
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        -- Rollback if a transaction is open and return a simple message
        ROLLBACK;
        SELECT 'Error: Unable to process request.' AS message;
    END;
    /* Labeled inner block to allow LEAVE for early exits (portable) */
    main_block: BEGIN

        /* --------- Fetch role only when needed (for update/delete/list-by-role) --------- */
        IF p_action IN (2,3,5) THEN
            SELECT role_id INTO v_role_id
            FROM master_user
            WHERE email = p_role_user
            LIMIT 1;
            IF v_role_id IS NULL THEN
                SELECT 'Unauthorized user: Role not found.' AS message;
                LEAVE main_block;
            END IF;
        END IF;
        /* --------- Deny update/delete if role not allowed --------- */
        IF p_action IN (2,3) AND v_role_id NOT IN (1,2,3) THEN
            SELECT 'You are not authorized to perform this action.' AS message;
            LEAVE main_block;
        END IF;
        /* --------------------- CREATE (no role check) --------------------- */
        IF p_action = 1 THEN
            START TRANSACTION;
            INSERT INTO customer (
                business_id, branch_id, first_name, last_name, email,
                contact_number, address_line, city, state, country, pincode, created_by
            )
            VALUES (
                p_business_id, p_branch_id, p_first_name, p_last_name, p_email,
                p_contact_number, p_address_line, p_city, p_state, p_country,
                p_pincode, p_user
            );
            SET v_last_id = LAST_INSERT_ID();
            COMMIT;
            SELECT CONCAT('Customer created successfully. ID=', v_last_id) AS message;
            LEAVE main_block;
        END IF;
        /* --------------------- UPDATE (role required) --------------------- */
        IF p_action = 2 THEN
            START TRANSACTION;
            UPDATE customer
            SET 
                business_id    = p_business_id,
                branch_id      = p_branch_id,
                first_name     = p_first_name,
                last_name      = p_last_name,
                email          = p_email,
                contact_number = p_contact_number,
                address_line   = p_address_line,
                city           = p_city,
                state          = p_state,
                country        = p_country,
                pincode        = p_pincode,
                updated_by     = p_user,
                updated_at     = CURRENT_TIMESTAMP(6)
            WHERE customer_id = p_customer_id AND is_deleted = 0;
            COMMIT;
            SELECT CONCAT('Customer updated successfully. ID=', p_customer_id) AS message;
            LEAVE main_block;
        END IF;
        /* --------------------- DELETE (soft, role required) --------------------- */
        IF p_action = 3 THEN
            START TRANSACTION;
            UPDATE customer
            SET 
                is_deleted = 1,
                is_active = 0,
                deleted_at = CURRENT_TIMESTAMP(6),
                updated_by = p_user,
                updated_at = CURRENT_TIMESTAMP(6)
            WHERE customer_id = p_customer_id AND is_deleted = 0;
            COMMIT;
            SELECT CONCAT('Customer deleted successfully. ID=', p_customer_id) AS message;
            LEAVE main_block;
        END IF;
        /* --------------------- GET LIST (branch-specific) --------------------- */
        IF p_action = 4 THEN
            SELECT 
                customer_id, business_id, branch_id,
                first_name, last_name, email, contact_number,
                address_line, city, state, country, pincode,
                created_by, created_at, updated_by, updated_at,
                is_active, is_deleted
            FROM customer
            WHERE business_id = p_business_id
              AND branch_id = p_branch_id
              AND is_deleted = 0
            ORDER BY customer_id DESC;
            LEAVE main_block;
        END IF;
        /* --------------------- GET LIST BASED ON ROLE (action = 5) --------------------- */
        IF p_action = 5 THEN
            IF v_role_id = 1 THEN
                -- role 1: show all branches for the business
                SELECT 
                    customer_id, business_id, branch_id,
                    first_name, last_name, email, contact_number,
                    address_line, city, state, country, pincode,
                    created_by, created_at, updated_by, updated_at,
                    is_active, is_deleted
                FROM customer
                WHERE business_id = p_business_id
                  AND is_deleted = 0
                ORDER BY branch_id, customer_id DESC;
                LEAVE main_block;
            ELSE
                -- role 2 or 3: only own branch
                SELECT 
                    customer_id, business_id, branch_id,
                    first_name, last_name, email, contact_number,
                    address_line, city, state, country, pincode,
                    created_by, created_at, updated_by, updated_at,
                    is_active, is_deleted
                FROM customer
                WHERE business_id = p_business_id
                  AND branch_id = p_branch_id
                  AND is_deleted = 0
                ORDER BY customer_id DESC;
                LEAVE main_block;
            END IF;
        END IF;
        -- If action not matched
        SELECT 'Invalid action.' AS message;
    END; -- end main_block

END