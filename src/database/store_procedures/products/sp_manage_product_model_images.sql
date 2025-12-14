DROP PROCEDURE IF EXISTS sp_manage_product_model_images;
CREATE PROCEDURE sp_manage_product_model_images(
    IN  p_action INT,                      -- 1=Create, 2=Update, 3=Delete, 4=Get Single, 5=Get All by Product Model
    IN  p_product_model_image_id INT,
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_product_model_id INT,
    IN  p_url VARCHAR(1024),
    IN  p_alt_text VARCHAR(512),
    IN  p_is_primary TINYINT(1),
    IN  p_image_order INT, 
    IN  p_user_id VARCHAR(255),

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    -- DECLARATIONS
    DECLARE v_existing_image INT DEFAULT 0;
    DECLARE v_user_role_id INT DEFAULT NULL;
    DECLARE v_old_order INT DEFAULT NULL;
    DECLARE v_max_order INT DEFAULT 0;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- ==================================================================================
    /* Exception Handling */
    -- ==================================================================================
    
    -- Specific Handler: Foreign Key Violation
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_FK_VIOLATION';
        SET p_error_message = 'Foreign key violation (likely missing reference).';
    END;

    -- Specific Handler: Duplicate Key
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_DUPLICATE';
        SET p_error_message = 'Duplicate key error (unique constraint).';
    END;

    -- Generic Handler: SQLEXCEPTION
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;

        IF v_cno > 0 THEN
            GET DIAGNOSTICS CONDITION 1
                v_errno     = MYSQL_ERRNO,
                v_sql_state = RETURNED_SQLSTATE,
                v_error_msg = MESSAGE_TEXT;
        ELSE
            SET v_errno = NULL;
            SET v_sql_state = NULL;
            SET v_error_msg = 'No diagnostics available';
        END IF;

        ROLLBACK;

        -- Log error details
        INSERT INTO proc_error_log(
            proc_name, 
            proc_args, 
            mysql_errno, 
            sql_state, 
            error_message
        )
        VALUES (
            'sp_manage_product_model_images',
            CONCAT('p_action=', IFNULL(p_action, 'NULL'), ', p_product_model_image_id=', IFNULL(p_product_model_image_id, 'NULL'), ', p_product_model_id=', IFNULL(p_product_model_id, 'NULL'), ', p_image_order=', IFNULL(p_image_order, 'NULL')),
            v_errno,
            v_sql_state,
            LEFT(v_error_msg, 2000)
        );

        -- Safe return message
        SET p_success = FALSE;
        SET p_error_code = 'ERR_EXCEPTION';
        SET p_error_message = CONCAT(
            'Error logged (errno=', IFNULL(CAST(v_errno AS CHAR), '?'),
            ', sqlstate=', IFNULL(v_sql_state, '?'), '). See proc_error_log.'
        );
    END;

    -- RESET OUTPUT PARAMETERS
    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- ==================================================================================
    /* ACTION 1: CREATE */
    -- ==================================================================================

    IF p_action = 1 THEN

        -- Validate required fields
        IF p_business_id IS NULL THEN
            SET p_error_code = 'ERR_MISSING_BUSINESS';
            SET p_error_message = 'Business ID is required.';
            LEAVE proc_body;
        END IF;

        IF p_branch_id IS NULL THEN
            SET p_error_code = 'ERR_MISSING_BRANCH';
            SET p_error_message = 'Branch ID is required.';
            LEAVE proc_body;
        END IF;

        IF p_url IS NULL OR p_url = '' THEN
            SET p_error_code = 'ERR_MISSING_URL';
            SET p_error_message = 'Image URL is required.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        -- If this image is marked as primary, unset other primary images for this product model
        IF p_is_primary = 1 AND p_product_model_id IS NOT NULL THEN
            UPDATE product_model_images
            SET is_primary = 0,
                updated_by = p_user_id
            WHERE product_model_id = p_product_model_id
                AND business_id = p_business_id
                AND branch_id = p_branch_id
                AND is_deleted = 0;
        END IF;

        IF p_image_order IS NULL THEN
            SELECT COALESCE(MAX(image_order), 0) + 1 INTO v_max_order
            FROM product_model_images
            WHERE product_model_id <=> p_product_model_id
              AND business_id = p_business_id
              AND branch_id = p_branch_id
              AND is_deleted = 0;
            SET p_image_order = v_max_order;
        ELSE
            -- shift others (>= requested position)
            UPDATE product_model_images
            SET image_order = image_order + 1
            WHERE product_model_id = p_product_model_id
              AND business_id = p_business_id
              AND branch_id = p_branch_id
              AND image_order >= p_image_order
              AND is_deleted = 0;
        END IF;

        -- Insert product model image
        INSERT INTO product_model_images (
            business_id, branch_id, product_model_id,
            url, alt_text, is_primary, image_order,
            created_by
        )
        VALUES (
            p_business_id, p_branch_id, p_product_model_id,
            p_url, p_alt_text, p_is_primary, p_image_order,
            p_user_id
        );

        COMMIT;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model image created successfully.';
        LEAVE proc_body;
    END IF;


    -- ==================================================================================
    /* ACTION 2: UPDATE */
    -- ==================================================================================

    IF p_action = 2 THEN

        IF p_product_model_image_id IS NULL THEN
            SET p_error_code = 'ERR_MISSING_ID';
            SET p_error_message = 'Product image ID is required for update.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        -- ensure the record exists and fetch old order
        SELECT image_order
        INTO v_old_order
        FROM product_model_images
        WHERE product_model_image_id = p_product_model_image_id
            AND business_id = p_business_id
            AND branch_id = p_branch_id
            AND is_deleted = 0
        LIMIT 1;

        IF v_old_order IS NULL THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product model image not found or already deleted.';
            LEAVE proc_body;
        END IF;

        -- If this image is marked as primary, unset other primary images for this product model
        IF p_is_primary = 1 AND p_product_model_id IS NOT NULL THEN
            UPDATE product_model_images
            SET is_primary = 0,
                updated_by = p_user_id
             WHERE product_model_id <=> p_product_model_id
              AND business_id = p_business_id
              AND branch_id = p_branch_id
              AND is_deleted = 0
              AND product_model_image_id != p_product_model_image_id;
        END IF;

         -- If image order is provided and different, reposition others
        IF p_image_order IS NOT NULL AND p_image_order != v_old_order THEN
            -- If moving down (to higher order number), decrement middle items
            IF p_image_order > v_old_order THEN
                UPDATE product_model_images
                SET image_order = image_order - 1,
                    updated_by = p_user_id
                WHERE product_model_id <=> p_product_model_id
                  AND business_id = p_business_id
                  AND branch_id = p_branch_id
                  AND is_deleted = 0
                  AND image_order > v_old_order
                  AND image_order <= p_image_order
                  AND product_model_image_id != p_product_model_image_id;
            ELSE
                -- moving up (to lower order number): increment middle items
                UPDATE product_model_images
                SET image_order = image_order + 1,
                    updated_by = p_user_id
                WHERE product_model_id <=> p_product_model_id
                  AND business_id = p_business_id
                  AND branch_id = p_branch_id
                  AND is_deleted = 0
                  AND image_order >= p_image_order
                  AND image_order < v_old_order
                  AND product_model_image_id != p_product_model_image_id;
            END IF;
        END IF;

        UPDATE product_model_images
        SET 
            product_model_id = IFNULL(p_product_model_id, product_model_id),
            url = IFNULL(p_url, url),
            alt_text = IFNULL(p_alt_text, alt_text),
            is_primary = IFNULL(p_is_primary, is_primary),
            image_order = IFNULL(p_image_order, image_order),
            updated_by = p_user_id
        WHERE product_model_image_id = p_product_model_image_id 
          AND business_id = p_business_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product model image not found or already deleted.';
            LEAVE proc_body;
        END IF;

        COMMIT;

        SET p_id = p_product_model_image_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model image updated successfully.';
        LEAVE proc_body;
    END IF;


    -- ==================================================================================
    /* ACTION 3: DELETE (Soft Delete) */
    -- ==================================================================================
    IF p_action = 3 THEN

        IF p_product_model_image_id IS NULL THEN
            SET p_error_code = 'ERR_MISSING_ID';
            SET p_error_message = 'Product image ID is required for delete.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        -- Get old order (to collapse gap)
        SELECT image_order, product_model_id
        INTO v_old_order, v_existing_image
        FROM product_model_images
        WHERE product_model_image_id = p_product_model_image_id
          AND business_id = p_business_id
          AND is_deleted = 0
        LIMIT 1;

        IF v_old_order IS NULL THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product model image not found or already deleted.';
            LEAVE proc_body;
        END IF;

        UPDATE product_model_images
        SET 
            is_deleted = 1,
            is_active = FALSE,
            deleted_at = UTC_TIMESTAMP(6),
            updated_by = p_user_id
        WHERE product_model_image_id = p_product_model_image_id 
          AND business_id = p_business_id
          AND is_deleted = 0;

        IF ROW_COUNT() = 0 THEN
            ROLLBACK;
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product model image not found or already deleted.';
            LEAVE proc_body;
        END IF;

        -- Collapse gap: decrement orders greater than the removed one for same product_model+business+branch
        UPDATE product_model_images
        SET image_order = image_order - 1,
            updated_by = p_user_id
        WHERE product_model_id <=> v_existing_image
          AND business_id = p_business_id
          AND branch_id = p_branch_id
          AND is_deleted = 0
          AND image_order > v_old_order;

        COMMIT;

        SET p_id = p_product_model_image_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model image deleted successfully.';
        LEAVE proc_body;
    END IF;

    -- ==================================================================================
    /* ACTION 4: GET */
    -- ==================================================================================
     IF p_action = 4 THEN

        IF p_product_model_image_id IS NULL THEN
            SET p_error_code = 'ERR_MISSING_ID';
            SET p_error_message = 'Product image ID is required.';
            LEAVE proc_body;
        END IF;

        SELECT JSON_OBJECT(
            'product_model_image_id', product_model_image_id,
            'business_id', business_id,
            'branch_id', branch_id,
            'product_model_id', product_model_id,
            'url', url,
            'alt_text', alt_text,
            'is_primary', is_primary,
            'image_order', image_order,
            'is_active', is_active,
            'created_by', created_by,
            'created_at', created_at,
            'updated_by', updated_by,
            'updated_at', updated_at
        )
        INTO p_data
        FROM product_model_images
        WHERE product_model_image_id = p_product_model_image_id 
          AND business_id = p_business_id
          AND is_deleted = 0
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Product model image not found.';
            LEAVE proc_body;
        END IF;

        SET p_id = p_product_model_image_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model image details fetched successfully.';
        LEAVE proc_body;
    END IF;


    -- ==================================================================================
    /* ACTION 5: GET LIST (by product model) */
    -- ==================================================================================
    IF p_action = 5 THEN

        IF p_product_model_id IS NULL THEN
            SET p_error_code = 'ERR_MISSING_PRODUCT_MODEL';
            SET p_error_message = 'Product model ID is required.';
            LEAVE proc_body;
        END IF;

        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'product_model_image_id', product_model_image_id,
                'business_id', business_id,
                'branch_id', branch_id,
                'product_model_id', product_model_id,
                'url', url,
                'alt_text', alt_text,
                'is_primary', is_primary,
                'image_order', image_order,
                'is_active', is_active,
                'created_by', created_by,
                'created_at', created_at,
                'updated_by', updated_by,
                'updated_at', updated_at
            )
            ORDER BY is_primary DESC, image_order ASC, created_at ASC
        )
        INTO p_data
        FROM product_model_images
        WHERE product_model_id = p_product_model_id 
          AND business_id = p_business_id
          AND is_deleted = 0;

        IF p_data IS NULL THEN
            SET p_data = JSON_ARRAY();
        END IF;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model images fetched successfully.';
        LEAVE proc_body;
    END IF;



    -- INVALID ACTION
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action specified.';

END;
