DROP PROCEDURE IF EXISTS sp_customer_manage;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_customer_manage`(
    IN p_action INT,
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
    IN p_role_user VARCHAR(255)
)
BEGIN
    DECLARE v_role_id INT DEFAULT NULL;
    DECLARE v_last_id INT DEFAULT NULL;
    DECLARE v_active_count INT DEFAULT 0;
    DECLARE v_deleted_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'Error: Unable to process request.' AS message, FALSE AS success;
    END;

main_block: BEGIN

    /* ====== GET ROLE ====== */
    SELECT role_id INTO v_role_id
    FROM master_user
    WHERE master_user_id = p_role_user
    LIMIT 1;

    IF v_role_id IS NULL THEN
        SELECT 'Unauthorized: Role not found.' AS message, FALSE AS success;
        LEAVE main_block;
    END IF;

    /* ====== RESTRICT MODIFY ACTIONS ====== */
    IF p_action IN (1,2,3) AND v_role_id NOT IN (1,2,3) THEN
        SELECT 'Unauthorized: No permission.' AS message, FALSE AS success;
        LEAVE main_block;
    END IF;

    /* ============================================================ */
    /*                           CREATE                              */
    /* ============================================================ */

    IF p_action = 1 THEN

        SELECT COUNT(*) INTO v_active_count
        FROM customer
        WHERE email = p_email
          AND business_id = p_business_id
          AND is_deleted = 0;

        IF v_active_count > 0 THEN
            SELECT 'Email already exists for active customer.' AS message, FALSE AS success;
            LEAVE main_block;
        END IF;

        SELECT COUNT(*) INTO v_deleted_count
        FROM customer
        WHERE email = p_email
          AND business_id = p_business_id
          AND is_deleted = 1;

        IF v_deleted_count > 0 THEN
            UPDATE customer
            SET 
                first_name = p_first_name,
                last_name = p_last_name,
                contact_number = p_contact_number,
                address_line = p_address_line,
                city = p_city,
                state = p_state,
                country = p_country,
                pincode = p_pincode,
                branch_id = p_branch_id,
                is_deleted = 0,
                is_active = 1,
                updated_by = p_user,
                updated_at = NOW()
            WHERE email = p_email
              AND business_id = p_business_id;

            SELECT 'Customer reactivated successfully.' AS message, TRUE AS success;
            LEAVE main_block;
        END IF;

        INSERT INTO customer(
            business_id, branch_id, first_name, last_name, email,
            contact_number, address_line, city, state, country,
            pincode, created_by
        )
        VALUES(
            p_business_id, p_branch_id, p_first_name, p_last_name, p_email,
            p_contact_number, p_address_line, p_city, p_state, p_country,
            p_pincode, p_user
        );

        SET v_last_id = LAST_INSERT_ID();

        SELECT CONCAT('Customer created successfully. ID=', v_last_id) AS message, TRUE AS success;
        LEAVE main_block;
    END IF;

    /* ============================================================ */
    /*                           UPDATE                              */
    /* ============================================================ */
    IF p_action = 2 THEN
        UPDATE customer
        SET 
            business_id = p_business_id,
            branch_id = p_branch_id,
            first_name = p_first_name,
            last_name = p_last_name,
            email = p_email,
            contact_number = p_contact_number,
            address_line = p_address_line,
            city = p_city,
            state = p_state,
            country = p_country,
            pincode = p_pincode,
            updated_by = p_user,
            updated_at = NOW()
        WHERE customer_id = p_customer_id
          AND is_deleted = 0;

        SELECT 'Customer updated successfully.' AS message, TRUE AS success;
        LEAVE main_block;
    END IF;

    /* ============================================================ */
    /*                           DELETE                              */
    /* ============================================================ */
    IF p_action = 3 THEN
        UPDATE customer
        SET 
            is_deleted = 1,
            is_active = 0,
            deleted_at = NOW(),
            updated_by = p_user,
            updated_at = NOW()
        WHERE customer_id = p_customer_id
          AND is_deleted = 0;

        SELECT 'Customer deleted successfully.' AS message, TRUE AS success;
        LEAVE main_block;
    END IF;

    /* ============================================================ */
    /*                           GET LIST                            */
    /* ============================================================ */
    IF p_action = 4 THEN
        SELECT *
        FROM customer
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND is_deleted = 0
        ORDER BY customer_id DESC;

        LEAVE main_block;
    END IF;

    /* ============================================================ */
    /*                         GET LIST BY ROLE                      */
    /* ============================================================ */
    IF p_action = 5 THEN
        
        IF v_role_id = 1 THEN
            SELECT *
            FROM customer
            WHERE business_id = p_business_id
              AND is_deleted = 0
            ORDER BY customer_id DESC;
        ELSE
            SELECT *
            FROM customer
            WHERE business_id = p_business_id
              AND branch_id = p_branch_id
              AND is_deleted = 0
            ORDER BY customer_id DESC;
        END IF;

        LEAVE main_block;
    END IF;

    SELECT 'Invalid action.' AS message, FALSE AS success;

END main_block;
END
DELIMITER ;
