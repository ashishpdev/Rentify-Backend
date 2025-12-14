DROP PROCEDURE IF EXISTS sp_manage_customer;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_customer`(
    IN  p_action INT,                      -- 1=Create, 2=Update, 3=Delete, 4=Get List, 5=Get List By Role
    IN  p_customer_id INT,
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_first_name VARCHAR(200),
    IN  p_last_name VARCHAR(200),
    IN  p_email VARCHAR(255),
    IN  p_contact_number VARCHAR(80),
    IN  p_address_line VARCHAR(255),
    IN  p_city VARCHAR(100),
    IN  p_state VARCHAR(100),
    IN  p_country VARCHAR(100),
    IN  p_pincode VARCHAR(20),
    IN  p_user VARCHAR(255),
    IN  p_role_user VARCHAR(255),

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    /* ================================================================
       DECLARATIONS
       ================================================================ */
    DECLARE v_role_id INT DEFAULT NULL;
    DECLARE v_active_count INT DEFAULT 0;
    DECLARE v_deleted_count INT DEFAULT 0;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    /* ================================================================
       SPECIFIC ERROR HANDLER FOR FOREIGN KEY VIOLATIONS (Error 1452)
       ================================================================ */
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_INVALID_REFERENCE';
        SET p_error_message = 'Operation failed: Invalid Segment, Category or Model name provided.';
    END;

    /* ================================================================
       ERROR HANDLER
       ================================================================ */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;
            GET DIAGNOSTICS CONDITION v_cno
            v_errno = MYSQL_ERRNO,
            v_sql_state = RETURNED_SQLSTATE,
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        IF p_error_code IS NULL THEN
            SET p_success = FALSE;
            SET p_error_code = 'ERR_SQL_EXCEPTION';
            SET p_error_message = 'Unexpected database error occurred.';
        END IF;
    END;

    /* ================================================================
       RESET OUTPUT PARAMETERS
       ================================================================ */
    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;



    /* ================================================================
       GET ROLE VALIDATION
       ================================================================ */
    SELECT role_id INTO v_role_id
    FROM master_user
    WHERE master_user_id = p_role_user
    LIMIT 1;

    IF v_role_id IS NULL THEN
        SET p_error_code = 'ERR_UNAUTHORIZED';
        SET p_error_message = 'Role not found';
        LEAVE proc_body;
    END IF;

    /* Restrict Create/Update/Delete to specific roles */
    IF p_action IN (1,2,3) AND v_role_id NOT IN (1,2,3) THEN
        SET p_error_code = 'ERR_PERMISSION_DENIED';
        SET p_error_message = 'User does not have permission to modify customers';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 1: CREATE CUSTOMER
       ================================================================ */
    IF p_action = 1 THEN
        START TRANSACTION;

        /* Check duplicate active customer */
        SELECT COUNT(*) INTO v_active_count
        FROM customer
        WHERE email = p_email
          AND business_id = p_business_id
          AND branch_id = p_branch_id
          AND is_deleted = 0;

        IF v_active_count > 0 THEN
            SET p_error_code = 'ERR_EMAIL_EXISTS';
            SET p_error_message = 'Email already exists for an active customer';
            ROLLBACK;
            LEAVE proc_body;
        END IF;

        /* Check for deleted customer → Reactivate */
        SELECT COUNT(*) INTO v_deleted_count
        FROM customer
        WHERE email = p_email
          AND business_id = p_business_id
          AND branch_id = p_branch_id
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

            -- Get the reactivated customer_id
            SELECT customer_id INTO p_id
            FROM customer
            WHERE email = p_email
              AND business_id = p_business_id
              AND branch_id = p_branch_id
              AND is_deleted = 0
            LIMIT 1;

            COMMIT;

            SET p_success = TRUE;
            SET p_error_code = 'SUCCESS';
            SET p_error_message = 'Customer reactivated successfully';
            LEAVE proc_body;
        END IF;

        /* Insert new customer */
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

        SET p_id = LAST_INSERT_ID();

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Customer created successfully';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 2: UPDATE CUSTOMER
       ================================================================ */
    IF p_action = 2 THEN
        START TRANSACTION;

        /* Check duplicate active customer */
        SELECT COUNT(*) INTO v_active_count
        FROM customer
        WHERE email = p_email
          AND business_id = p_business_id
          AND branch_id = p_branch_id
          AND is_deleted = 0;

        IF v_active_count > 0 THEN
            SET p_error_code = 'ERR_EMAIL_EXISTS';
            SET p_error_message = 'Email already exists for an active customer';
            ROLLBACK;
            LEAVE proc_body;
        END IF;

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

        SET p_id = p_customer_id;

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Customer updated successfully';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 3: DELETE CUSTOMER (SOFT DELETE)
       ================================================================ */
    IF p_action = 3 THEN
        START TRANSACTION;

        UPDATE customer
        SET 
            is_deleted = 1,
            is_active = 0,
            deleted_at = NOW(),
            updated_by = p_user,
            updated_at = NOW()
        WHERE customer_id = p_customer_id
          AND is_deleted = 0;

        SET p_id = p_customer_id;

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Customer deleted successfully';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 4: GET CUSTOMER LIST
       ================================================================ */
    IF p_action = 4 THEN

        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'customer_id', customer_id,
                'first_name', first_name,
                'last_name', last_name,
                'email', email,
                'contact_number', contact_number,
                'address_line', address_line,
                'city', city,
                'state', state,
                'country', country,
                'pincode', pincode,
                'created_at', created_at
            )
        )
        INTO p_data
        FROM customer
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND is_deleted = 0
        ORDER BY customer_id DESC;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Customer list fetched successfully';
        LEAVE proc_body;
    END IF;



    /* ================================================================
       ACTION 5: GET LIST BASED ON ROLE
       ================================================================ */
    IF p_action = 5 THEN

        IF v_role_id = 1 THEN
            -- Admin → All customers
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'customer_id', customer_id,
                    'first_name', first_name,
                    'last_name', last_name,
                    'email', email,
                    'contact_number', contact_number,
                    'branch_id', branch_id
                )
            )
            INTO p_data
            FROM customer
            WHERE business_id = p_business_id
              AND is_deleted = 0
            ORDER BY customer_id DESC;

        ELSE
            -- Branch level → Only branch customers
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'customer_id', customer_id,
                    'first_name', first_name,
                    'last_name', last_name,
                    'email', email,
                    'contact_number', contact_number
                )
            )
            INTO p_data
            FROM customer
            WHERE business_id = p_business_id
              AND branch_id = p_branch_id
              AND is_deleted = 0
            ORDER BY customer_id DESC;
        END IF;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Customer list fetched based on role';
        LEAVE proc_body;
    END IF;




    /* ================================================================
       INVALID ACTION
       ================================================================ */
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action specified';

END;
