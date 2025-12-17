-- Trigger to derive product_segment_id and product_category_id
DROP TRIGGER IF EXISTS trg_stock_bi;
CREATE TRIGGER trg_stock_bi
BEFORE INSERT ON stock
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
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid product_model_id for stock (product_model not found)';
  END IF;

  SET NEW.product_segment_id = v_seg;
  SET NEW.product_category_id = v_cat;
END;

-- Trigger to update product_segment_id and product_category_id on product_model_id change
DROP TRIGGER IF EXISTS trg_stock_bu;
CREATE TRIGGER trg_stock_bu
BEFORE UPDATE ON stock
FOR EACH ROW
BEGIN
  -- If product_model_id changed, re-derive segment/category
  IF NOT (OLD.product_model_id <=> NEW.product_model_id) THEN
    DECLARE v_seg INT;
    DECLARE v_cat INT;
    SELECT product_segment_id, product_category_id
      INTO v_seg, v_cat
      FROM product_model
     WHERE product_model_id = NEW.product_model_id
     LIMIT 1;

    IF v_cat IS NULL OR v_seg IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid product_model_id for stock (product_model not found)';
    END IF;

    SET NEW.product_segment_id = v_seg;
    SET NEW.product_category_id = v_cat;
  END IF;
END;