-- Trigger: Track asset status changes
DROP TRIGGER IF EXISTS trg_asset_status_change$$
CREATE TRIGGER trg_asset_status_change
AFTER UPDATE ON asset
FOR EACH ROW
BEGIN
  DECLARE v_movement_type TINYINT UNSIGNED;
  
  -- Only log if status actually changed
  IF NOT (OLD.product_status_id <=> NEW.product_status_id) THEN
    
    -- Get a generic movement type ID (use first available)
    SELECT inventory_movement_type_id INTO v_movement_type
    FROM inventory_movement_type
    LIMIT 1;
    
    IF v_movement_type IS NOT NULL THEN
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
      ) VALUES (
        NEW.business_id,
        NEW.branch_id,
        NEW.product_model_id,
        NEW.asset_id,
        v_movement_type,
        NEW.branch_id,
        NEW.branch_id,
        OLD.product_status_id,
        NEW.product_status_id,
        COALESCE(NEW.updated_by, 'system'),
        CONCAT('Status changed: ', COALESCE(OLD.product_status_id, 'NULL'), ' → ', COALESCE(NEW.product_status_id, 'NULL')),
        JSON_OBJECT(
          'origin', 'trigger',
          'trigger_name', 'trg_asset_status_change',
          'old_status', OLD.product_status_id,
          'new_status', NEW.product_status_id
        )
      );
    END IF;
  END IF;
END$$

-- Trigger: Initialize stock when asset is created
DROP TRIGGER IF EXISTS trg_asset_ai$$
CREATE TRIGGER trg_asset_ai
AFTER INSERT ON asset
FOR EACH ROW
BEGIN
  DECLARE v_add_type TINYINT UNSIGNED;
  DECLARE v_seg INT UNSIGNED;
  DECLARE v_cat INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    INSERT INTO proc_error_log (proc_name, proc_args, error_message)
    VALUES ('trg_asset_ai', JSON_OBJECT('asset_id', NEW.asset_id), 
            'Error in asset insert trigger');
  END;
  
  -- Get ADD movement type
  SELECT inventory_movement_type_id INTO v_add_type
  FROM inventory_movement_type
  WHERE code = 'ADD'
  LIMIT 1;
  
  -- Get segment and category
  SELECT product_segment_id, product_category_id
    INTO v_seg, v_cat
    FROM product_model
   WHERE product_model_id = NEW.product_model_id;
  
  IF v_seg IS NULL OR v_cat IS NULL THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Invalid product_model for asset';
  END IF;
  
  -- Log asset movement
  IF v_add_type IS NOT NULL THEN
    INSERT INTO asset_movements (
      business_id, branch_id, product_model_id, asset_id,
      inventory_movement_type_id, to_branch_id, to_product_status_id,
      created_by, note, metadata
    ) VALUES (
      NEW.business_id, NEW.branch_id, NEW.product_model_id, NEW.asset_id,
      v_add_type, NEW.branch_id, NEW.product_status_id,
      COALESCE(NEW.created_by, 'system'),
      'Initial asset creation',
      JSON_OBJECT('origin', 'trigger', 'action', 'asset_insert')
    );
    
    -- Update stock (increment available)
    INSERT INTO stock (
      business_id, branch_id, product_segment_id, product_category_id, 
      product_model_id, quantity_available, created_by
    ) VALUES (
      NEW.business_id, NEW.branch_id, v_seg, v_cat, NEW.product_model_id, 
      1, COALESCE(NEW.created_by, 'system')
    )
    ON DUPLICATE KEY UPDATE
      quantity_available = quantity_available + 1,
      last_updated_by = COALESCE(NEW.created_by, 'system');
    
    -- Log stock movement
    INSERT INTO stock_movements (
      business_id, branch_id, product_model_id, inventory_movement_type_id,
      quantity, to_branch_id, to_product_status_id, created_by, note, metadata
    ) VALUES (
      NEW.business_id, NEW.branch_id, NEW.product_model_id, v_add_type,
      1, NEW.branch_id, NEW.product_status_id,
      COALESCE(NEW.created_by, 'system'),
      'Stock added for new asset',
      JSON_OBJECT('origin', 'trigger', 'asset_id', NEW.asset_id)
    );
  END IF;
END$$

DELIMITER ;