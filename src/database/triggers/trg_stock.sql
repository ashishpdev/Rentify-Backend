-- Trigger: Auto-derive stock product hierarchy
DROP TRIGGER IF EXISTS trg_stock_bi$$
CREATE TRIGGER trg_stock_bi
BEFORE INSERT ON stock
FOR EACH ROW
BEGIN
  DECLARE v_seg INT UNSIGNED;
  DECLARE v_cat INT UNSIGNED;
  
  SELECT product_segment_id, product_category_id
    INTO v_seg, v_cat
    FROM product_model
   WHERE product_model_id = NEW.product_model_id;
  
  IF v_seg IS NULL OR v_cat IS NULL THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Invalid product_model_id for stock';
  END IF;
  
  SET NEW.product_segment_id = v_seg;
  SET NEW.product_category_id = v_cat;
END$$

DROP TRIGGER IF EXISTS trg_stock_bu$$
CREATE TRIGGER trg_stock_bu
BEFORE UPDATE ON stock
FOR EACH ROW
BEGIN
  IF NOT (OLD.product_model_id <=> NEW.product_model_id) THEN
    DECLARE v_seg INT UNSIGNED;
    DECLARE v_cat INT UNSIGNED;
    
    SELECT product_segment_id, product_category_id
      INTO v_seg, v_cat
      FROM product_model
     WHERE product_model_id = NEW.product_model_id;
    
    IF v_seg IS NULL OR v_cat IS NULL THEN
      SIGNAL SQLSTATE '45000' 
      SET MESSAGE_TEXT = 'Invalid product_model_id for stock';
    END IF;
    
    SET NEW.product_segment_id = v_seg;
    SET NEW.product_category_id = v_cat;
  END IF;
END$$