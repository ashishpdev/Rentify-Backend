DROP PROCEDURE IF EXISTS sp_logout;
CREATE PROCEDURE sp_logout(
    IN p_user_id INT,
    OUT p_is_success BOOLEAN,
    OUT p_error_message VARCHAR(500)
)
BEGIN
    DECLARE v_ok INT DEFAULT 1;

    -- Error handler for rollback
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_is_success = FALSE;
        SET p_error_message = 'An error occurred. Transaction rolled back.';
        SET v_ok = 0;
    END;

    START TRANSACTION;

    SET p_is_success = FALSE;
    SET p_error_message = NULL;

    -- Check if user_id is provided
    IF p_user_id IS NULL OR p_user_id <= 0 THEN
        SET p_error_message = 'Invalid user ID';
        SET v_ok = 0;
    END IF;

    -- Delete session for this user
    IF v_ok = 1 THEN
        DELETE FROM master_user_session
         WHERE user_id = p_user_id;

        SET p_is_success = TRUE;
        SET p_error_message = 'Logout successful';
    END IF;

    -- Commit or rollback
    IF v_ok = 1 THEN
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;
END;
