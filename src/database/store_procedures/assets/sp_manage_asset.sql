DROP PROCEDURE IF EXISTS sp_manage_asset;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_manage_asset`(
    IN p_action INT,                             -- 1=Create, 2=Update, 3=Delete, 4=Get Single, 5=Get List
    IN p_asset_id INT,
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_product_model_id INT,
    IN p_serial_number VARCHAR(100),
    IN p_asset_tag VARCHAR(100),
    IN p_product_status_id TINYINT,
    IN p_product_condition_id TINYINT,
    IN p_rent_price DECIMAL(12,2),
    IN p_sell_price DECIMAL(12,2),
    IN p_source_type_id TINYINT,
    IN p_borrowed_business VARCHAR(200),
    IN p_borrowed_branch VARCHAR(200),
    IN p_purchase_date DATE,
    IN p_purchase_price DECIMAL(12,2),
    IN p_current_value DECIMAL(12,2),
    -- Additional asset fields
    IN p_upper_body_measurement VARCHAR(50),
    IN p_lower_body_measurement VARCHAR(50),
    IN p_size_range VARCHAR(50),
    IN p_color_name VARCHAR(100),
    IN p_fabric_type VARCHAR(100),
    IN p_movement_category VARCHAR(20),
    IN p_manufacturing_date DATE,
    IN p_manufacturing_cost DECIMAL(12,2),
    -- Measurement table fields (optional)
    IN p_chest_cm DECIMAL(6,2),
    IN p_waist_cm DECIMAL(6,2),
    IN p_hip_cm DECIMAL(6,2),
    IN p_shoulder_cm DECIMAL(6,2),
    IN p_sleeve_length_cm DECIMAL(6,2),
    IN p_length_cm DECIMAL(6,2),
    IN p_inseam_cm DECIMAL(6,2),
    IN p_neck_cm DECIMAL(6,2),
    -- User context
    IN p_user_id INT,
    IN p_role_id INT,

    OUT p_success BOOLEAN,
    OUT p_id INT,
    OUT p_data JSON,
    OUT p_error_code VARCHAR(50),
    OUT p_error_message VARCHAR(500)
)
proc_body:BEGIN

    DECLARE v_role_id INT DEFAULT NULL;
    DECLARE v_exist INT DEFAULT 0;
    DECLARE v_product_segment_id INT DEFAULT NULL;
    DECLARE v_product_category_id INT DEFAULT NULL;
    DECLARE v_stock_id INT DEFAULT NULL;
    DECLARE v_add_movement_id TINYINT DEFAULT 1;      -- 'ADD' movement type
    DECLARE v_remove_movement_id TINYINT DEFAULT 2;   -- 'REMOVE' movement type
    DECLARE v_cno INT DEFAULT 0;
    DECLARE v_errno INT DEFAULT 0;
    DECLARE v_sql_state CHAR(5) DEFAULT '00000';
    DECLARE v_error_msg TEXT;
    DECLARE v_has_measurements BOOLEAN DEFAULT FALSE;
    DECLARE v_old_status_id TINYINT;
    DECLARE v_old_branch_id INT;
    DECLARE v_status_changed BOOLEAN DEFAULT FALSE;
    DECLARE v_del_branch_id INT;
    DECLARE v_del_model_id INT;
    DECLARE v_del_status_id TINYINT;

    -- =============================================
    /* Exception Handling */
    -- =============================================
    
    -- Foreign Key Violation
    DECLARE EXIT HANDLER FOR 1452
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_INVALID_REFERENCE';
        SET p_error_message = 'Invalid Product Model, Status, Condition, or Source Type.';
    END;

    -- Duplicate Key
    DECLARE EXIT HANDLER FOR 1062
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_code = 'ERR_DUPLICATE_KEY';
        SET p_error_message = 'Duplicate serial number or asset tag.';
    END;

    -- Generic Exception
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

        -- Log error
        INSERT INTO proc_error_log(
            proc_name, proc_args, mysql_errno, sql_state, error_message
        )
        VALUES (
            'sp_manage_asset',
            JSON_OBJECT(
                'p_action', p_action,
                'p_asset_id', p_asset_id,
                'p_business_id', p_business_id,
                'p_branch_id', p_branch_id,
                'p_product_model_id', p_product_model_id,
                'p_serial_number', p_serial_number,
                'p_user_id', p_user_id
            ),
            v_errno,
            v_sql_state,
            LEFT(v_error_msg, 2000)
        );

        SET p_success = FALSE;
        SET p_error_code = 'ERR_DATABASE_ERROR';
        SET p_error_message = CONCAT(
            'Unexpected error. Error Code: ',
            IFNULL(v_errno, 'N/A')
        );
    END;

    -- Reset output parameters
    SET p_success = FALSE;
    SET p_id = NULL;
    SET p_data = NULL;
    SET p_error_code = NULL;
    SET p_error_message = NULL;

    -- =============================================
    /* Role Validation */
    -- =============================================
    
    SELECT role_id INTO v_role_id
    FROM master_user WHERE role_id = p_role_id LIMIT 1;

    IF v_role_id IS NULL THEN
        SET p_error_code = 'ERR_ROLE_NOT_FOUND';
        SET p_error_message = 'User role not found.';
        LEAVE proc_body;
    END IF;

    IF p_action IN (1,2,3) AND v_role_id NOT IN (1,2,3) THEN
        SET p_error_code = 'ERR_PERMISSION_DENIED';
        SET p_error_message = 'No permission to modify asset records.';
        LEAVE proc_body;
    END IF;

    -- =============================================
    /* Get Segment and Category from Product Model */
    -- =============================================
    
    IF p_action IN (1, 2) THEN
        SELECT product_segment_id, product_category_id 
        INTO v_product_segment_id, v_product_category_id
        FROM product_model 
        WHERE product_model_id = p_product_model_id 
          AND business_id = p_business_id 
          AND is_active = 1
        LIMIT 1;

        IF v_product_segment_id IS NULL THEN
            SET p_error_code = 'ERR_INVALID_MODEL';
            SET p_error_message = 'Invalid or inactive product model.';
            LEAVE proc_body;
        END IF;
    END IF;

    -- Check if measurements are provided
    SET v_has_measurements = (
        p_chest_cm IS NOT NULL OR p_waist_cm IS NOT NULL OR 
        p_hip_cm IS NOT NULL OR p_shoulder_cm IS NOT NULL OR
        p_sleeve_length_cm IS NOT NULL OR p_length_cm IS NOT NULL OR
        p_inseam_cm IS NOT NULL OR p_neck_cm IS NOT NULL
    );

    -- =============================================
    /* ACTION 1: CREATE ASSET */
    -- =============================================
    
    IF p_action = 1 THEN

        -- Check duplicate serial number
        SELECT COUNT(*) INTO v_exist 
        FROM asset
        WHERE business_id = p_business_id 
          AND branch_id = p_branch_id
          AND product_model_id = p_product_model_id
          AND serial_number = p_serial_number 
          AND is_active = 1;

        IF v_exist > 0 THEN
            SET p_error_code = 'ERR_DUPLICATE_SERIAL';
            SET p_error_message = 'Serial number already exists.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        -- 1. Insert into asset table
        INSERT INTO asset (
            business_id, 
            branch_id, 
            product_model_id, 
            serial_number, 
            asset_tag,
            product_status_id, 
            product_condition_id,
            rent_price, 
            sell_price, 
            source_type_id,
            borrowed_from_business_name, 
            borrowed_from_branch_name,
            purchase_date, 
            purchase_price, 
            current_value,
            upper_body_measurement,
            lower_body_measurement,
            size_range,
            color_name,
            fabric_type,
            movement_category,
            manufacturing_date,
            manufacturing_cost,
            is_available,
            is_active,
            created_by
        )
        VALUES (
            p_business_id, 
            p_branch_id, 
            p_product_model_id, 
            p_serial_number, 
            p_asset_tag,
            p_product_status_id, 
            p_product_condition_id,
            p_rent_price, 
            p_sell_price, 
            p_source_type_id,
            p_borrowed_business, 
            p_borrowed_branch,
            p_purchase_date, 
            p_purchase_price, 
            p_current_value,
            p_upper_body_measurement,
            p_lower_body_measurement,
            p_size_range,
            p_color_name,
            p_fabric_type,
            IFNULL(p_movement_category, 'NORMAL'),
            p_manufacturing_date,
            p_manufacturing_cost,
            (p_product_status_id = 1),  -- is_available if status is 'AVAILABLE'
            1,  -- is_active
            p_user_id
        );

        SET p_id = LAST_INSERT_ID();

        -- 2. Insert measurements if provided
        IF v_has_measurements THEN
            INSERT INTO asset_measurement (
                asset_id, 
                chest_cm, 
                waist_cm, 
                hip_cm, 
                shoulder_cm,
                sleeve_length_cm, 
                length_cm, 
                inseam_cm, 
                neck_cm
            )
            VALUES (
                p_id, 
                p_chest_cm, 
                p_waist_cm, 
                p_hip_cm, 
                p_shoulder_cm,
                p_sleeve_length_cm, 
                p_length_cm, 
                p_inseam_cm, 
                p_neck_cm
            );
        END IF;

        -- 3. Update or create stock record
        SELECT stock_id INTO v_stock_id
        FROM stock
        WHERE business_id = p_business_id
          AND branch_id = p_branch_id
          AND product_model_id = p_product_model_id
        LIMIT 1;

        IF v_stock_id IS NULL THEN
            -- Create new stock record
            INSERT INTO stock (
                business_id, 
                branch_id, 
                product_segment_id, 
                product_category_id,
                product_model_id, 
                quantity_available, 
                created_by
            )
            VALUES (
                p_business_id, 
                p_branch_id, 
                v_product_segment_id, 
                v_product_category_id,
                p_product_model_id, 
                1, 
                p_user_id
            );
        ELSE
            -- Update existing stock
            UPDATE stock
            SET quantity_available = quantity_available + 1,
                last_updated_by = p_user_id,
                last_updated_at = UTC_TIMESTAMP(6)
            WHERE stock_id = v_stock_id;
        END IF;

        -- 4. Record stock movement
        INSERT INTO stock_movements (
            business_id, 
            branch_id, 
            product_model_id,
            inventory_movement_type_id, 
            quantity, 
            to_product_status_id,
            reference_no, 
            note, 
            created_by
        )
        VALUES (
            p_business_id, 
            p_branch_id, 
            p_product_model_id,
            v_add_movement_id, 
            1, 
            p_product_status_id,
            p_serial_number, 
            'New asset added', 
            p_user_id
        );

        -- 5. Record asset movement
        INSERT INTO asset_movements (
            business_id, 
            branch_id, 
            product_model_id, 
            asset_id,
            inventory_movement_type_id, 
            to_product_status_id,
            reference_no, 
            note, 
            created_by
        )
        VALUES (
            p_business_id, 
            p_branch_id, 
            p_product_model_id, 
            p_id,
            v_add_movement_id, 
            p_product_status_id,
            p_serial_number, 
            'Asset created', 
            p_user_id
        );

        COMMIT;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Asset created successfully.';
        LEAVE proc_body;
    END IF;

    -- =============================================
    /* ACTION 2: UPDATE ASSET */
    -- =============================================
    
    IF p_action = 2 THEN

        -- Get current status
        SELECT product_status_id, branch_id
        INTO v_old_status_id, v_old_branch_id
        FROM asset
        WHERE asset_id = p_asset_id AND is_active = 1;

        IF v_old_status_id IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Asset not found or deleted.';
            LEAVE proc_body;
        END IF;

        SET v_status_changed = (v_old_status_id != p_product_status_id);

        START TRANSACTION;

        -- 1. Update asset
        UPDATE asset SET
            product_model_id = p_product_model_id,
            serial_number = p_serial_number,
            asset_tag = p_asset_tag,
            product_status_id = p_product_status_id,
            product_condition_id = p_product_condition_id,
            rent_price = p_rent_price,
            sell_price = p_sell_price,
            source_type_id = p_source_type_id,
            borrowed_from_business_name = p_borrowed_business,
            borrowed_from_branch_name = p_borrowed_branch,
            purchase_date = p_purchase_date,
            purchase_price = p_purchase_price,
            current_value = p_current_value,
            upper_body_measurement = p_upper_body_measurement,
            lower_body_measurement = p_lower_body_measurement,
            size_range = p_size_range,
            color_name = p_color_name,
            fabric_type = p_fabric_type,
            movement_category = IFNULL(p_movement_category, movement_category),
            manufacturing_date = p_manufacturing_date,
            manufacturing_cost = p_manufacturing_cost,
            is_available = (p_product_status_id = 1),
            updated_by = p_user_id,
            updated_at = UTC_TIMESTAMP(6)
        WHERE asset_id = p_asset_id;

        -- 2. Update measurements if provided
        IF v_has_measurements THEN
            INSERT INTO asset_measurement (
                asset_id, 
                chest_cm, 
                waist_cm, 
                hip_cm, 
                shoulder_cm,
                sleeve_length_cm, 
                length_cm, 
                inseam_cm, 
                neck_cm
            )
            VALUES (
                p_asset_id, 
                p_chest_cm, 
                p_waist_cm, 
                p_hip_cm, 
                p_shoulder_cm,
                p_sleeve_length_cm, 
                p_length_cm, 
                p_inseam_cm, 
                p_neck_cm
            )
            ON DUPLICATE KEY UPDATE
                chest_cm = VALUES(chest_cm),
                waist_cm = VALUES(waist_cm),
                hip_cm = VALUES(hip_cm),
                shoulder_cm = VALUES(shoulder_cm),
                sleeve_length_cm = VALUES(sleeve_length_cm),
                length_cm = VALUES(length_cm),
                inseam_cm = VALUES(inseam_cm),
                neck_cm = VALUES(neck_cm),
                updated_at = UTC_TIMESTAMP(6);
        END IF;

        -- 3. Record asset movement if status changed
        IF v_status_changed THEN
            INSERT INTO asset_movements (
                business_id, 
                branch_id, 
                product_model_id, 
                asset_id,
                inventory_movement_type_id, 
                from_product_status_id, 
                to_product_status_id,
                reference_no, 
                note, 
                created_by
            )
            VALUES (
                p_business_id, 
                p_branch_id, 
                p_product_model_id, 
                p_asset_id,
                v_add_movement_id, 
                v_old_status_id, 
                p_product_status_id,
                p_serial_number, 
                'Status updated', 
                p_user_id
            );
        END IF;

        COMMIT;

        SET p_id = p_asset_id;
        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Asset updated successfully.';
        LEAVE proc_body;
    END IF;

    -- =============================================
    /* ACTION 3: DELETE ASSET (SOFT DELETE) */
    -- =============================================
    
    IF p_action = 3 THEN

        -- Get asset details
        SELECT branch_id, product_model_id, product_status_id
        INTO v_del_branch_id, v_del_model_id, v_del_status_id
        FROM asset
        WHERE asset_id = p_asset_id AND is_active = 1;

        IF v_del_branch_id IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Asset not found or already deleted.';
            LEAVE proc_body;
        END IF;

        START TRANSACTION;

        -- 1. Soft delete asset
        UPDATE asset SET
            is_active = 0,
            deleted_at = UTC_TIMESTAMP(6),
            updated_by = p_user_id
        WHERE asset_id = p_asset_id;

        -- 2. Update stock (decrease available quantity)
        UPDATE stock
        SET quantity_available = GREATEST(0, quantity_available - 1),
            last_updated_by = p_user_id,
            last_updated_at = UTC_TIMESTAMP(6)
        WHERE business_id = p_business_id
          AND branch_id = v_del_branch_id
          AND product_model_id = v_del_model_id;

        -- 3. Record stock movement
        INSERT INTO stock_movements (
            business_id, 
            branch_id, 
            product_model_id,
            inventory_movement_type_id, 
            quantity, 
            from_product_status_id,
            reference_no, 
            note, 
            created_by
        )
        VALUES (
            p_business_id, 
            v_del_branch_id, 
            v_del_model_id,
            v_remove_movement_id, 
            -1, 
            v_del_status_id,
            CONCAT('ASSET_', p_asset_id), 
            'Asset deleted', 
            p_user_id
        );

        -- 4. Record asset movement
        INSERT INTO asset_movements (
            business_id, 
            branch_id, 
            product_model_id, 
            asset_id,
            inventory_movement_type_id, 
            from_product_status_id,
            reference_no, 
            note, 
            created_by
        )
        VALUES (
            p_business_id, 
            v_del_branch_id, 
            v_del_model_id, 
            p_asset_id,
            v_remove_movement_id, 
            v_del_status_id,
            CONCAT('DELETE_', p_asset_id), 
            'Asset deleted', 
            p_user_id
        );

        COMMIT;

        SET p_success = TRUE;
        SET p_id = p_asset_id;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Asset deleted successfully.';
        LEAVE proc_body;
    END IF;

    -- =============================================
    /* ACTION 4: GET SINGLE ASSET */
    -- =============================================
    
    IF p_action = 4 THEN

        SELECT JSON_OBJECT(
            'asset_id', a.asset_id,
            'business_id', a.business_id,
            'branch_id', a.branch_id,
            'product_model_id', a.product_model_id,
            'serial_number', a.serial_number,
            'asset_tag', a.asset_tag,
            'qr_code', a.qr_code,
            'product_status_id', a.product_status_id,
            'product_condition_id', a.product_condition_id,
            'rent_price', a.rent_price,
            'sell_price', a.sell_price,
            'source_type_id', a.source_type_id,
            'borrowed_from_business_name', a.borrowed_from_business_name,
            'borrowed_from_branch_name', a.borrowed_from_branch_name,
            'purchase_date', a.purchase_date,
            'purchase_price', a.purchase_price,
            'current_value', a.current_value,
            'upper_body_measurement', a.upper_body_measurement,
            'lower_body_measurement', a.lower_body_measurement,
            'size_range', a.size_range,
            'color_name', a.color_name,
            'fabric_type', a.fabric_type,
            'movement_category', a.movement_category,
            'total_rent_count', a.total_rent_count,
            'total_rent_revenue', a.total_rent_revenue,
            'last_rented_date', a.last_rented_date,
            'last_cleaned_date', a.last_cleaned_date,
            'next_available_date', a.next_available_date,
            'manufacturing_date', a.manufacturing_date,
            'manufacturing_cost', a.manufacturing_cost,
            'is_available', a.is_available,
            'is_active', a.is_active,
            'created_at', a.created_at,
            'updated_at', a.updated_at,
            'measurements', IF(am.measurement_id IS NOT NULL, JSON_OBJECT(
                'chest_cm', am.chest_cm,
                'waist_cm', am.waist_cm,
                'hip_cm', am.hip_cm,
                'shoulder_cm', am.shoulder_cm,
                'sleeve_length_cm', am.sleeve_length_cm,
                'length_cm', am.length_cm,
                'inseam_cm', am.inseam_cm,
                'neck_cm', am.neck_cm
            ), NULL)
        ) INTO p_data
        FROM asset a
        LEFT JOIN asset_measurement am ON a.asset_id = am.asset_id
        WHERE a.asset_id = p_asset_id 
          AND a.is_active = 1
        LIMIT 1;

        IF p_data IS NULL THEN
            SET p_error_code = 'ERR_NOT_FOUND';
            SET p_error_message = 'Asset not found.';
            LEAVE proc_body;
        END IF;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Asset fetched successfully.';
        SET p_id = p_asset_id;
        LEAVE proc_body;
    END IF;

    -- =============================================
    /* ACTION 5: GET ASSET LIST */
    -- =============================================
    
    IF p_action = 5 THEN

        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'asset_id', asset_id,
                'business_id', business_id,
                'branch_id', branch_id,
                'product_model_id', product_model_id,
                'serial_number', serial_number,
                'asset_tag', asset_tag,
                'product_status_id', product_status_id,
                'product_condition_id', product_condition_id,
                'rent_price', rent_price,
                'sell_price', sell_price,
                'is_available', is_available,
                'created_at', created_at
            )
        ) INTO p_data
        FROM asset
        WHERE business_id = p_business_id 
          AND branch_id = p_branch_id 
          AND is_active = 1
        ORDER BY created_at DESC;

        SET p_success = TRUE;
        SET p_error_code = 'SUCCESS';
        SET p_error_message = 'Asset list fetched successfully.';
        LEAVE proc_body;
    END IF;

    -- Invalid action
    SET p_error_code = 'ERR_INVALID_ACTION';
    SET p_error_message = 'Invalid action provided.';

END;