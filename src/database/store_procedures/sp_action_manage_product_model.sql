DROP PROCEDURE IF EXISTS sp_action_manage_product_model;
CREATE PROCEDURE sp_action_manage_product_model(
    IN  p_action INT,                          -- 1=Create, 2=Update, 3=Delete, 4=GetSingle, 5=GetAll
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
    IN  p_default_warranty_days INT,
    IN  p_total_quantity INT,               -- Mapped to Stock Quantity
    IN  p_available_quantity INT,           -- (Optional, usually same as total on creation)
    IN  p_user_id INT,
    IN  p_role_id INT,

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body: BEGIN

    -- DECLARATIONS
    DECLARE v_product_model_id INT DEFAULT NULL;
    DECLARE v_product_image_id INT DEFAULT NULL;
    DECLARE v_image JSON DEFAULT NULL;
    DECLARE v_image_url VARCHAR(1024);
    DECLARE v_alt_text VARCHAR(512);
    DECLARE v_is_primary TINYINT(1);
    DECLARE v_image_order INT;
    DECLARE v_stock_json JSON DEFAULT NULL;
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;
    
    -- Variables for List Fetching
    DECLARE v_images_json JSON DEFAULT NULL;
    DECLARE v_models_json JSON DEFAULT NULL;
    DECLARE v_model_id INT DEFAULT NULL;
    DECLARE v_idx INT DEFAULT 0;
    DECLARE v_total INT DEFAULT 0;

    -- =============================================
    /* Exception Handling */
    -- =============================================

    -- Specific Handler: Foreign Key Violation
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_error_message = 'Foreign key violation (likely missing reference).';
    END;

    -- Specific Handler: Duplicate Key
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
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
        ROLLBACK; -- Critical: Rollback entire transaction

        -- Log error details
        INSERT INTO proc_error_log(
            proc_name, 
            proc_args, 
            mysql_errno, 
            sql_state, 
            error_message
        )
        VALUES (
            'sp_action_manage_product_model',
            CONCAT(
                'p_action=', IFNULL(p_action, 'NULL'),
                ', p_id=', IFNULL(p_product_model_id, 'NULL')),
            v_errno,
            v_sql_state,
            LEFT(v_error_msg, 2000)
        );

        -- Safe return message
        SET p_error_message = CONCAT(
            'Error logged (errno=', IFNULL(CAST(v_errno AS CHAR), '?'),
            ', sqlstate=', IFNULL(v_sql_state, '?'), '). See proc_error_log.'
        );

        SET p_success = FALSE;
        SET p_error_code = 'ERR_EXCEPTION';
        SET p_error_message = CONCAT('Error logged (errno=', IFNULL(v_errno, '?'), ').');
    END;

    -- RESET OUTPUT PARAMETERS
    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;

    /* 1: CREATE */
    IF p_action = 1 THEN
        START TRANSACTION;

        -- A. Create Product Model
        CALL sp_manage_product_model(
            1,                       -- p_action
            NULL,                    -- p_product_model_id
            p_business_id,           -- p_business_id
            p_branch_id,             -- p_branch_id
            p_product_segment_id,    -- p_product_segment_id
            p_product_category_id,   -- p_product_category_id
            p_model_name,            -- p_model_name
            p_description,           -- p_description
            NULL,                    -- p_product_model_images
            p_default_rent,          -- p_default_rent
            p_default_deposit,       -- p_default_deposit
            p_default_warranty_days, -- p_default_warranty_days
            p_user_id,               -- p_user_id
            p_role_id,               -- p_role_id
            @p_success, @p_id, @p_data, @p_error_code, @p_error_message
        );
        
        -- Validation
        SELECT @p_success, @p_id, @p_error_code, @p_error_message 
        INTO p_success, v_product_model_id, p_error_code, p_error_message;

        IF NOT p_success THEN
            ROLLBACK;
            LEAVE proc_body;
        END IF;

        -- B. Initialize Stock (Create)
        -- We use v_product_model_id generated above
        CALL sp_manage_stock(
            1,                       -- Action: Create
            p_business_id,
            p_branch_id,
            p_product_segment_id,
            p_product_category_id,
            v_product_model_id,      -- The new ID
            p_total_quantity,        -- Initial Quantity
            1,                       -- p_movement_type_id = ADD_STOCK
            p_user_id,
            p_role_id,
            @p_success, @p_data, @p_error_code, @p_error_message
        );

        -- Validation
        SELECT @p_success INTO p_success;
        IF NOT p_success THEN
            ROLLBACK; -- Rollback Model creation if Stock creation fails
            SELECT @p_error_code, @p_error_message INTO p_error_code, p_error_message;
            LEAVE proc_body;
        END IF;

        -- C. Manage Images (if provided)
        IF p_product_model_images IS NOT NULL AND JSON_LENGTH(p_product_model_images) > 0 THEN
            WHILE JSON_LENGTH(p_product_model_images) > 0 DO
                CALL sp_manage_product_model_images(
                    1, NULL, p_business_id, p_branch_id, v_product_model_id,
                    JSON_UNQUOTE(JSON_EXTRACT(p_product_model_images, '$[0].url')),
                    JSON_UNQUOTE(JSON_EXTRACT(p_product_model_images, '$[0].alt_text')),
                    JSON_UNQUOTE(JSON_EXTRACT(p_product_model_images, '$[0].is_primary')),
                    JSON_UNQUOTE(JSON_EXTRACT(p_product_model_images, '$[0].image_order')),
                    p_user_id,
                    @p_success, @p_id, @p_data, @p_error_code, @p_error_message
                );

                SELECT @p_success INTO p_success;
                IF NOT p_success THEN
                    ROLLBACK;
                    SELECT @p_error_code, @p_error_message INTO p_error_code, p_error_message;
                    LEAVE proc_body;
                END IF;

                SET p_product_model_images = JSON_REMOVE(p_product_model_images, '$[0]');
            END WHILE;
        END IF;

        COMMIT;
        SET p_success = TRUE;
        SET p_id = v_product_model_id;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model and stock initialized successfully.';
        LEAVE proc_body;
    END IF;

    /* 2: UPDATE */
    IF p_action = 2 THEN
        START TRANSACTION;

        -- A. Update Product Model
        CALL sp_manage_product_model(
            2,                       -- p_action
            p_product_model_id,      -- p_product_model_id
            p_business_id,           -- p_business_id
            p_branch_id,             -- p_branch_id
            p_product_segment_id,    -- p_product_segment_id
            p_product_category_id,   -- p_product_category_id
            p_model_name,            -- p_model_name
            p_description,           -- p_description
            NULL,                    -- p_product_model_images
            p_default_rent,          -- p_default_rent
            p_default_deposit,       -- p_default_deposit
            p_default_warranty_days, -- p_default_warranty_days
            p_user_id,               -- p_user_id
            p_role_id,               -- p_role_id
            @p_success, @p_id, @p_data, @p_error_code, @p_error_message
        );

        SELECT @p_success, @p_id, @p_error_code, @p_error_message 
        INTO p_success, v_product_model_id, p_error_code, p_error_message;

        IF NOT p_success THEN
            ROLLBACK;
            LEAVE proc_body;
        END IF;

        -- C. Update Images
        IF p_product_model_images IS NOT NULL AND JSON_LENGTH(p_product_model_images) > 0 THEN
            WHILE JSON_LENGTH(p_product_model_images) > 0 DO
                SET v_image = JSON_EXTRACT(p_product_model_images, '$[0]');

                -- get product_image_id if provided
                IF JSON_EXTRACT(v_image, '$.product_image_id') IS NOT NULL THEN
                    SET v_product_image_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_image, '$.product_image_id')) AS SIGNED);
                ELSE
                    SET v_product_image_id = NULL;
                END IF;

                SET v_image_url = JSON_UNQUOTE(JSON_EXTRACT(v_image, '$.url'));
                SET v_alt_text = JSON_UNQUOTE(JSON_EXTRACT(v_image, '$.alt_text'));
                SET v_is_primary = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_image, '$.is_primary')) AS SIGNED);
                SET v_image_order = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_image, '$.image_order')) AS SIGNED);

                -- if image is marked deleted in payload -> delete
                IF JSON_EXTRACT(v_image, '$.is_deleted') = 1 OR JSON_EXTRACT(v_image, '$.is_deleted') = '1' THEN
                    IF v_product_image_id IS NOT NULL THEN
                        CALL sp_manage_product_model_images(
                            3, v_product_image_id, p_business_id, p_branch_id, v_product_model_id,
                            NULL, NULL, NULL, NULL, p_user_id,
                            @p_success, @p_id, @p_data, @p_error_code, @p_error_message
                        );
                        SELECT @p_success INTO p_success;
                        IF NOT p_success THEN
                            ROLLBACK;
                            SELECT @p_error_code, @p_error_message INTO p_error_code, p_error_message;
                            LEAVE proc_body;
                        END IF;
                    END IF;
                ELSE
                    -- if product_image_id present -> update
                    IF v_product_image_id IS NOT NULL THEN
                        CALL sp_manage_product_model_images(
                            2, v_product_image_id, p_business_id, p_branch_id, v_product_model_id,
                            v_image_url, v_alt_text, v_is_primary, v_image_order, p_user_id,
                            @p_success, @p_id, @p_data, @p_error_code, @p_error_message
                        );
                        SELECT @p_success INTO p_success;
                        IF NOT p_success THEN
                            ROLLBACK;
                            SELECT @p_error_code, @p_error_message INTO p_error_code, p_error_message;
                            LEAVE proc_body;
                        END IF;
                    ELSE
                        -- create new image
                        CALL sp_manage_product_model_images(
                            1, NULL, p_business_id, p_branch_id, v_product_model_id,
                            v_image_url, v_alt_text, v_is_primary, v_image_order, p_user_id,
                            @p_success, @p_id, @p_data, @p_error_code, @p_error_message
                        );
                        SELECT @p_success INTO p_success;
                        IF NOT p_success THEN
                            ROLLBACK;
                            SELECT @p_error_code, @p_error_message INTO p_error_code, p_error_message;
                            LEAVE proc_body;
                        END IF;
                    END IF;
                END IF;

                SET p_product_model_images = JSON_REMOVE(p_product_model_images, '$[0]');
            END WHILE;
        END IF;

        COMMIT;
        SET p_success = TRUE;
        SET p_id = v_product_model_id;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model updated successfully.';
        LEAVE proc_body;
    END IF;

    /* 3: DELETE */
    IF p_action = 3 THEN
        START TRANSACTION;

        CALL sp_manage_product_model(
            3,                       -- p_action
            p_product_model_id,      -- p_product_model_id
            p_business_id,           -- p_business_id
            p_branch_id,             -- p_branch_id
            p_product_segment_id,    -- p_product_segment_id
            p_product_category_id,   -- p_product_category_id
            NULL,                    -- p_model_name
            NULL,                    -- p_description
            NULL,                    -- p_product_model_images
            NULL,                    -- p_default_rent
            NULL,                    -- p_default_deposit
            NULL,                    -- p_default_warranty_days
            p_user_id,               -- p_user_id
            p_role_id,               -- p_role_id
            @p_success, @p_id, @p_data, @p_error_code, @p_error_message
        );

        -- Capture output parameters including the product_model_id
        SELECT @p_success, @p_id, @p_error_code, @p_error_message 
        INTO p_success, v_product_model_id, p_error_code, p_error_message;

        IF NOT p_success THEN
            ROLLBACK;
            LEAVE proc_body;
        END IF;

        IF p_product_model_images IS NOT NULL AND JSON_LENGTH(p_product_model_images) > 0 THEN
            WHILE JSON_LENGTH(p_product_model_images) > 0 DO
                SET v_product_image_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(p_product_model_images, '$[0].product_image_id')) AS SIGNED);

                IF v_product_image_id IS NOT NULL THEN
                    CALL sp_manage_product_model_images(
                        3, v_product_image_id, p_business_id, p_branch_id, v_product_model_id,
                        NULL, NULL, NULL, NULL, p_user_id,
                        @p_success, @p_id, @p_data, @p_error_code, @p_error_message
                    );
                    SELECT @p_success INTO p_success;
                    IF NOT p_success THEN
                        ROLLBACK;
                        SELECT @p_error_code, @p_error_message INTO p_error_code, p_error_message;
                        LEAVE proc_body;
                    END IF;
                END IF;

                SET p_product_model_images = JSON_REMOVE(p_product_model_images, '$[0]');
            END WHILE;
        ELSE
            -- fetch all images for this product model then delete each
            CALL sp_manage_product_model_images(
                5, NULL, p_business_id, p_branch_id, v_product_model_id,
                NULL, NULL, NULL, NULL, p_user_id,
                @p_success, @p_id, @p_data, @p_error_code, @p_error_message
            );
            SELECT @p_success, @p_data INTO p_success, v_images_json;
            IF NOT p_success THEN
                -- if listing images failed, continue but surface the error
                ROLLBACK;
                SELECT @p_error_code, @p_error_message INTO p_error_code, p_error_message;
                LEAVE proc_body;
            END IF;

            IF v_images_json IS NOT NULL AND JSON_LENGTH(v_images_json) > 0 THEN
                WHILE JSON_LENGTH(v_images_json) > 0 DO
                    SET v_product_image_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_images_json, '$[0].product_image_id')) AS SIGNED);

                    IF v_product_image_id IS NOT NULL THEN
                        CALL sp_manage_product_model_images(
                            3, v_product_image_id, p_business_id, p_branch_id, v_product_model_id,
                            NULL, NULL, NULL, NULL, p_user_id,
                            @p_success, @p_id, @p_data, @p_error_code, @p_error_message
                        );
                        SELECT @p_success INTO p_success;
                        IF NOT p_success THEN
                            ROLLBACK;
                            SELECT @p_error_code, @p_error_message INTO p_error_code, p_error_message;
                            LEAVE proc_body;
                        END IF;
                    END IF;

                    SET v_images_json = JSON_REMOVE(v_images_json, '$[0]');
                END WHILE;
            END IF;
        END IF;
        
        COMMIT;
        SET p_success = TRUE;
        SET p_id = p_product_model_id;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model and related data deleted successfully.';
        LEAVE proc_body;
    END IF;

    /* 4: GET */
    IF p_action = 4 THEN
        START TRANSACTION; -- (Optional for Reads, but keeps consistency)

        -- A. Get Model Data
        CALL sp_manage_product_model(
            4,                       -- p_action
            p_product_model_id,      -- p_product_model_id
            p_business_id,           -- p_business_id
            p_branch_id,             -- p_branch_id
            p_product_segment_id,    -- p_product_segment_id
            p_product_category_id,   -- p_product_category_id
            NULL,                    -- p_model_name
            NULL,                    -- p_description
            NULL,                    -- p_product_model_images
            NULL,                    -- p_default_rent
            NULL,                    -- p_default_deposit
            NULL,                    -- p_default_warranty_days
            NULL,                    -- p_user_id
            p_role_id,               -- p_role_id
            @p_success, @p_id, @p_data, @p_error_code, @p_error_message
        );

        SELECT @p_success, @p_id, @p_data, @p_error_code, @p_error_message
        INTO p_success, v_product_model_id, p_data, p_error_code, p_error_message;

        IF NOT p_success THEN
            ROLLBACK;
            LEAVE proc_body;
        END IF;

        -- B. Get Images (Action 5: Get all images for this model)
        SET v_images_json = NULL;
        CALL sp_manage_product_model_images(
            5,  -- Action 5: Get all images
            NULL, 
            p_business_id, 
            p_branch_id, 
            v_product_model_id,
            NULL, NULL, NULL, NULL, 
            p_user_id,
            @s_success, @s_id, v_images_json, @s_code, @s_msg
        );

        -- C. Get Stock (Action 4: Single Stock)
        SET v_stock_json = NULL;
        CALL sp_manage_stock(
            4, 
            p_business_id, 
            p_branch_id, 
            NULL, 
            NULL, 
            v_product_model_id, 
            NULL, 
            NULL,
            p_user_id, 
            p_role_id,
            @s_success, v_stock_json, @s_code, @s_msg
        );

        -- D. Construct Final JSON Response using JSON_SET
        -- This preserves JSON types instead of converting to strings
        IF p_data IS NULL THEN
            SET p_data = JSON_OBJECT();
        END IF;

        -- Ensure images is always an array (even if empty)
        SET p_data = JSON_MERGE_PATCH(
            IFNULL(p_data, '{}'),
            CONCAT(
            '{"images":',
                IF(v_images_json IS NOT NULL, v_images_json, JSON_ARRAY()),
            ',"stock":',
                IF(v_stock_json IS NOT NULL, v_stock_json, 'null'),
            '}'
            )
        );


        COMMIT;
        SET p_success = TRUE;
        SET p_id = v_product_model_id;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Product model retrieved successfully.';
        LEAVE proc_body;
    END IF;

    /* 5: GET ALL */
    IF p_action = 5 THEN
        START TRANSACTION;

        -- A. Get All Models
        CALL sp_manage_product_model(
            5,                       -- p_action
            p_product_model_id,      -- p_product_model_id
            p_business_id,           -- p_business_id
            p_branch_id,             -- p_branch_id
            p_product_segment_id,    -- p_product_segment_id
            p_product_category_id,   -- p_product_category_id
            NULL,                    -- p_model_name
            NULL,                    -- p_description
            NULL,                    -- p_product_model_images
            NULL,                    -- p_default_rent
            NULL,                    -- p_default_deposit
            NULL,                    -- p_default_warranty_days
            p_user_id,               -- p_user_id
            p_role_id,               -- p_role_id
            @p_success, @p_id, @p_data, @p_error_code, @p_error_message
        );

        SELECT @p_success, @p_id, @p_data, @p_error_code, @p_error_message
        INTO p_success, v_product_model_id, v_models_json, p_error_code, p_error_message;

        IF NOT p_success THEN
            ROLLBACK;
            LEAVE proc_body;
        END IF;

        -- B. Loop through Models to attach Images and Stock
        IF v_models_json IS NOT NULL THEN
            SET v_total = JSON_LENGTH(v_models_json);
            SET v_idx = 0;

            WHILE v_idx < v_total DO
                SET v_model_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(v_models_json, CONCAT('$[', v_idx, '].product_model_id'))) AS SIGNED);

                IF v_model_id IS NOT NULL THEN
                    
                    -- 1. Fetch Images for this Model
                    SET v_images_json = NULL;
                    CALL sp_manage_product_model_images(
                        5, NULL, p_business_id, p_branch_id, v_model_id,
                        NULL, NULL, NULL, NULL, p_user_id,
                        @s_success, @s_id, v_images_json, @s_code, @s_msg
                    );
                    
                    -- 2. Fetch Stock for this Model (Action 4 - Single)
                    SET v_stock_json = NULL;
                    CALL sp_manage_stock(
                        4,  -- ✅ CORRECT: Get single stock record
                        p_business_id, 
                        p_branch_id, 
                        NULL, 
                        NULL, 
                        v_model_id, 
                        NULL, 
                        NULL,
                        p_user_id, 
                        p_role_id,
                        @s_success, v_stock_json, @s_code, @s_msg
                    );

                    -- 3. Attach Data to current Array Item
                    -- Ensure images is always an array (even if empty)
                    SET v_models_json = JSON_SET(
                        v_models_json,
                        CONCAT('$[', v_idx, '].product_model_images'),
                        JSON_EXTRACT(IFNULL(v_images_json, '[]'), '$')
                    );
                    
                    SET v_models_json = JSON_SET(
                        v_models_json,
                        CONCAT('$[', v_idx, '].stock'),
                        CASE
                            WHEN v_stock_json IS NOT NULL THEN JSON_EXTRACT(v_stock_json, '$')
                            ELSE NULL
                        END
                        );

                    
                END IF;

                SET v_idx = v_idx + 1;
            END WHILE;

            SET p_data = v_models_json;
        ELSE
            SET p_data = JSON_ARRAY();
        END IF;

        COMMIT;
        SET p_success = TRUE;
        LEAVE proc_body;
    END IF;


    -- INVALID ACTION
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action provided.';
END;