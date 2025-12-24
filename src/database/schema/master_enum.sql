-- ========================================================
-- RENTAL MANAGEMENT SYSTEM - OPTIMIZED DATABASE SCHEMA
-- Version: 2.0
-- Last Updated: 2024
-- ========================================================
-- IMPROVEMENTS APPLIED:
-- 1. Optimized indexing strategy (composite, covering, functional)
-- 2. Partitioning for large tables (time-based RANGE partitioning)
-- 3. Improved data types and constraints
-- 4. Better normalization with controlled denormalization
-- 5. Enhanced triggers with error handling
-- 6. Performance-optimized stored procedures
-- 7. Comprehensive monitoring and audit capabilities
-- ========================================================

-- ========================================================
-- ONLY USE WHEN DROP TABLE WHICH IS HAVING FOREIGN KEY CONSTRAINTS
-- SET FOREIGN_KEY_CHECKS=0;
-- SET FOREIGN_KEY_CHECKS=1;
-- ========================================================

SET time_zone = '+00:00';
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- CREATE DATABASE IF NOT EXISTS master_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE master_db;

-- =========================================================
-- SCHEMA VERSION MANAGEMENT
-- =========================================================
CREATE TABLE schema_version (
  version_id INT AUTO_INCREMENT PRIMARY KEY,
  version_number VARCHAR(20) NOT NULL UNIQUE,
  description TEXT,
  applied_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  applied_by VARCHAR(255) NOT NULL,
  checksum VARCHAR(64) COMMENT 'SHA256 of migration script',
  INDEX idx_version_applied (applied_at DESC)
) ENGINE=InnoDB;

INSERT INTO schema_version (version_number, description, applied_by, checksum) 
VALUES ('1.0.0', 'Initial version with basic rental management features', 'system', SHA2('v1.0', 256));

-- =========================================================
-- MASTER ENUM TABLES
-- =========================================================

