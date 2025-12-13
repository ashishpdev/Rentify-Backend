DROP PROCEDURE IF EXISTS sp_system_health_check;
CREATE PROCEDURE sp_system_health_check(
  IN p_business_id INT,
  IN p_branch_id INT,
  OUT p_stock_mismatches INT,
  OUT p_orphaned_items INT,
  OUT p_overdue_rentals INT,
  OUT p_health_report JSON
)
BEGIN
  DECLARE v_stock_discrepancy INT DEFAULT 0;
  DECLARE v_orphaned INT DEFAULT 0;
  DECLARE v_overdue INT DEFAULT 0;
  DECLARE v_missing_fk INT DEFAULT 0;

  -- Check 1: Stock quantity mismatches
  SELECT COUNT(*) INTO v_stock_discrepancy
  FROM (
    SELECT s.stock_id, s.product_model_id, s.quantity_total,
           COUNT(a.asset_id) AS actual_count
    FROM stock s
    LEFT JOIN asset a ON a.product_model_id = s.product_model_id 
                     AND a.business_id = s.business_id 
                     AND a.branch_id = s.branch_id
                     AND a.is_deleted = 0
    WHERE s.business_id = p_business_id
      AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
    GROUP BY s.stock_id, s.product_model_id, s.quantity_total
    HAVING s.quantity_total != actual_count
  ) mismatches;

  -- Check 2: Orphaned rental items (should be impossible with FK, but check anyway)
  SELECT COUNT(*) INTO v_orphaned
  FROM rental_item ri
  LEFT JOIN rental r ON ri.rental_id = r.rental_id
  WHERE r.rental_id IS NULL
    AND ri.business_id = p_business_id
    AND (p_branch_id IS NULL OR ri.branch_id = p_branch_id);

  -- Check 3: Overdue rentals
  SELECT COUNT(*) INTO v_overdue
  FROM rental
  WHERE business_id = p_business_id
    AND (p_branch_id IS NULL OR branch_id = p_branch_id)
    AND end_date IS NULL
    AND due_date < UTC_TIMESTAMP(6)
    AND is_deleted = 0;

  -- Check 4: Assets with invalid status references
  SELECT COUNT(*) INTO v_missing_fk
  FROM asset a
  LEFT JOIN product_status ps ON a.product_status_id = ps.product_status_id
  WHERE a.business_id = p_business_id
    AND (p_branch_id IS NULL OR a.branch_id = p_branch_id)
    AND a.is_deleted = 0
    AND ps.product_status_id IS NULL;

  SET p_stock_mismatches = v_stock_discrepancy;
  SET p_orphaned_items = v_orphaned;
  SET p_overdue_rentals = v_overdue;

  SET p_health_report = JSON_OBJECT(
    'timestamp', UTC_TIMESTAMP(6),
    'business_id', p_business_id,
    'branch_id', p_branch_id,
    'checks', JSON_OBJECT(
      'stock_mismatches', v_stock_discrepancy,
      'orphaned_rental_items', v_orphaned,
      'overdue_rentals', v_overdue,
      'invalid_status_references', v_missing_fk
    ),
    'health_status', CASE 
      WHEN (v_stock_discrepancy + v_orphaned + v_missing_fk) = 0 THEN 'HEALTHY'
      WHEN (v_stock_discrepancy + v_orphaned + v_missing_fk) < 5 THEN 'WARNING'
      ELSE 'CRITICAL'
    END,
    'recommendation', CASE
      WHEN v_stock_discrepancy > 0 THEN 'Run sp_manage_stock_admin with action=2 (SYNC)'
      WHEN v_orphaned > 0 THEN 'Manual cleanup required for orphaned records'
      WHEN v_missing_fk > 0 THEN 'Fix invalid status references'
      ELSE 'System is healthy'
    END
  );
END;