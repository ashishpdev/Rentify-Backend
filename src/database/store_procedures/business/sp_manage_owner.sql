DROP PROCEDURE IF EXISTS sp_manage_owner;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_owner`(
    IN  p_action INT,
    IN  p_owner_id INT,
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_owner_name VARCHAR(255),
    IN  p_owner_email VARCHAR(255),
    IN  p_owner_contact_number VARCHAR(50),
    IN  p_created_by VARCHAR(255),

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    DECLARE v_owner_role_id INT DEFAULT NULL;
    DECLARE v_existing_owner INT DEFAULT 0;
    DECLARE v_user_role_id INT DEFAULT NULL;
    DECLARE v_default_password VARCHAR(255) DEFAULT NULL;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_INVALID_REFERENCE';
        SET p_error_message = 'Operation failed: Invalid reference provided.';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;
        GET DIAGNOSTICS CONDITION v_cno
            v_errno = MYSQL_ERRNO,
            v_sql_state = RETURNED_SQLSTATE,
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_success = FALSE;
        IF p_error_code IS NULL THEN
            SET p_error_code = 'ERR_SQL_EXCEPTION';
            SET p_error_message = CONCAT('Database error: ', v_error_msg);
        END IF;
    END;

    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_action IN (2,3) THEN
        SELECT role_id INTO v_user_role_id
        FROM master_user
        WHERE email = p_created_by AND deleted_at IS NULL
        LIMIT 1;

        IF v_user_role_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_ROLE';
            SET p_error_message = 'User does not have a valid role.';
            LEAVE proc_body;
        END IF;

        IF v_user_role_id != 1 THEN
            SET p_error_code = 'ERR_PERMISSION_DENIED';
            SET p_error_message = 'You are not allowed to perform this action.';
            LEAVE proc_body;
        END IF;
    END IF;

    IF p_action = 1 THEN
        SELECT master_role_type_id INTO v_owner_role_id
        FROM master_role_type
        WHERE code = 'OWNER'
        LIMIT 1;

        IF v_owner_role_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_ROLE';
            SET p_error_message = 'Role type OWNER does not exist.';
            LEAVE proc_body;
        END IF;

        SELECT COUNT(*) INTO v_existing_owner
        FROM master_user
        WHERE email = p_owner_email AND deleted_at IS NULL;

        IF v_existing_owner > 0 THEN
            SET p_error_code = 'ERR_EMAIL_EXISTS';
            SET p_error_message = 'Owner email already registered.';
            LEAVE proc_body;
        END IF;

        SET v_default_password = SHA2(CONCAT('TEMP_', p_owner_email, '_', UNIX_TIMESTAMP()), 256);

        START TRANSACTION;

        INSERT INTO master_user (
            business_id, 
            branch_id, 
            role_id, 
            name, 
            email,
            hash_password,
            contact_number, 
            is_owner, 
            created_by
        )
        VALUES (
            p_business_id, 
            p_branch_id, 
            v_owner_role_id, 
            p_owner_name,
            p_owner_email,
            v_default_password,
            p_owner_contact_number, 
            TRUE, 
            p_created_by
        );

        SET p_id = LAST_INSERT_ID();

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Owner created successfully.';
        LEAVE proc_body;
    END IF;

    IF p_action = 2 THEN
        START TRANSACTION;

        UPDATE master_user
        SET 
            name = p_owner_name,
            email = p_owner_email,
            contact_number = p_owner_contact_number,
            updated_by = p_created_by,
            updated_at = UTC_TIMESTAMP(6)
        WHERE master_user_id = p_owner_id
          AND is_owner = TRUE
          AND deleted_at IS NULL;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Owner not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_owner_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Owner updated successfully.';
        LEAVE proc_body;
    END IF;

    IF p_action = 3 THEN
        START TRANSACTION;

        UPDATE master_user
        SET 
            is_active = 0,
            deleted_at = UTC_TIMESTAMP(6),
            updated_by = p_created_by,
            updated_at = UTC_TIMESTAMP(6)
        WHERE master_user_id = p_owner_id
          AND is_owner = TRUE
          AND deleted_at IS NULL;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Owner not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_owner_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Owner deleted successfully.';
        LEAVE proc_body;
    END IF;

    IF p_action = 4 THEN
        SELECT JSON_OBJECT(
            'user_id', master_user_id,
            'business_id', business_id,
            'branch_id', branch_id,
            'role_id', role_id,
            'name', name,
            'email', email,
            'contact_number', contact_number,
            'is_owner', is_owner,
            'is_active', is_active,
            'created_by', created_by,
            'created_at', created_at,
            'updated_by', updated_by,
            'updated_at', updated_at
        )
        INTO p_data
        FROM master_user
        WHERE master_user_id = p_owner_id
          AND is_owner = TRUE
          AND deleted_at IS NULL
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Owner record not found.';
            LEAVE proc_body;
        END IF;

        SET p_id = p_owner_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Owner details fetched successfully.';
        LEAVE proc_body;
    END IF;

    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action specified.';

END;