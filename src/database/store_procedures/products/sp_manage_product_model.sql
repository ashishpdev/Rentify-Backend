DROP PROCEDURE IF EXISTS sp_manage_product_model;
CREATE PROCEDURE sp_manage_product_model(
    IN  p_action INT,                          -- 1=Create,2=Update,3=Delete,4=GetSingle,5=GetAll
    IN  p_product_model_id INT,
    IN  p_business_id INT,
    IN  p_branch_id INT,
    IN  p_product_segment_id INT,
    IN  p_product_category_id INT,
    IN  p_model_name VARCHAR(255),
    IN  p_description TEXT,
    IN  p_product_model_images JSON,
    IN  p_default_rent DECIMAL(12,2),
    IN  p_default_deposit DECIMAL(12,2),
    IN  p_default_sell DECIMAL(12,2),
    IN  p_default_warranty_days INT,
    IN  p_user_id INT,
    IN  p_role_id INT,

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN
    DECLARE v_role_id INT DEFAULT NULL;
    DECLARE v_exist INT DEFAULT 0;
    DECLARE v_product_id INT DEFAULT NULL;
    DECLARE v_images_json JSON DEFAULT NULL;
    DECLARE v_img JSON DEFAULT NULL;
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_len INT DEFAULT 0;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;

    -- Handlers
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE; SET p_error_code = 'ERR_FK'; SET p_error_message = 'Foreign key violation.';
    END;

    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_success = FALSE; SET p_error_code = 'ERR_DUPLICATE'; SET p_error_message = 'Duplicate key.';
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS v_cno = NUMBER;
        IF v_cno > 0 THEN
            GET DIAGNOSTICS CONDITION 1 v_errno = MYSQL_ERRNO, v_sql_state = RETURNED_SQLSTATE, v_error_msg = MESSAGE_TEXT;
        END IF;
        ROLLBACK;
        INSERT INTO proc_error_log(proc_name, proc_args, mysql_errno, sql_state, error_message)
        VALUES ('sp_manage_product_model', CONCAT('action=', p_action, ', model_id=', IFNULL(p_product_model_id,'NULL')), v_errno, v_sql_state, LEFT(v_error_msg,2000));
        SET p_success = FALSE; SET p_error_code = 'ERR_EXCEPTION'; SET p_error_message = 'Internal error. See proc_error_log.';
    END;

    SET p_success = FALSE; SET p_id = NULL; SET p_data = NULL; SET p_error_code = NULL; SET p_error_message = NULL;

    -- role check
    SELECT role_id INTO v_role_id FROM master_user WHERE role_id = p_role_id LIMIT 1;
    IF v_role_id IS NULL THEN SET p_error_code='ERR_ROLE_NOT_FOUND'; SET p_error_message='Role not found.'; LEAVE proc_body; END IF;
    IF p_action IN (1,2,3) AND v_role_id NOT IN (1,2,3) THEN SET p_error_code='ERR_PERMISSION_DENIED'; SET p_error_message='Permission denied.'; LEAVE proc_body; END IF;

    /* 1: CREATE */
    IF p_action = 1 THEN
        SELECT COUNT(*) INTO v_exist FROM product_model
        WHERE business_id = p_business_id AND branch_id = p_branch_id
          AND product_segment_id = p_product_segment_id AND product_category_id = p_product_category_id
          AND model_name = p_model_name AND is_active = 1;

        IF v_exist > 0 THEN SET p_error_code='ERR_DUPLICATE'; SET p_error_message='Model already exists.'; LEAVE proc_body; END IF;

        START TRANSACTION;

        INSERT INTO product_model (
            business_id, branch_id, product_segment_id, product_category_id,
            model_name, description, default_rent_price, default_deposit,
            default_sell_price, default_warranty_days, created_by, is_active
        ) VALUES (
            p_business_id, p_branch_id, p_product_segment_id, p_product_category_id,
            p_model_name, p_description, p_default_rent, p_default_deposit,
            p_default_sell, p_default_warranty_days, p_user_id, 1
        );

        SET v_product_id = LAST_INSERT_ID();
        SET p_id = v_product_id;

        -- images if provided
        IF p_product_model_images IS NOT NULL AND JSON_LENGTH(p_product_model_images) > 0 THEN
            SET v_len = JSON_LENGTH(p_product_model_images);
            SET v_idx = 0;
            WHILE v_idx < v_len DO
                SET v_img = JSON_EXTRACT(p_product_model_images, CONCAT('$[', v_idx, ']'));
                CALL sp_manage_product_model_images(
                    1, NULL, p_business_id, p_branch_id, v_product_id,
                    JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.file_id')),
                    JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.file_name')),
                    JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.url')),
                    JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.original_file_name')),
                    CAST(JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.file_size')) AS UNSIGNED),
                    JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.thumbnail_url')),
                    CAST(JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.is_primary')) AS SIGNED),
                    CAST(JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.image_order')) AS SIGNED),
                    CAST(JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.product_model_image_category_id')) AS UNSIGNED),
                    p_user_id,
                    @img_success, @img_id, @img_data, @img_code, @img_msg
                );
                SELECT @img_success INTO p_success;
                IF p_success IS NULL OR p_success = 0 THEN
                    ROLLBACK; SET p_error_code = @img_code; SET p_error_message = @img_msg; LEAVE proc_body;
                END IF;
                SET v_idx = v_idx + 1;
            END WHILE;
        END IF;

        -- set primary_image_url if any primary image exists
        SELECT url INTO @primary_url FROM product_model_images
        WHERE product_model_id = v_product_id AND business_id = p_business_id AND is_primary = 1 AND is_active = 1 LIMIT 1;
        IF @primary_url IS NOT NULL THEN
            UPDATE product_model SET primary_image_url = @primary_url WHERE product_model_id = v_product_id;
        END IF;

        COMMIT;
        SET p_success = TRUE; SET p_error_code = 'SUCCESS'; SET p_error_message = 'Model created'; LEAVE proc_body;
    END IF;

    /* UPDATE */
    IF p_action = 2 THEN
        SELECT COUNT(*) INTO v_exist FROM product_model WHERE product_model_id = p_product_model_id AND is_active = 1;
        IF v_exist = 0 THEN SET p_error_code='ERR_NOT_FOUND'; SET p_error_message='Model not found.'; LEAVE proc_body; END IF;

        SELECT COUNT(*) INTO v_exist FROM product_model
        WHERE business_id = p_business_id AND branch_id = p_branch_id AND product_segment_id = p_product_segment_id AND product_category_id = p_product_category_id
          AND model_name = p_model_name AND product_model_id != p_product_model_id AND is_active = 1;
        IF v_exist > 0 THEN SET p_error_code='ERR_DUPLICATE'; SET p_error_message='Model name conflict.'; LEAVE proc_body; END IF;

        START TRANSACTION;

        UPDATE product_model
        SET product_segment_id = p_product_segment_id,
            product_category_id = p_product_category_id,
            model_name = p_model_name,
            description = p_description,
            default_rent_price = p_default_rent,
            default_deposit = p_default_deposit,
            default_sell_price = p_default_sell,
            default_warranty_days = p_default_warranty_days,
            updated_by = p_user_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE product_model_id = p_product_model_id;

        -- handle images if passed
        IF p_product_model_images IS NOT NULL AND JSON_LENGTH(p_product_model_images) > 0 THEN
            SET v_len = JSON_LENGTH(p_product_model_images);
            SET v_idx = 0;
            WHILE v_idx < v_len DO
                SET v_img = JSON_EXTRACT(p_product_model_images, CONCAT('$[', v_idx, ']'));

                IF JSON_CONTAINS_PATH(v_img, 'one', '$.product_model_image_id') THEN
                    SET @img_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.product_model_image_id')) AS SIGNED);
                ELSE
                    SET @img_id = NULL;
                END IF;

                SET @file_id = JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.file_id'));
                SET @file_name = JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.file_name'));
                SET @img_url = JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.url'));
                SET @orig_name = JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.original_file_name'));
                SET @fsz = JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.file_size'));
                SET @thumb = JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.thumbnail_url'));
                SET @is_primary = JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.is_primary'));
                SET @order = JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.image_order'));
                SET @catid = JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.product_model_image_category_id'));

                -- deletion flag?
                IF JSON_EXTRACT(v_img, '$.is_deleted') = 1 OR JSON_EXTRACT(v_img, '$.is_deleted') = '1' THEN
                    IF @img_id IS NOT NULL THEN
                        CALL sp_manage_product_model_images(3, @img_id, p_business_id, p_branch_id, p_product_model_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, p_user_id, @img_success, @img_id_out, @img_data, @img_code, @img_msg);
                        SELECT @img_success INTO p_success;
                        IF p_success IS NULL OR p_success = 0 THEN ROLLBACK; SET p_error_code=@img_code; SET p_error_message=@img_msg; LEAVE proc_body; END IF;
                    END IF;
                ELSE
                    IF @img_id IS NOT NULL THEN
                        CALL sp_manage_product_model_images(2, @img_id, p_business_id, p_branch_id, p_product_model_id, @file_id, @file_name, @img_url, @orig_name, CAST(@fsz AS UNSIGNED), @thumb, CAST(@is_primary AS SIGNED), CAST(@order AS SIGNED), CAST(@catid AS UNSIGNED), p_user_id, @img_success, @img_id_out, @img_data, @img_code, @img_msg);
                        SELECT @img_success INTO p_success;
                        IF p_success IS NULL OR p_success = 0 THEN ROLLBACK; SET p_error_code=@img_code; SET p_error_message=@img_msg; LEAVE proc_body; END IF;
                    ELSE
                        CALL sp_manage_product_model_images(1, NULL, p_business_id, p_branch_id, p_product_model_id, @file_id, @file_name, @img_url, @orig_name, CAST(@fsz AS UNSIGNED), @thumb, CAST(@is_primary AS SIGNED), CAST(@order AS SIGNED), CAST(@catid AS UNSIGNED), p_user_id, @img_success, @img_id_out, @img_data, @img_code, @img_msg);
                        SELECT @img_success INTO p_success;
                        IF p_success IS NULL OR p_success = 0 THEN ROLLBACK; SET p_error_code=@img_code; SET p_error_message=@img_msg; LEAVE proc_body; END IF;
                    END IF;
                END IF;

                SET v_idx = v_idx + 1;
            END WHILE;
        END IF;

        -- update primary_image_url
        SELECT url INTO @primary_url FROM product_model_images
        WHERE product_model_id = p_product_model_id AND business_id = p_business_id AND is_primary = 1 AND is_active = 1 LIMIT 1;
        UPDATE product_model SET primary_image_url = @primary_url WHERE product_model_id = p_product_model_id;

        COMMIT;
        SET p_success = TRUE; SET p_id = p_product_model_id; SET p_error_code='SUCCESS'; SET p_error_message='Model updated'; LEAVE proc_body;
    END IF;

    /* DELETE (soft) */
    IF p_action = 3 THEN
        START TRANSACTION;

        SELECT COUNT(*) INTO v_exist FROM product_model WHERE product_model_id = p_product_model_id AND is_active = 1;
        IF v_exist = 0 THEN ROLLBACK; SET p_error_code='ERR_NOT_FOUND'; SET p_error_message='Model not found or already deleted.'; LEAVE proc_body; END IF;

        -- fetch images to return so caller can delete from Drive
        CALL sp_manage_product_model_images(5, NULL, p_business_id, p_branch_id, p_product_model_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, p_user_id, @img_success, @img_id_out, @img_data, @img_code, @img_msg);
        SELECT @img_success, @img_data INTO @imgs_ok, v_images_json;

        UPDATE product_model
        SET is_active = 0, deleted_at = UTC_TIMESTAMP(6), updated_by = p_user_id, updated_at = UTC_TIMESTAMP(6)
        WHERE product_model_id = p_product_model_id;

        -- soft-delete images
        IF v_images_json IS NOT NULL AND JSON_LENGTH(v_images_json) > 0 THEN
            SET v_len = JSON_LENGTH(v_images_json);
            SET v_idx = 0;
            WHILE v_idx < v_len DO
                SET v_img = JSON_EXTRACT(v_images_json, CONCAT('$[', v_idx, ']'));
                SET @img_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_img, '$.product_model_image_id')) AS SIGNED);
                IF @img_id IS NOT NULL THEN
                    CALL sp_manage_product_model_images(3, @img_id, p_business_id, p_branch_id, p_product_model_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, p_user_id, @d_success, @d_id, @d_data, @d_code, @d_msg);
                    SELECT @d_success INTO @dok;
                END IF;
                SET v_idx = v_idx + 1;
            END WHILE;
        END IF;

        COMMIT;
        -- Return deleted images list so caller can remove files from Drive
        SET p_data = v_images_json;
        SET p_success = TRUE; SET p_id = p_product_model_id; SET p_error_code='SUCCESS'; SET p_error_message='Model deleted';
        LEAVE proc_body;
    END IF;

    /* GET SINGLE (model + images) */
    IF p_action = 4 THEN
        SELECT JSON_OBJECT(
            'product_model_id', product_model_id,
            'business_id', business_id,
            'branch_id', branch_id,
            'product_segment_id', product_segment_id,
            'product_category_id', product_category_id,
            'model_name', model_name,
            'description', description,
            'default_rent_price', default_rent_price,
            'default_deposit', default_deposit,
            'default_sell_price', default_sell_price,
            'default_warranty_days', default_warranty_days,
            'primary_image_url', primary_image_url,
            'created_by', created_by,
            'created_at', created_at
        ) INTO p_data
        FROM product_model
        WHERE product_model_id = p_product_model_id
        LIMIT 1;

        IF p_data IS NULL THEN SET p_error_code='ERR_NOT_FOUND'; SET p_error_message='Model not found.'; LEAVE proc_body; END IF;

        -- attach images
        CALL sp_manage_product_model_images(5, NULL, p_business_id, p_branch_id, p_product_model_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, p_user_id, @img_success, @img_id_out, @img_list, @img_code, @img_msg);
        SELECT @img_list INTO v_images_json;
        IF v_images_json IS NULL THEN SET v_images_json = JSON_ARRAY(); END IF;

        SET p_data = JSON_MERGE_PATCH(p_data, JSON_OBJECT('product_model_images', v_images_json));
        SET p_success = TRUE; SET p_id = p_product_model_id; SET p_error_code='SUCCESS'; SET p_error_message='Model fetched'; LEAVE proc_body;
    END IF;

    /* GET ALL (list) */
    IF p_action = 5 THEN
        SELECT IFNULL(JSON_ARRAYAGG(
            JSON_OBJECT(
                'product_model_id', pm.product_model_id,
                'model_name', pm.model_name,
                'default_rent_price', pm.default_rent_price,
                'default_deposit', pm.default_deposit,
                'default_sell_price', pm.default_sell_price,
                'product_category_id', pm.product_category_id,
                'category_name', pc.name,
                'product_segment_id', pm.product_segment_id,
                'segment_name', ps.name,
                'primary_image_url', pm.primary_image_url,
                'created_at', pm.created_at
            )
        ), JSON_ARRAY()) INTO p_data
        FROM product_model pm
        STRAIGHT_JOIN product_category pc ON pm.product_category_id = pc.product_category_id
        STRAIGHT_JOIN product_segment ps ON pm.product_segment_id = ps.product_segment_id
        WHERE pm.business_id = p_business_id AND pm.branch_id = p_branch_id AND pm.is_active = 1;

        SET p_success = TRUE; SET p_error_code = 'SUCCESS'; SET p_error_message = 'Models fetched'; LEAVE proc_body;
    END IF;

    SET p_error_code='ERR_INVALID_ACTION'; SET p_error_message='Invalid action provided.';
END;