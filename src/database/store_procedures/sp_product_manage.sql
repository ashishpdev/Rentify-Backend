DROP PROCEDURE sp_product_manage;
CREATE DEFINER=`u130079017_rentaldb`@`%` PROCEDURE `sp_product_manage`(
    IN p_action INT,                    -- 4=Read Single, 5=Read All
    IN p_product_id INT,
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_category_id INT,
    IN p_product_name VARCHAR(255),
    IN p_product_code VARCHAR(100),
    IN p_description TEXT,
    IN p_brand VARCHAR(100),
    IN p_model VARCHAR(100),
    IN p_specifications JSON,
    IN p_rental_price_per_day DECIMAL(10,2),
    IN p_rental_price_per_week DECIMAL(10,2),
    IN p_rental_price_per_month DECIMAL(10,2),
    IN p_security_deposit DECIMAL(10,2),
    IN p_quantity_available INT,
    IN p_quantity_total INT,
    IN p_condition_type_id INT,
    IN p_product_images JSON,
    IN p_is_featured TINYINT(1),
    IN p_is_active TINYINT(1),
    IN p_user VARCHAR(255),
    IN p_role_id INT
)
BEGIN
    /* --------- READ SINGLE PRODUCT (p_action = 4) --------- */
    IF p_action = 4 THEN
        SELECT 
            pm.product_model_id,
            pm.business_id,
            pm.branch_id,
            pm.product_category_id,
            pm.model_name,
            pm.description,
            pm.brand,
            pm.model,
            pm.specifications,
            pm.rental_price_per_day,
            pm.rental_price_per_week,
            pm.rental_price_per_month,
            pm.security_deposit,
            pm.quantity_available,
            pm.quantity_total,
            pm.condition_type_id,
            pm.product_images,
            pm.is_featured,
            pm.is_active,
            pm.created_by,
            pm.created_at,
            pm.updated_by,
            pm.updated_at,
            pm.is_deleted
        FROM product_model pm
        WHERE pm.product_model_id = p_product_id
          AND pm.is_deleted = 0
        LIMIT 1;
    END IF;
    /* --------- READ ALL PRODUCTS FOR BUSINESS + BRANCH (p_action = 5) --------- */
    IF p_action = 5 THEN
        SELECT 
            pm.product_id,
            pm.business_id,
            pm.branch_id,
            pm.category_id,
            pm.product_name,
            pm.product_code,
            pm.description,
            pm.is_active,
            pm.created_by,
            pm.created_at,
            pm.updated_by,
            pm.updated_at
        FROM product_model pm
        WHERE pm.business_id = p_business_id
          AND pm.branch_id = p_branch_id
          AND pm.is_deleted = 0
        ORDER BY pm.is_featured DESC, pm.created_at DESC;
    END IF;
END