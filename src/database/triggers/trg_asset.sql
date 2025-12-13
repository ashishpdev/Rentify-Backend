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