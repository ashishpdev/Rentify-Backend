DROP PROCEDURE IF EXISTS sp_get_user_permissions;
CREATE PROCEDURE sp_get_user_permissions(
    IN p_user_id INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            @sqlstate = RETURNED_SQLSTATE,
            @errno = MYSQL_ERRNO,
            @text = MESSAGE_TEXT;
        
        CALL sp_log_proc_error('sp_get_user_permissions', @errno, @text);
        RESIGNAL;
    END;

    -- Get all permissions for the user based on their role
    SELECT DISTINCT
        mp.master_permission_id as permission_id,
        mp.code,
        mp.name,
        mp.module,
        mp.action
    FROM master_user u
    JOIN role_permission rp ON u.role_id = rp.role_id
    JOIN master_permission mp ON rp.permission_id = mp.master_permission_id
    WHERE u.master_user_id = p_user_id
      AND u.is_active = 1
      AND u.deleted_at IS NULL
      AND rp.is_granted = 1
      AND mp.is_active = 1
    ORDER BY mp.module, mp.action;

END;