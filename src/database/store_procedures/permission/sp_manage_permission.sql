DROP PROCEDURE IF EXISTS sp_manage_permission;
CREATE PROCEDURE sp_manage_permission(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete, 4=Get, 5=List All
    IN p_permission_id INT,
    IN p_code VARCHAR(100),
    IN p_name VARCHAR(255),
    IN p_module VARCHAR(100),
    IN p_action_type VARCHAR(50),
    IN p_description TEXT,
    IN p_user_id INT,

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN
    
    DECLARE v_has_permission BOOLEAN DEFAULT FALSE;
    DECLARE v_perm_error_code VARCHAR(50);
    DECLARE v_perm_error_msg VARCHAR(500);
    
    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- Only owners can manage permissions
    CALL sp_check_permission(p_user_id, 'MANAGE_PERMISSION', v_has_permission, v_perm_error_code, v_perm_error_msg);
    
    IF NOT v_has_permission THEN
        SET p_error_code = 'ERR_PERMISSION_DENIED';
        SET p_error_message = 'Only system administrators can manage permissions';
        LEAVE proc_body;
    END IF;

    IF p_action = 1 THEN
        INSERT INTO master_permission (code, name, module, action, description)
        VALUES (p_code, p_name, p_module, p_action_type, p_description);
        SET p_id = LAST_INSERT_ID();
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Permission created';
    ELSEIF p_action = 2 THEN
        UPDATE master_permission
        SET name = p_name, description = p_description, updated_at = UTC_TIMESTAMP(6)
        WHERE master_permission_id = p_permission_id;
        SET p_id = p_permission_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Permission updated';
    ELSEIF p_action = 3 THEN
        UPDATE master_permission SET is_active = 0 WHERE master_permission_id = p_permission_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Permission deactivated';
    ELSEIF p_action = 4 THEN
        SELECT JSON_OBJECT('id', master_permission_id, 'code', code, 'name', name,
                          'module', module, 'action', action, 'description', description)
        INTO p_data FROM master_permission WHERE master_permission_id = p_permission_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
    ELSEIF p_action = 5 THEN
        SELECT JSON_ARRAYAGG(JSON_OBJECT('id', master_permission_id, 'code', code, 
                                        'name', name, 'module', module, 'action', action))
        INTO p_data FROM master_permission WHERE is_active = 1 ORDER BY module, action;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
    END IF;

END;