CREATE TABLE master_business_status (
    master_business_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    display_order TINYINT UNSIGNED DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    INDEX idx_status_active (is_active, display_order)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE master_role_type (
    master_role_type_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    permission_level TINYINT UNSIGNED NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    INDEX idx_role_level (permission_level),
    INDEX idx_role_active (is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE master_subscription_type (
    master_subscription_type_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    max_branches SMALLINT UNSIGNED DEFAULT 1,
    max_users SMALLINT UNSIGNED DEFAULT 1,
    max_items MEDIUMINT UNSIGNED DEFAULT 20,
    price_monthly DECIMAL(10,2) UNSIGNED DEFAULT 0,
    price_yearly DECIMAL(10,2) UNSIGNED DEFAULT 0,
    features JSON,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    INDEX idx_subscription_active (is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE master_subscription_status (
    master_subscription_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    allows_access BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    INDEX idx_sub_status_access (allows_access, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE master_billing_cycle (
    master_billing_cycle_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    months TINYINT UNSIGNED NOT NULL DEFAULT 1,
    discount_percent DECIMAL(5,2) UNSIGNED DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    INDEX idx_billing_active (is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE master_otp_type (
    master_otp_type_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    validity_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 10,
    max_attempts TINYINT UNSIGNED NOT NULL DEFAULT 3,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    INDEX idx_otp_type_active (is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE master_otp_status (
    master_otp_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    INDEX idx_otp_status_active (is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE product_status (
  product_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  is_available BOOLEAN NOT NULL DEFAULT FALSE,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_status_available (is_available, is_active),
  INDEX idx_status_order (display_order, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE product_condition (
  product_condition_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  condition_score TINYINT UNSIGNED DEFAULT 50,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_condition_score (condition_score DESC),
  INDEX idx_condition_order (display_order, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE inventory_movement_type (
  inventory_movement_type_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  affects_available TINYINT NOT NULL DEFAULT 0,
  affects_reserved TINYINT NOT NULL DEFAULT 0,
  affects_on_rent TINYINT NOT NULL DEFAULT 0,
  affects_maintenance TINYINT NOT NULL DEFAULT 0,
  affects_damaged TINYINT NOT NULL DEFAULT 0,
  affects_lost TINYINT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_movement_active (is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE rental_billing_period (
  rental_billing_period_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  hours DECIMAL(10,2) UNSIGNED NOT NULL,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_billing_period_hours (hours),
  INDEX idx_billing_period_order (display_order, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE payment_mode (
  payment_mode_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  requires_reference BOOLEAN NOT NULL DEFAULT FALSE,
  is_digital BOOLEAN NOT NULL DEFAULT FALSE,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_payment_mode_digital (is_digital, is_active),
  INDEX idx_payment_mode_order (display_order, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE maintenance_status (
  maintenance_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  is_completed BOOLEAN NOT NULL DEFAULT FALSE,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_maint_status_completed (is_completed, is_active),
  INDEX idx_maint_status_order (display_order, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE reservation_status (
  reservation_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  blocks_inventory BOOLEAN NOT NULL DEFAULT TRUE,
  is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_res_status_blocks (blocks_inventory, is_active),
  INDEX idx_res_status_order (display_order, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE source_type (
  source_type_id TINYINT UNSIGNED PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  requires_external_reference BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_source_active (is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE contact_type (
  contact_type_id TINYINT UNSIGNED PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_contact_type_active (is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE notification_channel (
  notification_channel_id TINYINT UNSIGNED PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  provider_name VARCHAR(100),
  cost_per_message DECIMAL(10,4) UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_channel_active (is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE notification_status (
  notification_status_id TINYINT UNSIGNED PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
  is_success BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_notif_status_terminal (is_terminal, is_success)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE rental_order_status (
  rental_order_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  allows_modification BOOLEAN NOT NULL DEFAULT TRUE,
  is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_rental_status_terminal (is_terminal, is_active),
  INDEX idx_rental_status_order (display_order, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE sales_order_status (
  sales_order_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  allows_modification BOOLEAN NOT NULL DEFAULT TRUE,
  is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  INDEX idx_sales_status_terminal (is_terminal, is_active),
  INDEX idx_sales_status_order (display_order, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

CREATE TABLE master_device_type (
  master_device_type_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255),
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE product_model_image_category (
  product_model_image_category_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255),
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE master_customer_tier (
  master_customer_tier_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255),
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE master_invoice_type (
  master_invoice_type_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255),
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE master_payment_direction (
  master_payment_direction_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255),
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE master_payment_status (
  master_payment_status_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255),
  is_terminal BOOLEAN NOT NULL DEFAULT FALSE,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE damage_severity (
  damage_severity_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255),
  severity_rank TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE master_gender (
  master_gender_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE clothing_season (
  clothing_season_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE clothing_size_system (
  clothing_size_system_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description VARCHAR(255),
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE clothing_size (
  clothing_size_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  clothing_size_system_id TINYINT UNSIGNED NOT NULL,
  code VARCHAR(50) NOT NULL,
  name VARCHAR(100) NULL,
  gender_id TINYINT UNSIGNED NULL,
  waist_cm DECIMAL(6,2) NULL,
  chest_cm DECIMAL(6,2) NULL,
  hip_cm DECIMAL(6,2) NULL,
  notes VARCHAR(255) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),

  UNIQUE KEY uq_clothing_size_system_code (clothing_size_system_id, code),
  INDEX idx_clothing_size_gender (gender_id),

  CONSTRAINT fk_clothing_size_system FOREIGN KEY (clothing_size_system_id) 
    REFERENCES clothing_size_system(clothing_size_system_id) 
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_clothing_size_gender FOREIGN KEY (gender_id) 
    REFERENCES master_gender(master_gender_id) 
    ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE clothing_colour (
  clothing_colour_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  hex_code CHAR(7) NULL,
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB;

CREATE TABLE order_progress_stage (
  stage_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  sequence_order TINYINT UNSIGNED NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;


-- =========================================================
 /* SEED MASTER ENUM */
-- =========================================================


-- Master Business Status
INSERT INTO master_business_status (code, name, description, display_order, created_at) VALUES
('ACTIVE', 'Active', 'Business is operational', 10, CURRENT_TIMESTAMP(6)),
('INACTIVE', 'Inactive', 'Business temporarily inactive', 20, CURRENT_TIMESTAMP(6)),
('SUSPENDED', 'Suspended', 'Business suspended due to payment/policy', 30, CURRENT_TIMESTAMP(6)),
('TERMINATED', 'Terminated', 'Business permanently closed', 40, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Master Role Types
INSERT INTO master_role_type (code, name, description, permission_level, created_at) VALUES
('SUPER_ADMIN', 'Super Administrator', 'Platform super admin', 100, CURRENT_TIMESTAMP(6)),
('OWNER', 'Business Owner', 'Full access to business', 90, CURRENT_TIMESTAMP(6)),
('ADMIN', 'Administrator', 'Management access', 80, CURRENT_TIMESTAMP(6)),
('MANAGER', 'Branch Manager', 'Branch-level management', 70, CURRENT_TIMESTAMP(6)),
('STAFF', 'Staff Member', 'Operational access', 50, CURRENT_TIMESTAMP(6)),
('VIEWER', 'Viewer', 'Read-only access', 10, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Subscription Types
INSERT INTO master_subscription_type (code, name, description, max_branches, max_users, max_items, price_monthly, price_yearly, features, created_at) VALUES
('FREE', 'Free Trial', 'Free trial plan', 1, 1, 10, 0.00, 0.00, JSON_ARRAY('basic_rental', 'basic_inventory'), CURRENT_TIMESTAMP(6)),
('BASIC', 'Basic', 'Basic rental management', 1, 3, 100, 999.00, 9990.00, JSON_ARRAY('basic_rental', 'inventory', 'basic_reports'), CURRENT_TIMESTAMP(6)),
('STANDARD', 'Standard', 'Standard plan with analytics', 3, 10, 500, 2999.00, 29990.00, JSON_ARRAY('advanced_rental', 'inventory', 'analytics', 'notifications'), CURRENT_TIMESTAMP(6)),
('PREMIUM', 'Premium', 'Premium with all features', 5, 25, 2000, 5999.00, 59990.00, JSON_ARRAY('all_features', 'priority_support', 'api_access', 'custom_reports'), CURRENT_TIMESTAMP(6)),
('ENTERPRISE', 'Enterprise', 'Enterprise solution', 20, 100, 10000, 14999.00, 149990.00, JSON_ARRAY('unlimited_features', '24x7_support', 'dedicated_manager', 'custom_integrations'), CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Subscription Status
INSERT INTO master_subscription_status (code, name, description, allows_access, created_at) VALUES
('TRIAL', 'Trial Period', 'In trial period', TRUE, CURRENT_TIMESTAMP(6)),
('ACTIVE', 'Active', 'Active subscription', TRUE, CURRENT_TIMESTAMP(6)),
('PAST_DUE', 'Past Due', 'Payment overdue but access allowed', TRUE, CURRENT_TIMESTAMP(6)),
('SUSPENDED', 'Suspended', 'Suspended due to non-payment', FALSE, CURRENT_TIMESTAMP(6)),
('CANCELLED', 'Cancelled', 'Cancelled by user', FALSE, CURRENT_TIMESTAMP(6)),
('EXPIRED', 'Expired', 'Subscription expired', FALSE, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Billing Cycles
INSERT INTO master_billing_cycle (code, name, months, discount_percent, created_at) VALUES
('MONTHLY', 'Monthly', 1, 0.00, CURRENT_TIMESTAMP(6)),
('QUARTERLY', 'Quarterly', 3, 5.00, CURRENT_TIMESTAMP(6)),
('HALF_YEARLY', 'Half Yearly', 6, 10.00, CURRENT_TIMESTAMP(6)),
('YEARLY', 'Yearly', 12, 16.67, CURRENT_TIMESTAMP(6)),
('LIFETIME', 'Lifetime', 999, 0.00, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- OTP Types
INSERT INTO master_otp_type (code, name, validity_minutes, max_attempts, created_at) VALUES
('LOGIN', 'Login Verification', 10, 3, CURRENT_TIMESTAMP(6)),
('REGISTER', 'Registration', 15, 3, CURRENT_TIMESTAMP(6)),
('RESET_PASSWORD', 'Password Reset', 15, 5, CURRENT_TIMESTAMP(6)),
('VERIFY_EMAIL', 'Email Verification', 30, 5, CURRENT_TIMESTAMP(6)),
('VERIFY_PHONE', 'Phone Verification', 10, 3, CURRENT_TIMESTAMP(6)),
('TWO_FACTOR', 'Two Factor Auth', 5, 3, CURRENT_TIMESTAMP(6)),
('TRANSACTION', 'Transaction Verification', 10, 3, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- OTP Status
INSERT INTO master_otp_status (code, name, is_terminal, created_at) VALUES
('PENDING', 'Pending Verification', FALSE, CURRENT_TIMESTAMP(6)),
('VERIFIED', 'Verified', TRUE, CURRENT_TIMESTAMP(6)),
('EXPIRED', 'Expired', TRUE, CURRENT_TIMESTAMP(6)),
('FAILED', 'Failed', TRUE, CURRENT_TIMESTAMP(6)),
('LOCKED', 'Locked (Too Many Attempts)', TRUE, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- =========================================================
    /* SEED PRODUCT/ASSET ENUM */
-- =========================================================

-- Product Status
INSERT INTO product_status (code, name, description, is_available, display_order, created_at) VALUES
('PROCUREMENT', 'In Procurement', 'Being procured', FALSE, 10, CURRENT_TIMESTAMP(6)),
('AVAILABLE', 'Available', 'Ready for rent', TRUE, 20, CURRENT_TIMESTAMP(6)),
('RESERVED', 'Reserved', 'Reserved for customer', FALSE, 30, CURRENT_TIMESTAMP(6)),
('RENTED', 'Rented Out', 'Currently on rent', FALSE, 40, CURRENT_TIMESTAMP(6)),
('MAINTENANCE', 'In Maintenance', 'Under maintenance/repair', FALSE, 50, CURRENT_TIMESTAMP(6)),
('DAMAGED', 'Damaged', 'Damaged, needs assessment', FALSE, 60, CURRENT_TIMESTAMP(6)),
('LOST', 'Lost', 'Lost or stolen', FALSE, 70, CURRENT_TIMESTAMP(6)),
('SOLD', 'Sold', 'Sold to customer', FALSE, 80, CURRENT_TIMESTAMP(6)),
('RETIRED', 'Retired', 'Retired from inventory', FALSE, 90, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Product Condition
INSERT INTO product_condition (code, name, description, condition_score, display_order, created_at) VALUES
('NEW', 'Brand New', 'Unused, original packaging', 100, 10, CURRENT_TIMESTAMP(6)),
('EXCELLENT', 'Excellent', 'Like new, minimal use', 90, 20, CURRENT_TIMESTAMP(6)),
('VERY_GOOD', 'Very Good', 'Light signs of use', 80, 30, CURRENT_TIMESTAMP(6)),
('GOOD', 'Good', 'Normal wear and tear', 70, 40, CURRENT_TIMESTAMP(6)),
('FAIR', 'Fair', 'Noticeable wear, fully functional', 60, 50, CURRENT_TIMESTAMP(6)),
('POOR', 'Poor', 'Heavy wear, may need repair', 40, 60, CURRENT_TIMESTAMP(6)),
('BROKEN', 'Broken/Non-functional', 'Not working, needs repair', 10, 70, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Inventory Movement Types
INSERT INTO inventory_movement_type (code, name, description, affects_available, affects_reserved, affects_on_rent, affects_maintenance, affects_damaged, affects_lost, created_at) VALUES
('ADD', 'Add Stock', 'New stock added', 1, 0, 0, 0, 0, 0, CURRENT_TIMESTAMP(6)),
('REMOVE', 'Remove Stock', 'Stock removed/scrapped', -1, 0, 0, 0, 0, 0, CURRENT_TIMESTAMP(6)),
('RENTAL_OUT', 'Rental Out', 'Item rented out', -1, 0, 1, 0, 0, 0, CURRENT_TIMESTAMP(6)),
('RENTAL_RETURN', 'Rental Return', 'Item returned from rental', 1, 0, -1, 0, 0, 0, CURRENT_TIMESTAMP(6)),
('RESERVE', 'Reserve', 'Item reserved', -1, 1, 0, 0, 0, 0, CURRENT_TIMESTAMP(6)),
('UNRESERVE', 'Unreserve', 'Reservation cancelled', 1, -1, 0, 0, 0, 0, CURRENT_TIMESTAMP(6)),
('MAINTENANCE_IN', 'Maintenance In', 'Sent for maintenance', -1, 0, 0, 1, 0, 0, CURRENT_TIMESTAMP(6)),
('MAINTENANCE_OUT', 'Maintenance Out', 'Returned from maintenance', 1, 0, 0, -1, 0, 0, CURRENT_TIMESTAMP(6)),
('MARK_DAMAGED', 'Mark Damaged', 'Marked as damaged', -1, 0, 0, 0, 1, 0, CURRENT_TIMESTAMP(6)),
('REPAIR_DAMAGED', 'Repair Damaged', 'Repaired from damaged', 1, 0, 0, 0, -1, 0, CURRENT_TIMESTAMP(6)),
('MARK_LOST', 'Mark Lost', 'Marked as lost', -1, 0, 0, 0, 0, 1, CURRENT_TIMESTAMP(6)),
('FOUND', 'Found', 'Previously lost item found', 1, 0, 0, 0, 0, -1, CURRENT_TIMESTAMP(6)),
('TRANSFER_OUT', 'Transfer Out', 'Transferred to another branch', -1, 0, 0, 0, 0, 0, CURRENT_TIMESTAMP(6)),
('TRANSFER_IN', 'Transfer In', 'Received from another branch', 1, 0, 0, 0, 0, 0, CURRENT_TIMESTAMP(6)),
('SOLD', 'Sold', 'Item sold to customer', -1, 0, 0, 0, 0, 0, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Rental Billing Periods
INSERT INTO rental_billing_period (code, name, description, hours, display_order, created_at) VALUES
('HOURLY', 'Hourly', 'Per hour billing', 1.00, 10, CURRENT_TIMESTAMP(6)),
('HALF_DAY', 'Half Day', '12 hours', 12.00, 20, CURRENT_TIMESTAMP(6)),
('DAILY', 'Daily', '24 hours', 24.00, 30, CURRENT_TIMESTAMP(6)),
('WEEKLY', 'Weekly', '7 days', 168.00, 40, CURRENT_TIMESTAMP(6)),
('FORTNIGHTLY', 'Fortnightly', '14 days', 336.00, 50, CURRENT_TIMESTAMP(6)),
('MONTHLY', 'Monthly', '30 days', 720.00, 60, CURRENT_TIMESTAMP(6)),
('QUARTERLY', 'Quarterly', '90 days', 2160.00, 70, CURRENT_TIMESTAMP(6)),
('CUSTOM', 'Custom Period', 'Custom billing period', 0.00, 999, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Payment Modes
INSERT INTO payment_mode (code, name, description, requires_reference, is_digital, display_order, created_at) VALUES
('CASH', 'Cash', 'Cash payment', FALSE, FALSE, 10, CURRENT_TIMESTAMP(6)),
('CARD', 'Card Payment', 'Credit/Debit card', TRUE, TRUE, 20, CURRENT_TIMESTAMP(6)),
('UPI', 'UPI', 'UPI payment', TRUE, TRUE, 30, CURRENT_TIMESTAMP(6)),
('NET_BANKING', 'Net Banking', 'Online bank transfer', TRUE, TRUE, 40, CURRENT_TIMESTAMP(6)),
('WALLET', 'Digital Wallet', 'Mobile wallet', TRUE, TRUE, 50, CURRENT_TIMESTAMP(6)),
('CHEQUE', 'Cheque', 'Bank cheque', TRUE, FALSE, 60, CURRENT_TIMESTAMP(6)),
('DD', 'Demand Draft', 'Bank DD', TRUE, FALSE, 70, CURRENT_TIMESTAMP(6)),
('BANK_TRANSFER', 'Bank Transfer', 'Direct bank transfer', TRUE, TRUE, 80, CURRENT_TIMESTAMP(6)),
('EMI', 'EMI', 'Easy monthly installments', TRUE, TRUE, 90, CURRENT_TIMESTAMP(6)),
('OTHER', 'Other', 'Other payment method', FALSE, FALSE, 999, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Maintenance Status
INSERT INTO maintenance_status (code, name, description, is_completed, display_order, created_at) VALUES
('REPORTED', 'Reported', 'Issue reported', FALSE, 10, CURRENT_TIMESTAMP(6)),
('PENDING', 'Pending', 'Awaiting assignment', FALSE, 20, CURRENT_TIMESTAMP(6)),
('SCHEDULED', 'Scheduled', 'Maintenance scheduled', FALSE, 30, CURRENT_TIMESTAMP(6)),
('IN_PROGRESS', 'In Progress', 'Work in progress', FALSE, 40, CURRENT_TIMESTAMP(6)),
('ON_HOLD', 'On Hold', 'Work paused', FALSE, 50, CURRENT_TIMESTAMP(6)),
('COMPLETED', 'Completed', 'Maintenance completed', TRUE, 60, CURRENT_TIMESTAMP(6)),
('CANCELLED', 'Cancelled', 'Maintenance cancelled', TRUE, 70, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Reservation Status
INSERT INTO reservation_status (code, name, description, blocks_inventory, is_terminal, display_order, created_at) VALUES
('PENDING', 'Pending', 'Awaiting confirmation', TRUE, FALSE, 10, CURRENT_TIMESTAMP(6)),
('CONFIRMED', 'Confirmed', 'Reservation confirmed', TRUE, FALSE, 20, CURRENT_TIMESTAMP(6)),
('FULFILLED', 'Fulfilled', 'Converted to rental', FALSE, TRUE, 30, CURRENT_TIMESTAMP(6)),
('CANCELLED', 'Cancelled', 'Reservation cancelled', FALSE, TRUE, 40, CURRENT_TIMESTAMP(6)),
('EXPIRED', 'Expired', 'Reservation period expired', FALSE, TRUE, 50, CURRENT_TIMESTAMP(6)),
('NO_SHOW', 'No Show', 'Customer did not show up', FALSE, TRUE, 60, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Source Types
INSERT INTO source_type (source_type_id, code, name, description, requires_external_reference, created_at) VALUES
(1, 'OWNED', 'Owned', 'Asset owned by business', FALSE, CURRENT_TIMESTAMP(6)),
(2, 'BORROWED', 'Borrowed', 'Borrowed from another party', TRUE, CURRENT_TIMESTAMP(6)),
(3, 'LEASED', 'Leased', 'Leased from vendor', TRUE, CURRENT_TIMESTAMP(6)),
(4, 'CONSIGNMENT', 'Consignment', 'On consignment basis', TRUE, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Contact Types
INSERT INTO contact_type (contact_type_id, code, name, description, created_at) VALUES
(1, 'MOBILE', 'Mobile', 'Mobile phone (SMS)', CURRENT_TIMESTAMP(6)),
(2, 'EMAIL', 'Email', 'Email address', CURRENT_TIMESTAMP(6)),
(3, 'BOTH', 'Both', 'Mobile and Email', CURRENT_TIMESTAMP(6)),
(4, 'LANDLINE', 'Landline', 'Landline phone', CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Notification Channels
INSERT INTO notification_channel (notification_channel_id, code, name, description, provider_name, cost_per_message, created_at) VALUES
(1, 'SMS', 'SMS', 'Text message', 'Twilio', 0.0500, CURRENT_TIMESTAMP(6)),
(2, 'EMAIL', 'Email', 'Email notification', 'SendGrid', 0.0010, CURRENT_TIMESTAMP(6)),
(3, 'PUSH', 'Push Notification', 'Mobile/Web push', 'Firebase', 0.0000, CURRENT_TIMESTAMP(6)),
(4, 'WHATSAPP', 'WhatsApp', 'WhatsApp message', 'Twilio', 0.0400, CURRENT_TIMESTAMP(6)),
(5, 'IN_APP', 'In-App', 'In-app notification', 'Internal', 0.0000, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Notification Status
INSERT INTO notification_status (notification_status_id, code, name, description, is_terminal, is_success, created_at) VALUES
(1, 'PENDING', 'Pending', 'Waiting to be sent', FALSE, FALSE, CURRENT_TIMESTAMP(6)),
(2, 'SCHEDULED', 'Scheduled', 'Scheduled for future', FALSE, FALSE, CURRENT_TIMESTAMP(6)),
(3, 'QUEUED', 'Queued', 'In sending queue', FALSE, FALSE, CURRENT_TIMESTAMP(6)),
(4, 'SENT', 'Sent', 'Sent to provider', FALSE, FALSE, CURRENT_TIMESTAMP(6)),
(5, 'DELIVERED', 'Delivered', 'Delivered to recipient', TRUE, TRUE, CURRENT_TIMESTAMP(6)),
(6, 'FAILED', 'Failed', 'Delivery failed', TRUE, FALSE, CURRENT_TIMESTAMP(6)),
(7, 'BOUNCED', 'Bounced', 'Message bounced', TRUE, FALSE, CURRENT_TIMESTAMP(6)),
(8, 'CANCELLED', 'Cancelled', 'Cancelled before sending', TRUE, FALSE, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Rental Order Status
INSERT INTO rental_order_status (code, name, description, allows_modification, is_terminal, display_order, created_at) VALUES
('DRAFT', 'Draft', 'Order being created', TRUE, FALSE, 10, CURRENT_TIMESTAMP(6)),
('PENDING', 'Pending', 'Awaiting confirmation', TRUE, FALSE, 20, CURRENT_TIMESTAMP(6)),
('CONFIRMED', 'Confirmed', 'Order confirmed', TRUE, FALSE, 30, CURRENT_TIMESTAMP(6)),
('ACTIVE', 'Active', 'Currently on rent', FALSE, FALSE, 40, CURRENT_TIMESTAMP(6)),
('OVERDUE', 'Overdue', 'Return overdue', FALSE, FALSE, 50, CURRENT_TIMESTAMP(6)),
('COMPLETED', 'Completed', 'Rental completed', FALSE, TRUE, 60, CURRENT_TIMESTAMP(6)),
('CANCELLED', 'Cancelled', 'Order cancelled', FALSE, TRUE, 70, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Sales Order Status
INSERT INTO sales_order_status (code, name, description, allows_modification, is_terminal, display_order, created_at) VALUES
('DRAFT', 'Draft', 'Order being created', TRUE, FALSE, 10, CURRENT_TIMESTAMP(6)),
('PENDING', 'Pending', 'Awaiting payment', TRUE, FALSE, 20, CURRENT_TIMESTAMP(6)),
('CONFIRMED', 'Confirmed', 'Payment received', TRUE, FALSE, 30, CURRENT_TIMESTAMP(6)),
('PROCESSING', 'Processing', 'Being processed', FALSE, FALSE, 40, CURRENT_TIMESTAMP(6)),
('SHIPPED', 'Shipped', 'Order shipped', FALSE, FALSE, 50, CURRENT_TIMESTAMP(6)),
('DELIVERED', 'Delivered', 'Delivered to customer', FALSE, FALSE, 60, CURRENT_TIMESTAMP(6)),
('COMPLETED', 'Completed', 'Sale completed', FALSE, TRUE, 70, CURRENT_TIMESTAMP(6)),
('CANCELLED', 'Cancelled', 'Order cancelled', FALSE, TRUE, 80, CURRENT_TIMESTAMP(6)),
('REFUNDED', 'Refunded', 'Payment refunded', FALSE, TRUE, 90, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Master Device Types
INSERT INTO master_device_type(code,name,display_order) VALUES
 ('WEB','Web',10),
 ('MOBILE_IOS','Mobile iOS',20),
 ('MOBILE_ANDROID','Mobile Android',30),
 ('TABLET','Tablet',40),
 ('DESKTOP','Desktop',50),
 ('OTHER','Other',99)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Product Image Categories
INSERT INTO product_model_image_category(code,name,display_order) VALUES
 ('MAIN','Main',10),
 ('DETAIL','Detail',20),
 ('LIFESTYLE','Lifestyle',30),
 ('OTHER','Other',99)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Master Customer Tiers
INSERT INTO master_customer_tier(code,name,display_order) VALUES
 ('BRONZE','Bronze',10),
 ('SILVER','Silver',20),
 ('GOLD','Gold',30),
 ('PLATINUM','Platinum',40)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Master Invoice Types
INSERT INTO master_invoice_type(code,name,display_order) VALUES
 ('FINAL','Final',10),
 ('PROFORMA','Proforma',20),
 ('CREDIT_NOTE','Credit Note',30),
 ('DEBIT_NOTE','Debit Note',40)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Master Payment Directions
INSERT INTO master_payment_direction(code,name,display_order) VALUES
 ('IN','In',10),
 ('OUT','Out',20)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Master Payment Statuses
INSERT INTO master_payment_status(code,name,display_order) VALUES
 ('PENDING','Pending',10),
 ('COMPLETED','Completed',20),
 ('FAILED','Failed',30),
 ('REFUNDED','Refunded',40)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Damage Severities
INSERT INTO damage_severity(code,name,severity_rank) VALUES
 ('MINOR','Minor',10),
 ('MODERATE','Moderate',20),
 ('SEVERE','Severe',30),
 ('TOTAL_LOSS','Total Loss',40)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Clothing
INSERT INTO master_gender(code,name,display_order) VALUES
 ('MEN','Men',10),
 ('WOMEN','Women',20),
 ('UNISEX','Unisex',30),
 ('KIDS','Kids',40)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Clothing Seasons
INSERT INTO clothing_season(code,name,display_order) VALUES
 ('SUMMER','Summer',10),
 ('WINTER','Winter',20),
 ('MONSOON','Monsoon',30),
 ('ALL_SEASON','All Season',40)
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- Clothing Size Systems
INSERT INTO clothing_size_system (code, name, description, display_order, created_at) VALUES
('ALPHA',    'Alpha (XS,S,M,L...)',    'Alphabetic garment sizes',      10, CURRENT_TIMESTAMP(6)),
('NUMERIC',  'Numeric (28,30,32...)',  'Numeric sizes (waist/chest)',   20, CURRENT_TIMESTAMP(6)),
('US',       'US Standard',            'US regional sizing',            30, CURRENT_TIMESTAMP(6)),
('EU',       'EU Standard',            'EU regional sizing',            31, CURRENT_TIMESTAMP(6)),
('UK',       'UK Standard',            'UK regional sizing',            32, CURRENT_TIMESTAMP(6)),
('WAIST_IN', 'Waist (inches)',         'Waist measurement (inches)',    40, CURRENT_TIMESTAMP(6)),
('WAIST_CM', 'Waist (cm)',             'Waist measurement (cm)',        41, CURRENT_TIMESTAMP(6)),
('CHEST_CM', 'Chest (cm)',             'Chest measurement (cm)',        42, CURRENT_TIMESTAMP(6))
ON DUPLICATE KEY UPDATE name = VALUES(name), description = VALUES(description);

-- Clothing Sizes
INSERT INTO clothing_size ( clothing_size_system_id, code, name, gender_id, waist_cm, chest_cm, hip_cm, notes, is_active, created_at ) VALUES
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='ALPHA'),
  'XS', 'Extra Small', NULL, NULL, NULL, NULL, 'Alpha size', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='ALPHA'),
  'S', 'Small', NULL, NULL, NULL, NULL, 'Alpha size', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='ALPHA'),
  'M', 'Medium', NULL, NULL, NULL, NULL, 'Alpha size', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='ALPHA'),
  'L', 'Large', NULL, NULL, NULL, NULL, 'Alpha size', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='ALPHA'),
  'XL', 'Extra Large', NULL, NULL, NULL, NULL, 'Alpha size', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='ALPHA'),
  'XXL', 'Double Extra Large', NULL, NULL, NULL, NULL, 'Alpha size', TRUE, CURRENT_TIMESTAMP(6)
),
-- Numeric waist sizes (common men's waist sizes)
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='NUMERIC'),
  '28', '28', NULL, NULL, NULL, NULL, 'Numeric waist', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='NUMERIC'),
  '30', '30', NULL, NULL, NULL, NULL, 'Numeric waist', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='NUMERIC'),
  '32', '32', NULL, NULL, NULL, NULL, 'Numeric waist', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='NUMERIC'),
  '34', '34', NULL, NULL, NULL, NULL, 'Numeric waist', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='NUMERIC'),
  '36', '36', NULL, NULL, NULL, NULL, 'Numeric waist', TRUE, CURRENT_TIMESTAMP(6)
),
(
  (SELECT clothing_size_system_id FROM clothing_size_system WHERE code='NUMERIC'),
  '38', '38', NULL, NULL, NULL, NULL, 'Numeric waist', TRUE, CURRENT_TIMESTAMP(6)
)
ON DUPLICATE KEY UPDATE name = VALUES(name), notes = VALUES(notes);

-- Clothing Colours
INSERT INTO clothing_colour (code, name, hex_code, display_order) VALUES
('BLACK',        'Black',        '#000000',  10),
('WHITE',        'White',        '#FFFFFF',  20),
('GREY',         'Grey',         '#808080',  30),
('CHARCOAL',     'Charcoal',     '#36454F',  40),
('NAVY',         'Navy Blue',    '#000080',  50),
('BLUE',         'Blue',         '#0000FF',  60),
('LIGHT_BLUE',   'Light Blue',   '#ADD8E6',  70),
('GREEN',        'Green',        '#008000',  80),
('OLIVE',        'Olive',        '#808000',  90),
('RED',          'Red',          '#FF0000', 100),
('MAROON',       'Maroon',       '#800000', 110),
('BURGUNDY',     'Burgundy',     '#800020', 120),
('YELLOW',       'Yellow',       '#FFFF00', 130),
('MUSTARD',      'Mustard',      '#FFDB58', 140),
('ORANGE',       'Orange',       '#FFA500', 150),
('PINK',         'Pink',         '#FFC0CB', 160),
('PURPLE',       'Purple',       '#800080', 170),
('LAVENDER',     'Lavender',     '#E6E6FA', 180),
('BROWN',        'Brown',        '#8B4513', 190),
('BEIGE',        'Beige',        '#F5F5DC', 200),
('CREAM',        'Cream',        '#FFFDD0', 210),
('OFF_WHITE',    'Off White',    '#FAF9F6', 220),
('GOLD',         'Gold',         '#D4AF37', 230),
('SILVER',       'Silver',       '#C0C0C0', 240),
('MULTICOLOR',   'Multicolor',   NULL,      250),
('PRINTED',      'Printed',      NULL,      260),
('TRANSPARENT',  'Transparent',  NULL,      270)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  hex_code = VALUES(hex_code);

INSERT INTO order_progress_stage (code, name, description, sequence_order) VALUES
('ORDER_PLACED',        'Order Placed',         'Customer has placed the order',               10),
('PROCESSING',          'Processing',           'Order is being processed',                     20),
('PICKED',              'Picked',               'Items have been picked from inventory',       30),
('PACKED',              'Packed',               'Items have been packed for shipment',         40),
('SHIPPED',             'Shipped',              'Order has been shipped',                       50),
('OUT_FOR_DELIVERY',    'Out for Delivery',     'Order is out for delivery to customer',       60),
('DELIVERED',           'Delivered',            'Order has been delivered to customer',        70),
('COMPLETED',           'Completed',            'Order process completed successfully',        80),
('CANCELLED',           'Cancelled',            'Order has been cancelled',                     90)
ON DUPLICATE KEY UPDATE name=VALUES(name), description=VALUES(description), sequence_order=VALUES(sequence_order);