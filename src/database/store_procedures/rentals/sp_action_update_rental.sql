DROP PROCEDURE IF EXISTS sp_action_update_rental;
CREATE PROCEDURE sp_action_update_rental(
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_rental_id INT,
    IN  p_due_date TIMESTAMP(6),
    IN  p_notes TEXT,
    IN  p_product_rental_status_id INT,
    IN  p_user_id INT,
    IN  p_role_id INT,
    OUT p_success BOOLEAN,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(1000)
)
proc_exit: BEGIN

    DECLARE v_role_id INT DEFAULT NULL;

    SET p_success = FALSE;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_rental_id IS NULL OR p_rental_id <= 0 THEN
      SET p_error_code = 'ERR_INVALID_RENTAL_ID';
      SET p_error_message = 'Valid rental_id is required.';
      LEAVE proc_exit;
    END IF;

    -- role validation (match pattern used by customer SP)
    SELECT role_id INTO v_role_id
    FROM master_user
    WHERE role_id = p_role_id
    LIMIT 1;

    IF v_role_id IS NULL THEN
      SET p_error_code = 'ERR_ROLE_NOT_FOUND';
      SET p_error_message = 'Role not found.';
      LEAVE proc_exit;
    END IF;

    IF v_role_id NOT IN (1,2,3) THEN
      SET p_error_code = 'ERR_PERMISSION_DENIED';
      SET p_error_message = 'User does not have permission to update rentals.';
      LEAVE proc_exit;
    END IF;

    START TRANSACTION;

    UPDATE rental r
    SET
      r.due_date = COALESCE(p_due_date, r.due_date),
      r.notes = COALESCE(p_notes, r.notes),
      r.product_rental_status_id = COALESCE(p_product_rental_status_id, r.product_rental_status_id),
      r.updated_by = p_user_id,
      r.updated_at = UTC_TIMESTAMP(6)
    WHERE r.rental_id = p_rental_id
      AND r.business_id = p_business_id
      AND (p_branch_id IS NULL OR r.branch_id = p_branch_id)
      AND r.is_deleted = 0;

    IF ROW_COUNT() = 0 THEN
      ROLLBACK;
      SET p_error_code = 'ERR_NOT_FOUND';
      SET p_error_message = 'Rental not found or no changes made.';
      LEAVE proc_exit;
    END IF;

    COMMIT;

    SET p_success = TRUE;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Rental updated successfully.';

END proc_exit;
