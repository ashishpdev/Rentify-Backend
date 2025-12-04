DROP PROCEDURE sp_manage_stock;
CREATE PROCEDURE `sp_manage_stock`(
    IN p_action INT,
    IN p_business_id INT,
    IN p_branch_id INT,
    IN p_product_model_id INT,
    IN p_quantity INT,
    IN p_role_id INT
)
BEGIN
    DECLARE v_role_id INT DEFAULT NULL;
    DECLARE v_exists INT DEFAULT 0;

    -- ERROR HANDLER
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SELECT 'Error: Something went wrong.' AS message, 0 AS success;
    END;

    main_block: BEGIN

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
            SELECT 'Unauthorized: No permission to modify stock.' AS message, 0 AS success;
            LEAVE main_block;
        END IF;

        /* ---------------- CHECK PRODUCT MODEL EXISTS ---------------- */
        IF p_action IN (1,2,3) THEN
            SELECT COUNT(*) INTO v_exists 
            FROM product_model
            WHERE product_model_id = p_product_model_id;

            IF v_exists = 0 THEN
                SELECT 'Invalid product_model_id.' AS message, 0 AS success;
                LEAVE main_block;
            END IF;
        END IF;


        /* ──────────────────────────────────────────── */
        /*                     ACTION 1: ADD STOCK       */
        /* ──────────────────────────────────────────── */

        IF p_action = 1 THEN
            SELECT COUNT(*) INTO v_exists
            FROM stock
            WHERE business_id = p_business_id
              AND branch_id = p_branch_id
              AND product_model_id = p_product_model_id;

            -- No record → Insert new stock
            IF v_exists = 0 THEN
                INSERT INTO stock(
                    business_id,
                    branch_id,
                    product_model_id,
                    total_quantity,
                    available_quantity,
                    reserved_quantity,
                    borrowed_quantity,
                    last_updated
                )
                VALUES (
                    p_business_id,
                    p_branch_id,
                    p_product_model_id,
                    p_quantity,
                    p_quantity,
                    0,
                    0,
                    UTC_TIMESTAMP(6)
                );

                SELECT 'Stock added successfully.' AS message, 1 AS success;
                LEAVE main_block;
            END IF;

            -- Exists → Increase stock
            UPDATE stock
            SET 
                total_quantity = total_quantity + p_quantity,
                available_quantity = available_quantity + p_quantity,
                last_updated = UTC_TIMESTAMP(6)
            WHERE business_id = p_business_id
              AND branch_id = p_branch_id
              AND product_model_id = p_product_model_id;

            SELECT 'Stock increased successfully.' AS message, 1 AS success;
            LEAVE main_block;
        END IF;



        /* ──────────────────────────────────────────── */
        /*                ACTION 2: UPDATE STOCK         */
        /* ──────────────────────────────────────────── */

        IF p_action = 2 THEN

            UPDATE stock
            SET 
                total_quantity = p_quantity,
                available_quantity = p_quantity - reserved_quantity - borrowed_quantity,
                last_updated = UTC_TIMESTAMP(6)
            WHERE business_id = p_business_id
              AND branch_id = p_branch_id
              AND product_model_id = p_product_model_id;

            SELECT 'Stock updated successfully.' AS message, 1 AS success;
            LEAVE main_block;
        END IF;



        /* ──────────────────────────────────────────── */
        /*             ACTION 3: DECREASE STOCK          */
        /* ──────────────────────────────────────────── */

        IF p_action = 3 THEN

            IF (SELECT available_quantity FROM stock
                WHERE business_id = p_business_id
                  AND branch_id = p_branch_id
                  AND product_model_id = p_product_model_id) < p_quantity THEN

                SELECT 'Not enough stock available.' AS message, 0 AS success;
                LEAVE main_block;
            END IF;

            UPDATE stock
            SET 
                total_quantity = total_quantity - p_quantity,
                available_quantity = available_quantity - p_quantity,
                last_updated = UTC_TIMESTAMP(6)
            WHERE business_id = p_business_id
              AND branch_id = p_branch_id
              AND product_model_id = p_product_model_id;

            SELECT 'Stock decreased successfully.' AS message, 1 AS success;
            LEAVE main_block;
        END IF;



        /* ──────────────────────────────────────────── */
        /*            ACTION 4: GET STOCK (BRANCH)       */
        /* ──────────────────────────────────────────── */

        IF p_action = 4 THEN
            SELECT *
            FROM stock
            WHERE business_id = p_business_id
              AND branch_id = p_branch_id
            ORDER BY product_model_id DESC;

            LEAVE main_block;
        END IF;



        /* ──────────────────────────────────────────── */
        /*            ACTION 5: GET STOCK (ROLE)         */
        /* ──────────────────────────────────────────── */

        IF p_action = 5 THEN

            IF v_role_id = 1 THEN
                SELECT *
                FROM stock
                WHERE business_id = p_business_id
                ORDER BY branch_id, product_model_id DESC;

                LEAVE main_block;
            ELSE
                SELECT *
                FROM stock
                WHERE business_id = p_business_id
                  AND branch_id = p_branch_id
                ORDER BY product_model_id DESC;

                LEAVE main_block;
            END IF;
        END IF;



        /* ──────────────────────────────────────────── */
        /*                INVALID ACTION                 */
        /* ──────────────────────────────────────────── */

        SELECT 'Invalid action.' AS message, 0 AS success;

    END; -- main_block
END;