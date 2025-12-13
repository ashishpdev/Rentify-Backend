-- ========================================================
-- RENTAL MANAGEMENT SYSTEM - MASTER DATABASE SCHEMA
-- ========================================================
-- TIME ZONE: All timestamps stored in UTC
-- Server timezone should be set to UTC to avoid conversion issues
-- ========================================================

-- Force UTC timezone for this session
SET time_zone = '+00:00';

-- ========================================================
-- ONLY USE WHEN DROP TABLE WHICH IS HAVING FOREIGN KEY CONSTRAINTS
-- SET FOREIGN_KEY_CHECKS=0;
-- SET FOREIGN_KEY_CHECKS=1;
-- ========================================================

-- Diagram : "https://dbdiagram.io/d/tenant_db-691763986735e11170e19b53"
-- =========================================================
-- DATABASE INITIALIZATION
-- =========================================================
CREATE DATABASE IF NOT EXISTS master_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE master_db;


-- =========================================================
    /* MASTER ENUM */
-- =========================================================

DROP TABLE IF EXISTS master_business_status;
CREATE TABLE master_business_status (
    master_business_status_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_role_type;
CREATE TABLE master_role_type (
    master_role_type_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_deleted TINYINT(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_subscription_type;
CREATE TABLE master_subscription_type (
    master_subscription_type_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    max_branches INT DEFAULT 1,
    max_users INT DEFAULT 1,
    max_items INT DEFAULT 20,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_subscription_status;
CREATE TABLE master_subscription_status (
    master_subscription_status_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_billing_cycle;
CREATE TABLE master_billing_cycle (
    master_billing_cycle_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_otp_type;
CREATE TABLE master_otp_type (
    master_otp_type_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_otp_status;
CREATE TABLE master_otp_status (
    master_otp_status_id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;



-- =========================================================
    /* PRODUCT/ASSET ENUM */
-- =========================================================

-- Status before give on rent
DROP TABLE IF EXISTS product_status;
CREATE TABLE product_status (
  product_status_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS product_condition;
CREATE TABLE product_condition (
  product_condition_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- used for rental transaction status after issue
DROP TABLE IF EXISTS product_rental_status;
CREATE TABLE product_rental_status (
  product_rental_status_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS inventory_movement_type;
CREATE TABLE inventory_movement_type (
  inventory_movement_type_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL DEFAULT 'system',
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS billing_period;
CREATE TABLE billing_period (
  billing_period_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS payment_mode;
CREATE TABLE payment_mode (
  payment_mode_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS maintenance_status;
CREATE TABLE maintenance_status (
  maintenance_status_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS reservation_status;
CREATE TABLE reservation_status (
  reservation_status_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS source_type;
CREATE TABLE source_type (
  source_type_id INT NOT NULL PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS contact_type;
CREATE TABLE contact_type (
  contact_type_id INT NOT NULL PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS notification_channel;
CREATE TABLE notification_channel (
  notification_channel_id INT NOT NULL PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS notification_status;
CREATE TABLE notification_status (
  notification_status_id INT NOT NULL PRIMARY KEY,
  code VARCHAR(64) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  created_by VARCHAR(255),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;



-- =========================================================
 /* SEED MASTER ENUM */
-- =========================================================

INSERT INTO master_business_status (code, name, description, created_by) VALUES
('ACTIVE', 'Active', 'Business is active', 'system'),
('INACTIVE', 'Inactive', 'Business is inactive', 'system'),
('SUSPENDED', 'Suspended', 'Business temporarily suspended', 'system'),
('TERMINATED', 'Terminated', 'Business permanently closed', 'system');

INSERT INTO master_role_type (code, name, description, created_by) VALUES
('OWNER', 'Owner', 'Business Owner with full access', 'system'),
('ADMIN', 'Admin', 'Administrator with management access', 'system'),
('MANAGER', 'Manager', 'Manager with operational access', 'system'),
('STAFF', 'Staff', 'Staff member with limited access', 'system'),
('VIEWER', 'Viewer', 'Read-only access user', 'system');

INSERT INTO master_subscription_type (code, name, description, max_branches, max_users, max_items, created_by) VALUES
('TRIAL', 'Trial', 'Trial plan', 1, 1, 20, 'system'),
('BASIC', 'Basic', 'Basic plan', 1, 5, 100, 'system'),
('STANDARD', 'Standard', 'Standard plan', 3, 10, 500, 'system'),
('PREMIUM', 'Premium', 'Premium plan', 5, 50, 2000, 'system'),
('ENTERPRISE', 'Enterprise', 'Enterprise plan', 10, 200, 10000, 'system'),
('CUSTOM', 'Custom', 'Custom plan as per requirement', 50, 500, 50000, 'system');

INSERT INTO master_subscription_status (code, name, description, created_by) VALUES
('ACTIVE', 'Active', 'Subscription is active', 'system'),
('INACTIVE', 'Inactive', 'Subscription is inactive', 'system'),
('SUSPENDED', 'Suspended', 'Subscription temporarily disabled', 'system'),
('CANCELLED', 'Cancelled', 'Subscription cancelled by user', 'system'),
('EXPIRED', 'Expired', 'Subscription expired', 'system');

INSERT INTO master_billing_cycle (code, name, created_by) VALUES
('MONTHLY', 'Monthly', 'system'),
('QUARTERLY', 'Quarterly', 'system'),
('YEARLY', 'Yearly', 'system'),
('LIFETIME', 'Lifetime', 'system');

INSERT INTO master_otp_type (code, name, created_by) VALUES
('LOGIN', 'Login Verification', 'system'),
('REGISTER', 'Register Verification', 'system'),
('RESET_PASSWORD', 'Password Reset', 'system'),
('VERIFY_EMAIL', 'Email Verification', 'system'),
('VERIFY_PHONE', 'Phone Verification', 'system'),
('TWO_FACTOR', 'Two Factor Authentication', 'system');

INSERT into master_otp_status (code, name, created_by) VALUES
('PENDING', 'Pending', 'system'),
('VERIFIED', 'Verified', 'system'),
('EXPIRED', 'Expired', 'system'),
('FAILED', 'Failed', 'system');



-- =========================================================
    /* SEED PRODUCT/ASSET ENUM */
-- =========================================================
INSERT IGNORE INTO product_status (code, name, description, created_by) VALUES
  ('PROCUREMENT','Procurement','Item is being procured','system'),
  ('AVAILABLE','Available','Item is available for rent','system'),
  ('RESERVED','Reserved','Item reserved, not available','system'),
  ('RENTED','Rented','Item currently rented','system'),
  ('MAINTENANCE','Maintenance','Item under maintenance','system'),
  ('DAMAGE','Damage','Item damaged','system'),
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

INSERT IGNORE INTO inventory_movement_type (code, name, description, created_by) VALUES
  ('ADD', 'Add Stock', 'Adding new stock to inventory', 'system'),
  ('REMOVE', 'Remove Stock', 'Removing stock from inventory', 'system'),
  ('RENTAL_OUT', 'Rental Out', 'Item issued for rental', 'system'),
  ('RENTAL_RETURN', 'Rental Return', 'Item returned from rental', 'system'),
  ('RESERVE', 'Reserve Item', 'Item reserved for customer', 'system'),
  ('UNRESERVE', 'Unreserve Item', 'Item unreserved/cancelled', 'system'),
  ('MAINTENANCE_IN', 'Maintenance In', 'Item sent for maintenance', 'system'),
  ('MAINTENANCE_OUT', 'Maintenance Out', 'Item returned from maintenance', 'system'),
  ('MARK_DAMAGED', 'Marked Damaged', 'Item reported as damaged', 'system'),
  ('LOST', 'Lost', 'Item reported as lost', 'system'),
  ('RETIRE', 'Retire Item', 'Item retired from inventory', 'system');

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

INSERT IGNORE INTO source_type (source_type_id, code, name, description, created_by) VALUES
    (1, 'OWNED', 'Owned', 'Asset owned by business', 'system'),
    (2, 'BORROWED', 'Borrowed', 'Asset borrowed/loaned from another party', 'system')

INSERT IGNORE INTO contact_type (contact_type_id, code, name, description, created_by) VALUES
    (1, 'MOBILE', 'Mobile', 'Mobile phone number (SMS) contact', 'system'),
    (2, 'EMAIL', 'Email', 'Email contact', 'system'),
    (3, 'BOTH', 'Both', 'Both mobile and email', 'system')

INSERT IGNORE INTO notification_channel (notification_channel_id, code, name, description, created_by) VALUES
    (1, 'SMS', 'SMS', 'SMS / Text messages', 'system'),
    (2, 'EMAIL', 'Email', 'Email messages', 'system'),
    (3, 'PUSH', 'Push', 'Push notification (mobile/web)', 'system'),
    (4, 'WHATSAPP', 'WhatsApp', 'WhatsApp message via provider', 'system'),
    (5, 'OTHER', 'Other', 'Other/third-party channel', 'system')

INSERT IGNORE INTO notification_status (notification_status_id, code, name, description, created_by) VALUES
    (1, 'PENDING', 'Pending', 'Pending to be sent', 'system'),
    (2, 'SCHEDULED', 'Scheduled', 'Scheduled for sending', 'system'),
    (3, 'SENT', 'Sent', 'Sent to provider', 'system'),
    (4, 'DELIVERED', 'Delivered', 'Delivered to recipient (provider reported)', 'system'),
    (5, 'FAILED', 'Failed', 'Delivery failed', 'system')

