DROP TRIGGER IF EXISTS trg_stock_movements_bi;
DELIMITER $$
CREATE TRIGGER trg_stock_movements_bi
BEFORE INSERT ON stock_movements
FOR EACH ROW
BEGIN
  DECLARE v_exists INT;
  SELECT COUNT(1) INTO v_exists FROM product_model WHERE product_model_id = NEW.product_model_id;
  IF v_exists = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid product_model_id in stock_movements';
  END IF;
END$$
DELIMITER ;
