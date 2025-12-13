-- Active rentals view
CREATE OR REPLACE VIEW vw_active_rentals AS
SELECT 
  r.rental_id,
  r.business_id,
  r.branch_id,
  b.branch_name,
  r.customer_id,
  CONCAT(c.first_name, ' ', IFNULL(c.last_name, '')) AS customer_name,
  c.contact_number,
  c.email,
  r.invoice_no,
  r.start_date,
  r.due_date,
  r.end_date,
  r.total_items,
  r.total_amount,
  r.paid_amount,
  (r.total_amount - r.paid_amount) AS balance_due,
  CASE 
    WHEN r.end_date IS NULL AND r.due_date < UTC_TIMESTAMP(6) THEN 'OVERDUE'
    WHEN r.end_date IS NULL THEN 'ACTIVE'
    ELSE 'COMPLETED'
  END AS rental_status,
  DATEDIFF(UTC_TIMESTAMP(6), r.due_date) AS days_overdue,
  r.created_at,
  r.updated_at
FROM rental r
JOIN customer c ON r.customer_id = c.customer_id
JOIN master_branch b ON r.branch_id = b.branch_id
WHERE r.is_deleted = 0 AND r.is_active = 1;