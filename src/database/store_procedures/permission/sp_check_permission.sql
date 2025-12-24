DROP PROCEDURE IF EXISTS sp_check_permission;
CREATE PROCEDURE sp_check_permission(
    IN  p_user_id INT,
    IN  p_permission_code VARCHAR(100),
    
    OUT p_has_permission BOOLEAN,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN
    
    DECLARE v_role_id TINYINT DEFAULT NULL;
    DECLARE v_permission_count INT DEFAULT 0;
    DECLARE v_is_active BOOLEAN DEFAULT FALSE;
    DECLARE v_is_owner BOOLEAN DEFAULT FALSE;
    
    -- Initialize outputs
    SET p_has_permission = FALSE;
    SET p_error_code = NULL;
    SET p_error_message = NULL;
    
    -- Validate inputs
    IF p_user_id IS NULL OR p_user_id <= 0 THEN
        SET p_error_code = 'ERR_INVALID_USER';
        SET p_error_message = 'Invalid user ID';
        LEAVE proc_body;
    END IF;
    
    IF p_permission_code IS NULL OR p_permission_code = '' THEN
        SET p_error_code = 'ERR_INVALID_PERMISSION';
        SET p_error_message = 'Permission code is required';
        LEAVE proc_body;
    END IF;
    
    -- Get user's role and status
    SELECT role_id, is_active, is_owner
    INTO v_role_id, v_is_active, v_is_owner
    FROM master_user
    WHERE master_user_id = p_user_id
      AND deleted_at IS NULL
    LIMIT 1;
    
    IF v_role_id IS NULL THEN
        SET p_error_code = 'ERR_USER_NOT_FOUND';
        SET p_error_message = 'User not found';
        LEAVE proc_body;
    END IF;
    
    IF NOT v_is_active THEN
        SET p_error_code = 'ERR_USER_INACTIVE';
        SET p_error_message = 'User account is inactive';
        LEAVE proc_body;
    END IF;
    
    -- Owners have all permissions
    IF v_is_owner THEN
        SET p_has_permission = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Permission granted (Owner)';
        LEAVE proc_body;
    END IF;
    
    -- Check if role has the required permission
    SELECT COUNT(*) INTO v_permission_count
    FROM role_permission rp
    JOIN master_permission mp ON rp.permission_id = mp.master_permission_id
    WHERE rp.role_id = v_role_id
      AND mp.code = p_permission_code
      AND rp.is_granted = 1
      AND mp.is_active = 1;
    
    IF v_permission_count > 0 THEN
        SET p_has_permission = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Permission granted';
    ELSE
        SET p_has_permission = FALSE;
        SET p_error_code = 'ERR_PERMISSION_DENIED';
        SET p_error_message = CONCAT('Permission denied: ', p_permission_code);
    END IF;
    
END;