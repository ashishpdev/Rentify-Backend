DROP PROCEDURE IF EXISTS sp_action_return_rental;
CREATE PROCEDURE sp_action_return_rental(
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_rental_id INT,
    IN  p_end_date TIMESTAMP(6),
    IN  p_notes TEXT,
    IN  p_user_id INT,
    IN  p_role_id INT,
    OUT p_success BOOLEAN,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(1000)
)
proc_exit: BEGIN

    DECLARE v_role_id INT DEFAULT NULL;
    DECLARE v_returned_status INT;
    DECLARE v_available_status INT;

    SET p_success = FALSE;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    IF p_rental_id IS NULL OR p_rental_id <= 0 THEN
      SET p_error_code = 'ERR_INVALID_RENTAL_ID';
      SET p_error_message = 'Valid rental_id is required.';
      LEAVE proc_exit;
    END IF;

    IF p_end_date IS NULL THEN
      SET p_error_code = 'ERR_INVALID_END_DATE';
      SET p_error_message = 'end_date is required.';
      LEAVE proc_exit;
    END IF;

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
      SET p_error_message = 'User does not have permission to return rentals.';
      LEAVE proc_exit;
    END IF;

    SELECT product_rental_status_id INTO v_returned_status
    FROM product_rental_status WHERE code='RETURNED' LIMIT 1;

    SELECT product_status_id INTO v_available_status
    FROM product_status WHERE code='AVAILABLE' LIMIT 1;

    IF v_returned_status IS NULL OR v_available_status IS NULL THEN
      SET p_error_code = 'ERR_LOOKUP_MISSING';
      SET p_error_message = 'Required lookup rows missing.';
      LEAVE proc_exit;
    END IF;

    START TRANSACTION;

    -- lock header
    IF NOT EXISTS (
      SELECT 1
      FROM rental r
      WHERE r.rental_id = p_rental_id
        AND r.business_id = p_business_id
        AND (p_branch_id IS NULL OR r.branch_id = p_branch_id)
        AND r.is_deleted = 0
      FOR UPDATE
    ) THEN
      ROLLBACK;
      SET p_error_code = 'ERR_NOT_FOUND';
      SET p_error_message = 'Rental not found.';
      LEAVE proc_exit;
    END IF;

    UPDATE rental r
    SET r.end_date = p_end_date,
        r.product_rental_status_id = v_returned_status,
        r.notes = CONCAT(IFNULL(r.notes,''), IF(p_notes IS NULL OR TRIM(p_notes)='', '', '\n'), IFNULL(p_notes,'')),
        r.updated_by = p_user_id,
        r.updated_at = UTC_TIMESTAMP(6)
    WHERE r.rental_id = p_rental_id;

    UPDATE rental_item ri
    SET ri.product_rental_status_id = v_returned_status,
        ri.updated_by = p_user_id,
        ri.updated_at = UTC_TIMESTAMP(6)
    WHERE ri.rental_id = p_rental_id;

    -- update assets back to available in bulk
    UPDATE asset a
    JOIN rental_item ri ON ri.asset_id = a.asset_id AND ri.rental_id = p_rental_id
    SET a.product_status_id = v_available_status,
        a.updated_by = p_user_id,
        a.updated_at = UTC_TIMESTAMP(6);

    COMMIT;

    SET p_success = TRUE;
    SET p_error_code = 'SUCCESS';
    SET p_error_message = 'Rental returned successfully.';

END proc_exit;
