-- product_model BEFORE INSERT/UPDATE
DROP TRIGGER IF EXISTS trg_product_model_validate;
CREATE TRIGGER trg_product_model_validate
BEFORE INSERT ON product_model
FOR EACH ROW
BEGIN
  DECLARE v_seg INT;
  SELECT product_segment_id INTO v_seg
    FROM product_category
   WHERE product_category_id = NEW.product_category_id
   LIMIT 1;
  IF v_seg IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid product_category_id for product_model (category not found)';
  END IF;

  IF v_seg <> NEW.product_segment_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'product_model.product_segment_id must match product_category.product_segment_id';
  END IF;
END;


-- Also validate on UPDATE
DROP TRIGGER IF EXISTS trg_product_model_validate_upd;
CREATE TRIGGER trg_product_model_validate_upd
BEFORE UPDATE ON product_model
FOR EACH ROW
BEGIN
  DECLARE v_seg INT;
  SELECT product_segment_id INTO v_seg
    FROM product_category
   WHERE product_category_id = NEW.product_category_id
   LIMIT 1;
  IF v_seg IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid product_category_id for product_model (category not found)';
  END IF;

  IF v_seg <> NEW.product_segment_id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'product_model.product_segment_id must match product_category.product_segment_id';
  END IF;
END;