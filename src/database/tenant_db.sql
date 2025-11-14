-- =========================================================
-- TENANT DATABASE: schema + tenant relations + cross-db relations
-- =========================================================
CREATE DATABASE IF NOT EXISTS tenant_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE tenant_db;

-- ============================
-- LOOKUP / ENUM TABLES (unchanged)
-- ============================

-- Status before give on rent
CREATE TABLE IF NOT EXISTS product_status (
  product_status_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product_condition (
  product_condition_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- used for rental transaction status after issue
CREATE TABLE IF NOT EXISTS product_rental_status (
  product_rental_status_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS billing_period (
  billing_period_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payment_mode (
  payment_mode_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS maintenance_status (
  maintenance_status_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reservation_status (
  reservation_status_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- =========================================================
-- Seed lookup rows (INSERT IGNORE to avoid duplicates)
INSERT IGNORE INTO product_status (code, name, description, created_by) VALUES
  ('AVAILABLE','Available','Item is available for rent','system'),
  ('RESERVED','Reserved','Item reserved, not available','system'),
  ('RENTED','Rented','Item currently rented','system'),
  ('MAINTENANCE','Maintenance','Item under maintenance','system'),
  ('LOST','Lost','Item lost','system'),
  ('RETIRED','Retired','Item retired from use','system');

INSERT IGNORE INTO product_condition (code, name, description, created_by) VALUES
  ('NEW','New','Brand new item','system'),
  ('GOOD','Good','Good condition','system'),
  ('FAIR','Fair','Fair condition','system'),
  ('POOR','Poor','Poor condition','system'),
  ('BROKEN','Broken','Non functional / broken','system');

INSERT IGNORE INTO product_rental_status (code, name, description, created_by) VALUES
  ('ACTIVE','Active','Currently active rental','system'),
  ('RETURNED','Returned','Item returned','system'),
  ('LATE','Late','Returned late','system'),
  ('CANCELLED','Cancelled','Rental cancelled','system'),
  ('LOST','Lost','Item lost during rental','system');

INSERT IGNORE INTO billing_period (code, name, description, created_by) VALUES
  ('HOUR','Hour','Billing per hour','system'),
  ('DAY','Day','Billing per day','system'),
  ('WEEK','Week','Billing per week','system'),
  ('MONTH','Month','Billing per month','system'),
  ('CUSTOM','Custom','Custom billing period','system');

INSERT IGNORE INTO payment_mode (code, name, description, created_by) VALUES
  ('CASH','Cash','Cash payment','system'),
  ('CARD','Card','Card payment','system'),
  ('UPI','UPI','UPI payment','system'),
  ('BANK_TRANSFER','Bank Transfer','Bank transfer','system'),
  ('CHEQUE','Cheque','Cheque payment','system'),
  ('OTHER','Other','Other payment mode','system');

INSERT IGNORE INTO maintenance_status (code, name, description, created_by) VALUES
  ('PENDING','Pending','Maintenance pending','system'),
  ('SCHEDULED','Scheduled','Maintenance scheduled','system'),
  ('IN_PROGRESS','In Progress','Maintenance in progress','system'),
  ('COMPLETED','Completed','Maintenance completed','system'),
  ('CANCELLED','Cancelled','Maintenance cancelled','system');

INSERT IGNORE INTO reservation_status (code, name, description, created_by) VALUES
  ('PENDING','Pending','Reservation pending','system'),
  ('CONFIRMED','Confirmed','Reservation confirmed','system'),
  ('CANCELLED','Cancelled','Reservation cancelled','system'),
  ('EXPIRED','Expired','Reservation expired','system');


-- ============================
-- CORE: categories, models, inventory units
-- ============================

-- product_category (CAMERA, LAPTOP, MIC)
CREATE TABLE IF NOT EXISTS product_category (
  product_category_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  code VARCHAR(128) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  CONSTRAINT uq_product_category_business_branch_code UNIQUE (business_id, branch_id, code),
  INDEX idx_product_category_business (business_id),

  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- product_model (Canon EOS 5D Mark IV, iPhone 13 Pro)
CREATE TABLE IF NOT EXISTS product_model (
  product_model_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  sku VARCHAR(150) NOT NULL,
  model_name VARCHAR(255) NOT NULL,
  description TEXT,
  product_category_id INT NULL, -- FK to product_category.product_category_id
  default_rent DECIMAL(12,2),
  default_deposit DECIMAL(12,2),
  default_warranty_days INT,
  total_quantity INT NOT NULL DEFAULT 0,
  available_quantity INT NOT NULL DEFAULT 0,

  INDEX idx_product_model_business_sku (business_id, sku),
  CONSTRAINT uq_product_model_business_sku UNIQUE (business_id, sku),
  
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- inventory_unit (physical serialized item)
-- Ex: Canon EOS 5D Mark IV with serial no XYZ12345
CREATE TABLE IF NOT EXISTS inventory_unit (
  inventory_unit_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  object_id VARCHAR(200) UNIQUE,             -- optional unique id across system
  product_category_id INT NOT NULL,
  product_model_id INT NOT NULL,
  serial_number VARCHAR(200) UNIQUE NOT NULL,
  asset_tag VARCHAR(200) UNIQUE NOT NULL,
  product_status_id INT NOT NULL,
  product_condition_id INT NOT NULL,
  product_rental_status_id INT NOT NULL,
  purchase_price DECIMAL(12,2),
  purchase_date DATETIME(6),
  current_value DECIMAL(12,2),
  rent_price DECIMAL(12,2),
  deposit_amount DECIMAL(12,2),

  source_type ENUM('OWNED','BORROWED') NOT NULL DEFAULT 'OWNED',
  borrowed_from_business_name VARCHAR(255) NULL,
  borrowed_from_branch_name VARCHAR(255) NULL,
  purchase_bill_url VARCHAR(1024),

  INDEX idx_inventory_unit_business_object (business_id, object_id),
  INDEX idx_inventory_unit_business_model (business_id, product_model_id),
  INDEX idx_inventory_unit_serial (serial_number),
  INDEX idx_inventory_unit_source (business_id, source_type),
  INDEX idx_inventory_unit_model_branch (product_model_id, branch_id),

  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- ============================================================================
CREATE TABLE IF NOT EXISTS customer (
  customer_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  first_name VARCHAR(200) NOT NULL,
  last_name VARCHAR(200),
  email VARCHAR(255),
  contact_number VARCHAR(80) NOT NULL,
  address_line VARCHAR(255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  state VARCHAR(100) NOT NULL,
  country VARCHAR(100) DEFAULT 'India',
  pincode VARCHAR(20) NOT NULL,
  INDEX idx_customer_business_contact (business_id, contact_number),

  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- Represents one complete rental transaction — like a bill or invoice.
CREATE TABLE IF NOT EXISTS rental (
  rental_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  -- rental_code VARCHAR(200) NOT NULL,    -- UNIQUE code per business/branch according to item rent if needed, in future we will add
  invoice_no VARCHAR(200) NULL,
  invoice_date DATETIME(6) NULL,
  customer_id INT NOT NULL,
  start_date DATETIME(6) NOT NULL,
  due_date DATETIME(6) NOT NULL,
  end_date DATETIME(6),
  total_items INT NOT NULL DEFAULT 0,
  items_json JSON NOT NULL, -- array snapshot; enforce valid JSON
  product_rental_status_id INT,
  security_deposit DECIMAL(12,2),
  subtotal_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  discount_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(14,2) NOT NULL,
  paid_amount DECIMAL(14,2) DEFAULT 0,
  billing_period_id INT NOT NULL,
  currency VARCHAR(16) DEFAULT 'INR',
  notes TEXT,
  INDEX idx_rental_business (business_id, rental_code),
  INDEX idx_rental_customer (customer_id),
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,
  CONSTRAINT chk_items_json_valid CHECK (JSON_VALID(items_json))
) ENGINE=InnoDB;

-- Stores each specific item that was rented as part of that rental.
CREATE TABLE IF NOT EXISTS rental_item (
  rental_item_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  rental_id INT NOT NULL,
  product_category_id INT NOT NULL,
  product_model_id INT NULL,
  inventory_unit_id INT NULL,
  rent_price DECIMAL(14,2) NOT NULL,
  item_subtotal DECIMAL(14,2) NOT NULL,
  billing_period_id INT NULL,
  notes TEXT,
  INDEX idx_rental_item_rental (rental_id),
  INDEX idx_rental_item_model (product_model_id),
  INDEX idx_rental_item_unit (inventory_unit_id),
  created_by VARCHAR(255),
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS rental_payments (
  rental_payment_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  rental_id INT NOT NULL,
  -- payment_code VARCHAR(200) NOT NULL,
  paid_on DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  amount DECIMAL(14,2) NOT NULL,
  mode_of_payment_id INT,
  reference_no VARCHAR(255),
  notes TEXT,
  created_by VARCHAR(200),
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  INDEX idx_rental_payment_code (payment_code),
  INDEX idx_rental_payment_rental (rental_id),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- ============================
-- Other tables referencing inventory_unit (branch_id/business_id NOT NULL)
-- ============================
CREATE TABLE IF NOT EXISTS maintenance_records (
  maintenance_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  inventory_unit_id INT NOT NULL,
  maintenance_status_id INT NOT NULL,
  -- maintenance_code VARCHAR(200) NOT NULL,
  reported_by VARCHAR(255),
  reported_on DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  assigned_to VARCHAR(255),
  scheduled_date DATETIME(6),
  completed_on DATETIME(6),
  cost DECIMAL(14,2),
  remarks TEXT,
  -- attachments JSON,
  INDEX idx_maintenance_inv (inventory_unit_id),
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS damage_reports (
  damage_report_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  inventory_unit_id INT NOT NULL,
  -- report_code VARCHAR(200) NOT NULL,
  reported_by_id INT,
  reported_on DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  description TEXT NOT NULL,
  -- attachments JSON,
  estimated_cost DECIMAL(14,2),
  resolved TINYINT(1) DEFAULT 0,
  resolution_notes TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- CREATE TABLE IF NOT EXISTS item_history (
--   item_history_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
--   business_id INT NOT NULL,
--   branch_id INT NOT NULL,
--   inventory_unit_id INT NOT NULL,
--   changed_by VARCHAR(255),
--   from_status_id INT,
--   to_status_id INT,
--   from_branch INT,
--   to_branch INT,
--   note TEXT,
--   ts DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
--   INDEX idx_item_history (business_id, inventory_unit_id, ts),
--   created_by VARCHAR(255) NOT NULL,
--   created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
--   updated_by VARCHAR(255),
--   updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
--   deleted_at DATETIME(6),
--   is_active BOOLEAN DEFAULT TRUE,
--   is_deleted TINYINT(1) DEFAULT 0
-- ) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS item_history (
  item_history_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  inventory_unit_id INT NOT NULL,
  changed_field VARCHAR(255) NOT NULL, -- e.g. 'product_status_id', 'branch_id', 'location', 'serial_number'
  old_value TEXT NULL,                -- textual representation of previous value
  new_value TEXT NULL,                -- textual representation of new value

  changed_by VARCHAR(255) NULL,       -- user who made change (optional)
  note TEXT,                          -- free text note for human context

  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_item_history_unit (business_id, inventory_unit_id, ts),
  INDEX idx_item_history_field (inventory_unit_id, change_field, ts)
) ENGINE=InnoDB;


CREATE TABLE IF NOT EXISTS reservations (
  reservation_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  inventory_unit_id INT NOT NULL,
  customer_id INT NOT NULL,
  -- reservation_code VARCHAR(200) NOT NULL,
  reservation_status_id INT NOT NULL,
  reserved_from DATETIME(6) NOT NULL,
  reserved_until DATETIME(6) NOT NULL,
  reservation_status_id INT NOT NULL,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS product_images (
  product_image_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  product_model_id INT NULL,
  inventory_unit_id INT NULL,
  url VARCHAR(1024) NOT NULL,
  alt_text VARCHAR(512),
  is_primary TINYINT(1) DEFAULT 0,
  created_by VARCHAR(255),
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS invoice_photos (
  invoice_photo_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  product_model_id INT NULL,
  inventory_unit_id INT NULL,
  url VARCHAR(1024) NOT NULL,
  uploaded_by VARCHAR(255),
  uploaded_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  notes TEXT,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS borrow_records (
  borrow_record_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  inventory_unit_id INT NOT NULL,
  lender_business_name VARCHAR(255) NOT NULL,
  lender_branch_name VARCHAR(255) NOT NULL,
  borrowed_date DATETIME(6) NOT NULL,
  due_date DATETIME(6),
  returned_date DATETIME(6),
  status VARCHAR(64) DEFAULT 'ACTIVE',
  quantity INT DEFAULT 1,
  purchase_bill_url VARCHAR(1024),
  notes TEXT,
  created_by VARCHAR(255),
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS stock (
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  product_model_id INT NOT NULL,
  total_quantity INT NOT NULL DEFAULT 0,
  available_quantity INT NOT NULL DEFAULT 0,
  reserved_quantity INT NOT NULL DEFAULT 0,
  borrowed_quantity INT NOT NULL DEFAULT 0,
  last_updated DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (business_id, branch_id, product_model_id)
) ENGINE=InnoDB;

-- pricing_plans, location_history, deposit, etc. — ensure business_id & branch_id NOT NULL where present
CREATE TABLE IF NOT EXISTS pricing_plans (
  pricing_plan_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  plan_code VARCHAR(200) NOT NULL,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  billing_period_id INT,
  price DECIMAL(14,2) NOT NULL,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS location_history (
  location_history_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  inventory_unit_id INT NOT NULL,
  electronics_device_id INT NULL,
  latitude DECIMAL(10,6),
  longitude DECIMAL(10,6),
  accuracy_m DECIMAL(8,2),
  source VARCHAR(255),
  recorded_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  metadata JSON,
  INDEX idx_loc_hist_inv (business_id, inventory_unit_id, recorded_at),
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS deposit (
  deposit_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  deposit_code VARCHAR(200) NOT NULL,
  customer_id INT NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  held_since DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  released_on DATETIME(6),
  released_amount DECIMAL(14,2),
  notes TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at DATETIME(6),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;


-- ============================
-- TENANT internal FKs (run after creating tables)
-- (keeps constraint names unique)
-- ============================

ALTER TABLE product_model
  ADD CONSTRAINT fk_product_model_category
    FOREIGN KEY (product_category_id) REFERENCES product_category(product_category_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE inventory_unit
  ADD CONSTRAINT fk_inventory_unit_model
    FOREIGN KEY (product_model_id) REFERENCES product_model(product_model_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT fk_inventory_unit_category
    FOREIGN KEY (product_category_id) REFERENCES product_category(product_category_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_inventory_unit_status
    FOREIGN KEY (product_status_id) REFERENCES product_status(product_status_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT fk_inventory_unit_condition
    FOREIGN KEY (product_condition_id) REFERENCES product_condition(product_condition_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE rental
  ADD CONSTRAINT fk_rental_customer
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE rental_item
  ADD CONSTRAINT fk_rit_rental
    FOREIGN KEY (rental_id) REFERENCES rental(rental_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_rit_model
    FOREIGN KEY (product_model_id) REFERENCES product_model(product_model_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT fk_rit_unit
    FOREIGN KEY (inventory_unit_id) REFERENCES inventory_unit(inventory_unit_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE rental_payments
  ADD CONSTRAINT fk_rpayment_rental
    FOREIGN KEY (rental_id) REFERENCES rental(rental_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maint_unit
    FOREIGN KEY (inventory_unit_id) REFERENCES inventory_unit(inventory_unit_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE damage_reports
  ADD CONSTRAINT fk_damage_unit
    FOREIGN KEY (inventory_unit_id) REFERENCES inventory_unit(inventory_unit_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE item_history
  ADD CONSTRAINT fk_item_hist_unit
    FOREIGN KEY (inventory_unit_id) REFERENCES inventory_unit(inventory_unit_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE reservations
  ADD CONSTRAINT fk_res_unit
    FOREIGN KEY (inventory_unit_id) REFERENCES inventory_unit(inventory_unit_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE product_images
  ADD CONSTRAINT fk_pimg_model
    FOREIGN KEY (product_model_id) REFERENCES product_model(product_model_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT fk_pimg_unit
    FOREIGN KEY (inventory_unit_id) REFERENCES inventory_unit(inventory_unit_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE invoice_photos
  ADD CONSTRAINT fk_invoice_unit
    FOREIGN KEY (inventory_unit_id) REFERENCES inventory_unit(inventory_unit_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT fk_invoice_model
    FOREIGN KEY (product_model_id) REFERENCES product_model(product_model_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE borrow_records
  ADD CONSTRAINT fk_borrow_unit
    FOREIGN KEY (inventory_unit_id) REFERENCES inventory_unit(inventory_unit_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE stock
  ADD CONSTRAINT fk_stock_model
    FOREIGN KEY (product_model_id) REFERENCES product_model(product_model_id)
    ON DELETE CASCADE ON UPDATE CASCADE;

-- ============================
-- CROSS-DB foreign keys (tenant -> master_db)
-- Run these only if master_db exists on same server and types/signedness match
-- ============================
ALTER TABLE product_category
  ADD CONSTRAINT fk_product_category_business FOREIGN KEY (business_id)
    REFERENCES master_db.master_business (business_id) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_product_category_branch FOREIGN KEY (branch_id)
    REFERENCES master_db.master_branch (branch_id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE product_model
  ADD CONSTRAINT fk_product_model_business FOREIGN KEY (business_id)
    REFERENCES master_db.master_business (business_id) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_product_model_branch FOREIGN KEY (branch_id)
    REFERENCES master_db.master_branch (branch_id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE inventory_unit
  ADD CONSTRAINT fk_inventory_unit_business FOREIGN KEY (business_id)
    REFERENCES master_db.master_business (business_id) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_inventory_unit_branch FOREIGN KEY (branch_id)
    REFERENCES master_db.master_branch (branch_id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE customer
  ADD CONSTRAINT fk_customer_business FOREIGN KEY (business_id) REFERENCES master_db.master_business (business_id) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_customer_branch FOREIGN KEY (branch_id) REFERENCES master_db.master_branch (branch_id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE rental
  ADD CONSTRAINT fk_rental_business FOREIGN KEY (business_id) REFERENCES master_db.master_business (business_id) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_rental_branch FOREIGN KEY (branch_id) REFERENCES master_db.master_branch (branch_id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE rental_payments
  ADD CONSTRAINT fk_rpayment_business FOREIGN KEY (business_id) REFERENCES master_db.master_business (business_id) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_rpayment_branch FOREIGN KEY (branch_id) REFERENCES master_db.master_branch (branch_id) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE maintenance_records
  ADD CONSTRAINT fk_maint_business FOREIGN KEY (business_id) REFERENCES master_db.master_business (business_id) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT fk_maint_branch FOREIGN KEY (branch_id) REFERENCES master_db.master_branch (branch_id) ON DELETE CASCADE ON UPDATE CASCADE;

-- Repeat cross-db FK additions for any other tenant tables holding business_id/branch_id as needed.
