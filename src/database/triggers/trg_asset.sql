/* AFTER UPDATE */
DROP TRIGGER IF EXISTS trg_asset_status_change;
CREATE TRIGGER trg_asset_status_change
AFTER UPDATE ON asset
FOR EACH ROW
BEGIN
  -- only when status actually changes (NULL-safe)
  IF NOT (OLD.product_status_id <=> NEW.product_status_id) THEN

    -- insert a status-change movement into asset_movements
    INSERT INTO asset_movements (
      business_id,
      branch_id,
      product_model_id,
      asset_id,
      inventory_movement_type_id,
      from_branch_id,
      to_branch_id,
      from_product_status_id,
      to_product_status_id,
      created_by,
      note,
      metadata
    )
    VALUES (
      NEW.business_id,
      NEW.branch_id,
      NEW.product_model_id,
      NEW.asset_id,
      -- lookup STATUS_CHANGE id; ensure the row exists (seed above)
      (SELECT inventory_movement_type_id FROM inventory_movement_type LIMIT 1),
      NEW.branch_id,    -- status-change does not move branch; keep branch context
      NEW.branch_id,
      OLD.product_status_id,
      NEW.product_status_id,
      COALESCE(NEW.updated_by, 'system'),
      CONCAT('Status changed from ', COALESCE(OLD.product_status_id,'NULL'), ' -> ', COALESCE(NEW.product_status_id,'NULL')),
      JSON_OBJECT('origin','db-trigger','reason','status change via asset update')
    );

  END IF;
END;

/* AFTER INSERT */
-- when a new asset row is created we should record an 'ADD' movement and update stock 
DROP TRIGGER IF EXISTS trg_asset_after_insert;
CREATE TRIGGER trg_asset_after_insert
AFTER INSERT ON asset
FOR EACH ROW
BEGIN
  DECLARE v_add_type INT DEFAULT NULL;
  DECLARE v_seg INT;
  DECLARE v_cat INT;

  SELECT inventory_movement_type_id
    INTO v_add_type
    FROM inventory_movement_type
   WHERE code = 'ADD'
   LIMIT 1;

  SELECT product_segment_id, product_category_id
    INTO v_seg, v_cat
    FROM product_model
   WHERE product_model_id = NEW.product_model_id
   LIMIT 1;

  IF v_seg IS NULL OR v_cat IS NULL THEN
    -- product_model missing or inconsistent
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'product_model missing or invalid for newly inserted asset';
  END IF;

  IF v_add_type IS NOT NULL THEN
    INSERT INTO asset_movements (
      business_id,
      branch_id,
      product_model_id,
      asset_id,
      inventory_movement_type_id,
      to_branch_id,
      to_product_status_id,
      created_by,
      note,
      metadata
    ) VALUES (
      NEW.business_id,
      NEW.branch_id,
      NEW.product_model_id,
      NEW.asset_id,
      v_add_type,
      NEW.branch_id,
      NEW.product_status_id,
      COALESCE(NEW.created_by, 'system'),
      'Initial asset record created',
      JSON_OBJECT('origin','db-trigger','action','asset create')
    );

    -- try update stock row (increment available). If none, insert with derived segment/category
    UPDATE stock s
    SET s.quantity_available = s.quantity_available + 1,
        s.last_updated_by = COALESCE(NEW.created_by, 'system')
    WHERE s.business_id = NEW.business_id
      AND s.branch_id = NEW.branch_id
      AND s.product_model_id = NEW.product_model_id;

    IF ROW_COUNT() = 0 THEN
      INSERT IGNORE INTO stock (
        business_id, branch_id, product_segment_id, product_category_id, product_model_id,
        quantity_available, quantity_reserved, quantity_on_rent, quantity_in_maintenance, quantity_damaged, quantity_lost,
        created_by
      ) VALUES (
        NEW.business_id, NEW.branch_id, v_seg, v_cat, NEW.product_model_id,
        1, 0, 0, 0, 0, 0,
        COALESCE(NEW.created_by, 'system')
      );
    END IF;

    INSERT INTO stock_movements (
      business_id, branch_id, product_model_id, inventory_movement_type_id,
      quantity, to_branch_id, to_product_status_id, created_by, note, metadata
    ) VALUES (
      NEW.business_id,
      NEW.branch_id,
      NEW.product_model_id,
      v_add_type,
      1,
      NEW.branch_id,
      NEW.product_status_id,
      COALESCE(NEW.created_by, 'system'),
      'Stock added for new asset',
      JSON_OBJECT('origin','db-trigger','asset_id', NEW.asset_id)
    );
  END IF;
END;