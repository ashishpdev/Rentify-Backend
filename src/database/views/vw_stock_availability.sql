-- Stock availability view
CREATE OR REPLACE VIEW vw_stock_availability AS
SELECT 
  s.business_id,
  s.branch_id,
  b.branch_name,
  s.product_segment_id,
  seg.name AS segment_name,
  s.product_category_id,
  cat.name AS category_name,
  s.product_model_id,
  pm.model_name,
  pm.default_rent,
  pm.default_deposit,
  s.quantity_available,
  s.quantity_reserved,
  s.quantity_on_rent,
  s.quantity_in_maintenance,
  s.quantity_damaged,
  s.quantity_lost,
  s.quantity_total,
  s.is_product_model_rentable,
  ROUND((s.quantity_on_rent / NULLIF(s.quantity_total, 0)) * 100, 2) AS utilization_pct,
  s.last_updated_at
FROM stock s
JOIN master_branch b ON s.branch_id = b.branch_id
JOIN product_segment seg ON s.product_segment_id = seg.product_segment_id
JOIN product_category cat ON s.product_category_id = cat.product_category_id
JOIN product_model pm ON s.product_model_id = pm.product_model_id
WHERE pm.is_deleted = 0;