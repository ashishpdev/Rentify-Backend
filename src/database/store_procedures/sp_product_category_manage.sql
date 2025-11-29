DROP PROCEDURE IF EXISTS sp_product_manage;
CREATE PROCEDURE `sp_product_manage`(
    IN p_action INT,                    -- 1=Create, 2=Update, 3=Delete, 4=Read Single, 5=Read All
    IN p_product_model_id INT,
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_product_category_id INT,
    IN p_model_name VARCHAR(255),
    IN p_description TEXT,
    IN p_product_images JSON,
    IN p_default_rent DECIMAL(10,2),
    IN p_default_deposit DECIMAL(10,2),
    IN p_default_warranty_days INT,
    IN p_total_quantity INT,
    IN p_available_quantity INT,
    IN p_user_id INT,
    IN p_role_id INT
)
main_block: BEGIN
    DECLARE v_role_id INT DEFAULT NULL;
    /* ---------------- GET USER ROLE ---------------- */
    SELECT role_id INTO v_role_id
    FROM master_user
    WHERE role_id = p_role_id
    LIMIT 1;
    IF v_role_id IS NULL THEN
        SELECT 'Unauthorized: Role not found.' AS message, 0 AS success;
        LEAVE main_block;
    END IF;
    /* ---------------- BLOCK MODIFY ACTIONS ---------------- */
    IF p_action IN (1,2,3) AND v_role_id NOT IN (1,2,3) THEN
        SELECT 'Unauthorized: No permission to modify product.' AS message, 0 AS success;
        LEAVE main_block;
    END IF;
    /* =============================================================== */
    /* ========================= CREATE ============================== */
    /* =============================================================== */
    IF p_action = 1 THEN
        INSERT INTO product_model (
            business_id, branch_id, product_category_id,
            model_name, description, product_images,
            default_rent, default_deposit, default_warranty_days,
            total_quantity, available_quantity,
            created_by, created_at,
            is_active, is_deleted
        )
        VALUES (
            p_business_id, p_branch_id, p_product_category_id,
            p_model_name, p_description, p_product_images,
            p_default_rent, p_default_deposit, p_default_warranty_days,
            p_total_quantity, p_available_quantity,
            p_user_id, NOW(),
            1, 0
        );
        SELECT CONCAT('Product created successfully. ID=', LAST_INSERT_ID()) AS message, 1 AS success;
        LEAVE main_block;
    END IF;
    /* =============================================================== */
    /* ========================= UPDATE ============================== */
    /* =============================================================== */
    IF p_action = 2 THEN
        UPDATE product_model
        SET 
            product_category_id = p_product_category_id,
            model_name = p_model_name,
            description = p_description,
            product_images = p_product_images,
            default_rent = p_default_rent,
            default_deposit = p_default_deposit,
            default_warranty_days = p_default_warranty_days,
            total_quantity = p_total_quantity,
            available_quantity = p_available_quantity,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE product_model_id = p_product_model_id
          AND is_deleted = 0;
        SELECT CONCAT('Product updated successfully. ID=', p_product_model_id) AS message, 1 AS success;
        LEAVE main_block;
    END IF;
    /* =============================================================== */
    /* ========================= DELETE ============================== */
    /* =============================================================== */
    IF p_action = 3 THEN
        UPDATE product_model
        SET 
            is_deleted = 1,
            is_active = 0,
            deleted_at = NOW(),
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE product_model_id = p_product_model_id
          AND is_deleted = 0;
        SELECT CONCAT('Product deleted successfully. ID=', p_product_model_id) AS message, 1 AS success;
        LEAVE main_block;
    END IF;
    /* =============================================================== */
    /* ===================== READ SINGLE ============================= */
    /* =============================================================== */
    IF p_action = 4 THEN
        SELECT 
            pm.product_model_id,
            pm.business_id,
            pm.branch_id,
            pm.product_category_id,
            pm.model_name,
            pm.description,
            pm.product_images,
            pm.default_rent,
            pm.default_deposit,
            pm.default_warranty_days,
            pm.total_quantity,
            pm.available_quantity,
            pm.is_active,
            pm.created_by,
            pm.created_at,
            pm.updated_by,
            pm.updated_at,
            pm.deleted_at,
            pm.is_deleted
        FROM product_model pm
        WHERE pm.product_model_id = p_product_model_id
          AND pm.is_deleted = 0
        LIMIT 1;
        SELECT 'Single product fetched.' AS message, 1 AS success;
        LEAVE main_block;
    END IF;
    /* =============================================================== */
    /* ===================== READ ALL ================================ */
    /* =============================================================== */
    IF p_action = 5 THEN
        SELECT 
            pm.product_model_id,
            pm.business_id,
            pm.branch_id,
            pm.product_category_id,
            pm.model_name,
            pm.description,
            pm.product_images,
            pm.default_rent,
            pm.default_deposit,
            pm.default_warranty_days,
            pm.total_quantity,
            pm.available_quantity,
            pm.is_active,
            pm.created_by,
            pm.created_at,
            pm.updated_by,
            pm.updated_at
        FROM product_model pm
        WHERE pm.business_id = p_business_id
          AND pm.branch_id = p_branch_id
          AND pm.is_deleted = 0
        ORDER BY pm.created_at DESC;
        SELECT 'Product list fetched.' AS message, 1 AS success;
        LEAVE main_block;
    END IF;
    /* =============================================================== */
    /* ===================== INVALID ACTION ========================== */
    /* =============================================================== */
    SELECT 'Invalid action provided.' AS message, 0 AS success;
END;