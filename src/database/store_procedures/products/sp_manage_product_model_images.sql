DROP PROCEDURE IF EXISTS sp_manage_product_model_images;
CREATE PROCEDURE sp_manage_product_model_images(
    IN  p_action INT,                      -- 1=Create,2=Update,3=Delete,4=Get Single,5=Get All by Product Model
    IN  p_product_model_image_id INT,
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_product_model_id INT,
    IN  p_url VARCHAR(1024),
    IN  p_thumbnail_url VARCHAR(1024),
    IN  p_alt_text VARCHAR(512),
    IN  p_file_size_bytes INT,
    IN  p_width_px SMALLINT,
    IN  p_height_px SMALLINT,
    IN  p_is_primary TINYINT(1),
    IN  p_image_order INT,
    IN  p_product_model_image_category_id TINYINT UNSIGNED,
    IN  p_user_id VARCHAR(255),

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN
    DECLARE v_old_order INT DEFAULT NULL;
    DECLARE v_existing_model INT DEFAULT NULL;
    DECLARE v_max_order INT DEFAULT 0;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- Handlers
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_FK_VIOLATION';
        SET p_error_message = 'Foreign key violation.';
    END;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_DUPLICATE';
        SET p_error_message = 'Duplicate key error.';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;
        IF v_cno > 0 THEN
            GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_sql_state = RETURNED_SQLSTATE, v_error_msg = MESSAGE_TEXT;
        END IF;
        ROLLBACK;
        INSERT INTO proc_error_log(proc_name, proc_args, mysql_errno, sql_state, error_message)
        VALUES ('sp_manage_product_model_images', CONCAT('action=', p_action, ', img_id=', IFNULL(p_product_model_image_id,'NULL')), v_errno, v_sql_state, LEFT(v_error_msg,2000));
        SET p_success = FALSE;
        SET p_error_code = 'ERR_EXCEPTION';
        SET p_error_message = 'Internal error. See proc_error_log.';
    END;

    -- Reset outputs
    SET p_success = FALSE; SET p_id = NULL; SET p_data = NULL; SET p_error_code = NULL; SET p_error_message = NULL;

    /* ACTION 1: CREATE */
    IF p_action = 1 THEN
        IF p_business_id IS NULL OR p_branch_id IS NULL OR p_product_model_id IS NULL OR p_url IS NULL OR p_url = '' THEN
            SET p_error_code = 'ERR_MISSING_PARAMS';
            SET p_error_message = 'Missing required fields.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        IF p_is_primary = 1 THEN
            UPDATE product_model_images
            SET is_primary = 0, updated_by = p_user_id
            WHERE product_model_id = p_product_model_id AND business_id = p_business_id AND branch_id = p_branch_id AND is_active = 1;
        END IF;

        IF p_image_order IS NULL THEN
            SELECT COALESCE(MAX(image_order), 0) + 1 INTO v_max_order
            FROM product_model_images
            WHERE product_model_id = p_product_model_id AND business_id = p_business_id AND branch_id = p_branch_id AND is_active = 1;
            SET p_image_order = v_max_order;
        ELSE
            UPDATE product_model_images
            SET image_order = image_order + 1, updated_by = p_user_id
            WHERE product_model_id = p_product_model_id AND business_id = p_business_id AND branch_id = p_branch_id AND image_order >= p_image_order AND is_active = 1;
        END IF;

        INSERT INTO product_model_images (
            business_id, branch_id, product_model_id, url, thumbnail_url, alt_text,
            file_size_bytes, width_px, height_px, is_primary, image_order, product_model_image_category_id, created_by
        ) VALUES (
            p_business_id, p_branch_id, p_product_model_id, p_url, p_thumbnail_url, p_alt_text,
            p_file_size_bytes, p_width_px, p_height_px, p_is_primary, p_image_order, p_product_model_image_category_id, p_user_id
        );

        SET p_id = LAST_INSERT_ID();

        COMMIT;
        SET p_success = TRUE; SET p_error_code = 'SUCCESS'; SET p_error_message = 'Image created';
        LEAVE proc_body;
    END IF;

    /* ACTION 2: UPDATE */
    IF p_action = 2 THEN
        IF p_product_model_image_id IS NULL THEN
            SET p_error_code = 'ERR_MISSING_ID';
            SET p_error_message = 'Image ID is required.'; LEAVE proc_body;
        END IF;

        START TRANSACTION;

        SELECT image_order, product_model_id INTO v_old_order, v_existing_model
        FROM product_model_images
        WHERE product_model_image_id = p_product_model_image_id AND business_id = p_business_id AND branch_id = p_branch_id AND is_active = 1
        LIMIT 1;

        IF v_old_order IS NULL THEN ROLLBACK; SET p_error_code='ERR_NOT_FOUND'; SET p_error_message='Image not found'; LEAVE proc_body; END IF;

        IF p_is_primary = 1 THEN
            UPDATE product_model_images
            SET is_primary = 0, updated_by = p_user_id
            WHERE product_model_id = v_existing_model AND business_id = p_business_id AND branch_id = p_branch_id AND is_active = 1 AND product_model_image_id != p_product_model_image_id;
        END IF;

        IF p_image_order IS NOT NULL AND p_image_order != v_old_order THEN
            IF p_image_order > v_old_order THEN
                UPDATE product_model_images SET image_order = image_order - 1, updated_by = p_user_id
                WHERE product_model_id = v_existing_model AND business_id = p_business_id AND branch_id = p_branch_id AND is_active = 1 AND image_order > v_old_order AND image_order <= p_image_order AND product_model_image_id != p_product_model_image_id;
            ELSE
                UPDATE product_model_images SET image_order = image_order + 1, updated_by = p_user_id
                WHERE product_model_id = v_existing_model AND business_id = p_business_id AND branch_id = p_branch_id AND is_active = 1 AND image_order >= p_image_order AND image_order < v_old_order AND product_model_image_id != p_product_model_image_id;
            END IF;
        END IF;

        UPDATE product_model_images
        SET url = COALESCE(p_url, url),
            thumbnail_url = COALESCE(p_thumbnail_url, thumbnail_url),
            alt_text = COALESCE(p_alt_text, alt_text),
            file_size_bytes = COALESCE(p_file_size_bytes, file_size_bytes),
            width_px = COALESCE(p_width_px, width_px),
            height_px = COALESCE(p_height_px, height_px),
            is_primary = COALESCE(p_is_primary, is_primary),
            image_order = COALESCE(p_image_order, image_order),
            product_model_image_category_id = p_product_model_image_category_id,
            updated_by = p_user_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE product_model_image_id = p_product_model_image_id AND business_id = p_business_id AND is_active = 1;

        IF ROW_COUNT() = 0 THEN ROLLBACK; SET p_error_code='ERR_NOT_FOUND'; SET p_error_message='Image not found or already deleted'; LEAVE proc_body; END IF;

        COMMIT; SET p_success=TRUE; SET p_id=p_product_model_image_id; SET p_error_code='SUCCESS'; SET p_error_message='Image updated'; LEAVE proc_body;
    END IF;

    /* ACTION 3: DELETE */
    IF p_action = 3 THEN
        IF p_product_model_image_id IS NULL THEN SET p_error_code='ERR_MISSING_ID'; SET p_error_message='Image ID required'; LEAVE proc_body; END IF;

        START TRANSACTION;

        SELECT image_order, product_model_id, url INTO v_old_order, v_existing_model, p_data
        FROM product_model_images
        WHERE product_model_image_id = p_product_model_image_id AND business_id = p_business_id AND is_active = 1
        LIMIT 1;

        IF v_old_order IS NULL THEN ROLLBACK; SET p_error_code='ERR_NOT_FOUND'; SET p_error_message='Image not found'; LEAVE proc_body; END IF;

        UPDATE product_model_images
        SET is_active = 0, deleted_at = UTC_TIMESTAMP(6), updated_by = p_user_id
        WHERE product_model_image_id = p_product_model_image_id AND business_id = p_business_id AND is_active = 1;

        UPDATE product_model_images
        SET image_order = image_order - 1, updated_by = p_user_id
        WHERE product_model_id = v_existing_model AND business_id = p_business_id AND branch_id = p_branch_id AND is_active = 1 AND image_order > v_old_order;

        COMMIT;
        SET p_success=TRUE; SET p_id=p_product_model_image_id; SET p_error_code='SUCCESS'; SET p_error_message='Image deleted'; LEAVE proc_body;
    END IF;

    /* ACTION 4: GET */
    IF p_action = 4 THEN
        IF p_product_model_image_id IS NULL THEN SET p_error_code='ERR_MISSING_ID'; SET p_error_message='Image ID required'; LEAVE proc_body; END IF;

        SELECT JSON_OBJECT(
            'product_model_image_id', product_model_image_id,
            'business_id', business_id,
            'branch_id', branch_id,
            'product_model_id', product_model_id,
            'url', url,
            'thumbnail_url', thumbnail_url,
            'alt_text', alt_text,
            'file_size_bytes', file_size_bytes,
            'width_px', width_px,
            'height_px', height_px,
            'is_primary', is_primary,
            'image_order', image_order,
            'product_model_image_category_id', product_model_image_category_id,
            'is_active', is_active,
            'created_by', created_by,
            'created_at', created_at,
            'updated_by', updated_by,
            'updated_at', updated_at
        ) INTO p_data
        FROM product_model_images
        WHERE product_model_image_id = p_product_model_image_id AND business_id = p_business_id AND is_active = 1
        LIMIT 1;

        IF p_data IS NULL THEN SET p_error_code='ERR_NOT_FOUND'; SET p_error_message='Image not found'; LEAVE proc_body; END IF;

        SET p_success=TRUE; SET p_id=p_product_model_image_id; SET p_error_code='SUCCESS'; SET p_error_message='Image fetched'; LEAVE proc_body;
    END IF;

    /* ACTION 5: GET ALL */
    IF p_action = 5 THEN
        IF p_product_model_id IS NULL THEN SET p_error_code='ERR_MISSING_PRODUCT_MODEL'; SET p_error_message='Product model ID required'; LEAVE proc_body; END IF;

        SELECT IFNULL(JSON_ARRAYAGG(
            JSON_OBJECT(
                'product_model_image_id', product_model_image_id,
                'business_id', business_id,
                'branch_id', branch_id,
                'product_model_id', product_model_id,
                'url', url,
                'thumbnail_url', thumbnail_url,
                'alt_text', alt_text,
                'file_size_bytes', file_size_bytes,
                'width_px', width_px,
                'height_px', height_px,
                'is_primary', is_primary,
                'image_order', image_order,
                'product_model_image_category_id', product_model_image_category_id,
                'is_active', is_active,
                'created_by', created_by,
                'created_at', created_at,
                'updated_by', updated_by,
                'updated_at', updated_at
            )
            ORDER BY is_primary DESC, image_order ASC, created_at ASC
        ), JSON_ARRAY()) INTO p_data
        FROM product_model_images
        WHERE product_model_id = p_product_model_id AND business_id = p_business_id AND is_active = 1;

        SET p_success=TRUE; SET p_error_code='SUCCESS'; SET p_error_message='Images fetched'; LEAVE proc_body;
    END IF;

    SET p_error_code='ERR_INVALID_ACTION'; SET p_error_message='Invalid action';
END;