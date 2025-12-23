DROP TRIGGER IF EXISTS trg_product_model_bi$$
CREATE TRIGGER trg_product_model_bi
BEFORE INSERT ON product_model
FOR EACH ROW
BEGIN
  DECLARE v_seg INT UNSIGNED;
  
  SELECT product_segment_id INTO v_seg
    FROM product_category
   WHERE product_category_id = NEW.product_category_id;
  
  IF v_seg IS NULL THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Invalid product_category_id';
  END IF;
  
  IF v_seg <> NEW.product_segment_id THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'product_segment_id mismatch with category';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_product_model_bu$$
CREATE TRIGGER trg_product_model_bu
BEFORE UPDATE ON product_model
FOR EACH ROW
BEGIN
  DECLARE v_seg INT UNSIGNED;
  
  SELECT product_segment_id INTO v_seg
    FROM product_category
   WHERE product_category_id = NEW.product_category_id;
  
  IF v_seg IS NULL THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Invalid product_category_id';
  END IF;
  
  IF v_seg <> NEW.product_segment_id THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'product_segment_id mismatch with category';
  END IF;
END$$