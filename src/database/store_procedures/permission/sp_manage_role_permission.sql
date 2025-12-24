DROP PROCEDURE IF EXISTS sp_manage_role_permission;
CREATE PROCEDURE sp_manage_role_permission(
    IN p_action INT,                    -- 1=Assign, 2=Revoke, 3=Get Role Permissions
    IN p_role_id TINYINT,
    IN p_permission_id INT,
    IN p_user_id INT,

    OUT p_success BOOLEAN,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN
    
    DECLARE v_has_permission BOOLEAN DEFAULT FALSE;
    DECLARE v_perm_error_code VARCHAR(50);
    DECLARE v_perm_error_msg VARCHAR(500);
    
    SET p_success = FALSE;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- Only owners can manage role permissions
    CALL sp_check_permission(p_user_id, 'MANAGE_PERMISSION', v_has_permission, v_perm_error_code, v_perm_error_msg);
    
    IF NOT v_has_permission THEN
        SET p_error_code = 'ERR_PERMISSION_DENIED';
        SET p_error_message = 'Insufficient privileges';
        LEAVE proc_body;
    END IF;

    IF p_action = 1 THEN
        -- Assign permission
        INSERT INTO role_permission (role_id, permission_id, is_granted)
        VALUES (p_role_id, p_permission_id, 1)
        ON DUPLICATE KEY UPDATE is_granted = 1, updated_at = UTC_TIMESTAMP(6);
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Permission assigned to role';
        
    ELSEIF p_action = 2 THEN
        -- Revoke permission
        DELETE FROM role_permission 
        WHERE role_id = p_role_id AND permission_id = p_permission_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Permission revoked from role';
        
    ELSEIF p_action = 3 THEN
        -- Get all permissions for role
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'permission_id', mp.master_permission_id,
                'code', mp.code,
                'name', mp.name,
                'module', mp.module,
                'action', mp.action,
                'is_granted', rp.is_granted
            )
        )
        INTO p_data
        FROM role_permission rp
        JOIN master_permission mp ON rp.permission_id = mp.master_permission_id
        WHERE rp.role_id = p_role_id AND mp.is_active = 1;
        
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Role permissions retrieved';
    END IF;

END;