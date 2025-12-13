/* BEFORE INSERT */
CREATE TRIGGER trg_rental_bi
BEFORE INSERT ON rental
FOR EACH ROW
BEGIN
  IF NEW.end_date IS NULL AND NEW.due_date < UTC_TIMESTAMP(6) THEN
    SET NEW.is_overdue = 1;
  ELSE
    SET NEW.is_overdue = 0;
  END IF;
END;

/* BEFORE UPDATE */
CREATE TRIGGER trg_rental_bu
BEFORE UPDATE ON rental
FOR EACH ROW
BEGIN
  IF NEW.end_date IS NULL AND NEW.due_date < UTC_TIMESTAMP(6) THEN
    SET NEW.is_overdue = 1;
  ELSE
    SET NEW.is_overdue = 0;
  END IF;
END;