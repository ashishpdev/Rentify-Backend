-- rental_order_item BEFORE INSERT/UPDATE
DROP TRIGGER IF EXISTS trg_rental_item_bi;
CREATE TRIGGER trg_rental_item_bi
BEFORE INSERT ON rental_order_item
FOR EACH ROW
BEGIN
  DECLARE v_seg INT;
  DECLARE v_cat INT;
  SELECT product_segment_id, product_category_id
    INTO v_seg, v_cat
    FROM product_model
   WHERE product_model_id = NEW.product_model_id
   LIMIT 1;

  IF v_cat IS NULL OR v_seg IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid product_model_id for rental_order_item';
  END IF;

  SET NEW.product_segment_id = v_seg;
  SET NEW.product_category_id = v_cat;
END;

-- rental_order_item BEFORE UPDATE
DROP TRIGGER IF EXISTS trg_rental_item_bu;
CREATE TRIGGER trg_rental_item_bu
BEFORE UPDATE ON rental_order_item
FOR EACH ROW
BEGIN
  -- if product_model_id changed, sync snapshot
  IF NOT (OLD.product_model_id <=> NEW.product_model_id) THEN
    DECLARE v_seg INT;
    DECLARE v_cat INT;
    SELECT product_segment_id, product_category_id
      INTO v_seg, v_cat
      FROM product_model
     WHERE product_model_id = NEW.product_model_id
     LIMIT 1;

    IF v_cat IS NULL OR v_seg IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid product_model_id for rental_order_item (update)';
    END IF;

    SET NEW.product_segment_id = v_seg;
    SET NEW.product_category_id = v_cat;
  END IF;
END;