-- Overdue rentals view
CREATE OR REPLACE VIEW vw_overdue_rentals AS
SELECT 
  r.rental_id,
  r.invoice_no,
  CONCAT(c.first_name, ' ', IFNULL(c.last_name, '')) AS customer_name,
  c.contact_number,
  c.email,
  r.due_date,
  DATEDIFF(UTC_TIMESTAMP(6), r.due_date) AS days_overdue,
  r.total_amount,
  r.paid_amount,
  (r.total_amount - r.paid_amount) AS balance_due,
  b.branch_name,
  r.start_date
FROM rental r
JOIN customer c ON r.customer_id = c.customer_id
JOIN master_branch b ON r.branch_id = b.branch_id
WHERE r.end_date IS NULL 
  AND r.due_date < UTC_TIMESTAMP(6)
  AND r.is_deleted = 0
ORDER BY days_overdue DESC;