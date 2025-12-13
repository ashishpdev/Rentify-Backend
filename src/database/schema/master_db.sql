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
-- MASTER ENUM TABLES
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
-- BUSINESS CORE TABLES
-- =========================================================
DROP TABLE IF EXISTS master_business;
CREATE TABLE master_business (
    business_id INT AUTO_INCREMENT PRIMARY KEY,
    business_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    website VARCHAR(255),
    contact_person VARCHAR(255) NOT NULL,
    contact_number VARCHAR(50) NOT NULL,
    address_line VARCHAR(255) NULL,
    city VARCHAR(100) NULL,
    state VARCHAR(100) NULL,
    country VARCHAR(100) NULL,
    pincode VARCHAR(20) NULL,

    status_id INT NOT NULL,
    subscription_type_id INT NOT NULL,
    subscription_status_id INT NOT NULL,
    billing_cycle_id INT NOT NULL,

    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0,

    CONSTRAINT fk_business_status FOREIGN KEY (status_id)
        REFERENCES master_business_status(master_business_status_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_business_subscription_type FOREIGN KEY (subscription_type_id)
        REFERENCES master_subscription_type(master_subscription_type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_business_subscription_status FOREIGN KEY (subscription_status_id)
        REFERENCES master_subscription_status(master_subscription_status_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_business_billing_cycle FOREIGN KEY (billing_cycle_id)
        REFERENCES master_billing_cycle(master_billing_cycle_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_branch;
CREATE TABLE master_branch (
    branch_id INT AUTO_INCREMENT PRIMARY KEY,
    business_id INT NOT NULL,
    branch_name VARCHAR(255) NOT NULL,
    branch_code VARCHAR(100) NOT NULL,
    address_line VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    pincode VARCHAR(20) NOT NULL,
    contact_number VARCHAR(50) NOT NULL,
    timezone VARCHAR(100) NOT NULL COMMENT 'Display timezone for this branch (e.g., Asia/Kolkata). All data stored in UTC.',

    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_deleted TINYINT(1) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,

    INDEX idx_branch_business_id (business_id),
    CONSTRAINT fk_branch_business FOREIGN KEY (business_id)
        REFERENCES master_business(business_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_user;
CREATE TABLE master_user (
    master_user_id INT AUTO_INCREMENT PRIMARY KEY,
    business_id INT NOT NULL,
    branch_id INT DEFAULT NULL,
    role_id INT NOT NULL,
    is_owner BOOLEAN DEFAULT FALSE,

    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    contact_number VARCHAR(50) NOT NULL,

    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0,

    UNIQUE KEY uq_user_email_business_branch (email, business_id, branch_id),
    INDEX idx_user_email (email),
    INDEX idx_user_business (business_id),
    INDEX idx_user_is_owner (is_owner),

    CONSTRAINT fk_user_business FOREIGN KEY (business_id)
        REFERENCES master_business(business_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_user_branch FOREIGN KEY (branch_id)
        REFERENCES master_branch(branch_id)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT fk_user_role FOREIGN KEY (role_id)
        REFERENCES master_role_type(master_role_type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_user_session;
CREATE TABLE master_user_session (
    id CHAR(36) PRIMARY KEY,
    user_id INT NOT NULL,
    session_token TEXT NOT NULL COMMENT 'Encrypted session token (base64 encoded, can be 300-500+ chars)',
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    ip_address VARCHAR(100),

    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC timestamp',
    expiry_at TIMESTAMP(6) NOT NULL COMMENT 'UTC timestamp for session expiry',
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    last_active TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC timestamp of last activity',
    is_active BOOLEAN DEFAULT TRUE,

    INDEX idx_session_expiry (expiry_at),
    INDEX idx_session_user (user_id),
    INDEX idx_session_active_user (user_id, is_active),

    CONSTRAINT fk_session_user FOREIGN KEY (user_id)
        REFERENCES master_user(master_user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_otp;
CREATE TABLE master_otp (
    id CHAR(36) PRIMARY KEY,
    target_identifier VARCHAR(255) NULL COMMENT 'Email or phone number',
    user_id INT NULL COMMENT 'Can be null for unregistered users',
    otp_code_hash VARCHAR(255) NOT NULL,
    otp_type_id INT NOT NULL,
    otp_status_id INT NOT NULL DEFAULT 1, -- Default to PENDING
    attempts INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    ip_address VARCHAR(100),
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC timestamp',
    expires_at TIMESTAMP(6) NOT NULL COMMENT 'UTC timestamp for OTP expiry',
    verified_at TIMESTAMP(6) NULL COMMENT 'UTC timestamp when verified',

    created_by VARCHAR(255) NOT NULL,
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),

    INDEX idx_otp_target (target_identifier),
    INDEX idx_otp_type (otp_type_id),
    INDEX idx_otp_status (otp_status_id),
    INDEX idx_otp_expires (expires_at),

    CONSTRAINT fk_otp_user FOREIGN KEY (user_id)
        REFERENCES master_user(master_user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_otp_type FOREIGN KEY (otp_type_id)
        REFERENCES master_otp_type(master_otp_type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_otp_status FOREIGN KEY (otp_status_id)
        REFERENCES master_otp_status(master_otp_status_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -- =========================================================
-- -- SEED DATA
-- -- =========================================================

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
-- PRODUCT/ASSET ENUM TABLES (UTC timestamps)
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
-- Seed lookup rows (INSERT IGNORE to avoid duplicates)
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

-- ============================
-- CORE: categories, models, asset units
-- ============================

-- product_segment (electronics, furniture, appliances)
DROP TABLE IF EXISTS product_segment;
CREATE TABLE product_segment (
  product_segment_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  code VARCHAR(128) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,

  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  CONSTRAINT uq_product_segment_business_branch_code UNIQUE (business_id, branch_id, code),
  INDEX idx_product_segment_business (business_id),

  CONSTRAINT fk_product_segment_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_segment_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- product_category (CAMERA, LAPTOP, MIC)
DROP TABLE IF EXISTS product_category;
CREATE TABLE product_category (
  product_category_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  product_segment_id INT NOT NULL,
  code VARCHAR(128) NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,

  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  CONSTRAINT uq_product_category_business_branch_segment_code UNIQUE (business_id, branch_id, product_segment_id, code),
  INDEX idx_product_category_business (business_id),

  CONSTRAINT fk_product_category_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_category_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_category_segment FOREIGN KEY (product_segment_id)
    REFERENCES product_segment(product_segment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- product_model (Canon EOS 5D Mark IV, iPhone 13 Pro)
DROP TABLE IF EXISTS product_model;
CREATE TABLE product_model (
  product_model_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  product_segment_id INT NOT NULL,
  product_category_id INT NOT NULL,
  model_name VARCHAR(255) NOT NULL,
  description TEXT,
  default_rent DECIMAL(12,2) NOT NULL,
  default_deposit DECIMAL(12,2) NOT NULL,
  default_warranty_days INT,
  
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_product_model_business_category (business_id, product_category_id),
  INDEX idx_product_model_business_name (business_id, model_name),
  INDEX idx_product_model_business_branch (business_id, branch_id),

  CONSTRAINT uq_product_model_business_branch_segment_category_name UNIQUE (business_id, branch_id, product_segment_id, product_category_id, model_name),

  CONSTRAINT fk_product_model_business  FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_model_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_model_segment FOREIGN KEY (product_segment_id)
    REFERENCES product_segment(product_segment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_model_category FOREIGN KEY (product_category_id)
    REFERENCES product_category(product_category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- asset (physical serialized item)
-- Ex: Canon EOS 5D Mark IV with serial no XYZ12345
DROP TABLE IF EXISTS asset;
CREATE TABLE asset (
  asset_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  product_segment_id INT NOT NULL,
  product_category_id INT NOT NULL,
  product_model_id INT NOT NULL,
  serial_number VARCHAR(200) NOT NULL,
  product_status_id INT NOT NULL,
  product_condition_id INT NOT NULL,
  purchase_price DECIMAL(12,2),
  purchase_date DATETIME(6),
  current_value DECIMAL(12,2),
  rent_price DECIMAL(12,2),
  deposit_amount DECIMAL(12,2),

  source_type_id INT NOT NULL,
  borrowed_from_business_name VARCHAR(255) NULL,
  borrowed_from_branch_name VARCHAR(255) NULL,
  purchase_bill_url VARCHAR(1024),


  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  ADD CONSTRAINT chk_asset_prices CHECK (
    (purchase_price IS NULL OR purchase_price >= 0) AND
    (current_value IS NULL OR current_value >= 0) AND
    (rent_price IS NULL OR rent_price >= 0) AND
    (deposit_amount IS NULL OR deposit_amount >= 0)
  ),

  INDEX idx_asset_business_object (business_id),
  INDEX idx_asset_business_model (business_id, product_model_id),
  INDEX idx_asset_serial (serial_number),
  INDEX idx_asset_source (business_id, source_type_id),
  INDEX idx_asset_model_branch (product_model_id, branch_id),
  INDEX idx_asset_model_status (business_id, branch_id, product_model_id, product_status_id, asset_id),
  INDEX idx_asset_status_model (product_status_id, product_model_id, branch_id);

  CONSTRAINT uq_asset_business_branch_model_serial UNIQUE (business_id, branch_id, product_model_id, serial_number),

  CONSTRAINT fk_asset_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_product_segment FOREIGN KEY (product_segment_id)
    REFERENCES product_segment(product_segment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_product_category FOREIGN KEY (product_category_id)
    REFERENCES product_category(product_category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_product_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_product_status FOREIGN KEY (product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_product_condition FOREIGN KEY (product_condition_id)
    REFERENCES product_condition(product_condition_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_source_type FOREIGN KEY (source_type_id)
    REFERENCES source_type(source_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS customer;
CREATE TABLE customer (
  customer_id INT UNIQUE NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  first_name VARCHAR(200) NOT NULL,
  last_name VARCHAR(200) NULL,
  email VARCHAR(255) NOT NULL,
  contact_number VARCHAR(80) NOT NULL,
  address_line VARCHAR(255) NULL,
  city VARCHAR(100) NULL,
  state VARCHAR(100) NULL,
  country VARCHAR(100) NULL,
  pincode VARCHAR(20) NULL,

  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_customer_business_contact (business_id, contact_number),
  UNIQUE KEY uq_customer_email_business_branch (email, business_id, branch_id),

  CONSTRAINT fk_customer_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_customer_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Stores each specific item that was rented as part of that rental.
DROP TABLE IF EXISTS rental_item;
CREATE TABLE rental_item (
  rental_item_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  rental_id INT NOT NULL,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  product_segment_id INT NOT NULL,
  product_category_id INT NOT NULL,
  product_model_id INT NOT NULL,
  asset_id INT NOT NULL,
  product_rental_status_id INT NOT NULL,
  customer_id INT NOT NULL,
  rent_price DECIMAL(14,2) NOT NULL,
  notes TEXT,
  created_by VARCHAR(255),
  created_at DATETIME(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),

  INDEX idx_rental_item_rental (rental_id),
  INDEX idx_rental_item_model (product_model_id),
  INDEX idx_rental_item_unit (asset_id),

  CONSTRAINT fk_rental_item_rental FOREIGN KEY (rental_id)
    REFERENCES rental(rental_id)
    ON DELETE CASCADE ON UPDATE CASCADE,

  CONSTRAINT fk_product_rental_status_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_rental_status_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_rental_status_product_segment FOREIGN KEY (product_segment_id)
    REFERENCES product_segment(product_segment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE, 

  CONSTRAINT fk_product_rental_status_product_category FOREIGN KEY (product_category_id)
    REFERENCES product_category(product_category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_rental_status_product_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_rental_status_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_rental_status_product_rental_status FOREIGN KEY (product_rental_status_id)
    REFERENCES product_rental_status(product_rental_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_rental_status_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS invoice_photos;
CREATE TABLE invoice_photos (
  invoice_photo_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  customer_id INT NOT NULL,
  invoice_url VARCHAR(2048) NOT NULL,

  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_deleted TINYINT(1) DEFAULT 0,

  CONSTRAINT fk_invoice_photo_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_invoice_photo_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_invoice_photo_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE

) ENGINE=InnoDB;

DROP TABLE IF EXISTS rental;
CREATE TABLE rental (
  rental_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  customer_id INT NOT NULL,
  user_id INT NOT NULL COMMENT 'Staff who created the rental',
  invoice_no VARCHAR(200) NOT NULL,
  invoice_photo_id INT NULL,
  invoice_date TIMESTAMP(6) NOT NULL COMMENT 'UTC timestamp',
  start_date TIMESTAMP(6) NOT NULL COMMENT 'UTC timestamp when given on rent',
  due_date TIMESTAMP(6) NOT NULL COMMENT 'UTC timestamp - expected return date',
  end_date TIMESTAMP(6) NULL COMMENT 'UTC timestamp - actual returned date',
  total_items INT NOT NULL DEFAULT 0,
  security_deposit DECIMAL(12,2) NOT NULL DEFAULT 0,
  subtotal_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  discount_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(14,2) NOT NULL,
  paid_amount DECIMAL(14,2) DEFAULT 0,
  billing_period_id INT NOT NULL,
  currency VARCHAR(16) DEFAULT 'INR',
  notes TEXT,
  product_rental_status_id INT NOT NULL,
  is_overdue BOOLEAN GENERATED ALWAYS AS (
    CASE 
      WHEN end_date IS NULL AND due_date < UTC_TIMESTAMP(6) THEN 1
      ELSE 0
    END
  ) STORED,

  CONSTRAINT chk_rental_amounts CHECK (
    subtotal_amount >= 0 AND
    tax_amount >= 0 AND
    discount_amount >= 0 AND
    total_amount >= 0 AND
    paid_amount >= 0 AND
    security_deposit >= 0
  ),
  CONSTRAINT chk_rental_dates CHECK (
    start_date <= due_date AND
    (end_date IS NULL OR end_date >= start_date)
  ),

  INDEX idx_rental_business (business_id),
  INDEX idx_rental_customer (customer_id),
  INDEX idx_rental_dates (start_date, due_date),
  INDEX idx_rental_dates_status (start_date, due_date, is_active),
  INDEX idx_rental_customer_dates (customer_id, start_date, due_date),
  INDEX idx_rental_product (product_rental_status_id),
  INDEX idx_rental_overdue (is_overdue, business_id, branch_id),

  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  CONSTRAINT fk_rental_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_rental_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_rental_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_rental_user FOREIGN KEY (user_id)
    REFERENCES master_user(master_user_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_rental_invoice_photo FOREIGN KEY (invoice_photo_id)
    REFERENCES invoice_photos(invoice_photo_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_rental_billing_period FOREIGN KEY (billing_period_id)
    REFERENCES billing_period(billing_period_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_rental_product_rental_status FOREIGN KEY (product_rental_status_id)
    REFERENCES product_rental_status(product_rental_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS rental_payments;
CREATE TABLE rental_payments (
  rental_payment_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  rental_id INT NOT NULL,
  paid_on TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC timestamp',
  amount DECIMAL(14,2) NOT NULL,
  mode_of_payment_id INT,
  reference_no VARCHAR(255),
  notes TEXT,
  
  created_by VARCHAR(200),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_rental_payment_rental (rental_id),

  CONSTRAINT fk_rental_payment_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_rental_payment_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_rental_payment_rental FOREIGN KEY (rental_id)
    REFERENCES rental(rental_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_payment_mode FOREIGN KEY (mode_of_payment_id)
    REFERENCES payment_mode(payment_mode_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- MAINTENANCE & TRACKING TABLES (UTC timestamps)
-- =========================================================

DROP TABLE IF EXISTS maintenance_records;
CREATE TABLE maintenance_records (
  maintenance_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  asset_id INT NOT NULL,
  maintenance_status_id INT NOT NULL,
  reported_by VARCHAR(255),
  reported_on TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC timestamp',
  assigned_to VARCHAR(255),
  scheduled_date TIMESTAMP(6) NULL COMMENT 'UTC timestamp',
  completed_on TIMESTAMP(6) NULL COMMENT 'UTC timestamp',
  cost DECIMAL(14,2),
  remarks TEXT,
  
  INDEX idx_maintenance_inv (asset_id),
  
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  CONSTRAINT fk_maintenance_record_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_maintenance_record_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_maintenance_record_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_maintenance_record_status FOREIGN KEY (maintenance_status_id)
    REFERENCES maintenance_status(maintenance_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS damage_reports;
CREATE TABLE damage_reports (
  damage_report_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  asset_id INT NOT NULL,
  reported_by_id INT,
  reported_on TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC timestamp',
  description TEXT NOT NULL,
  estimated_cost DECIMAL(14,2),
  resolved TINYINT(1) DEFAULT 0,
  resolution_notes TEXT,
  
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  CONSTRAINT fk_damage_report_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_damage_report_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_damage_report_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- RESERVATIONS & DEPOSITS (UTC timestamps)
-- =========================================================

DROP TABLE IF EXISTS reservations;
CREATE TABLE reservations (
  reservation_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  customer_id INT NOT NULL,
  product_model_id INT NOT NULL,
  reservation_status_id INT NOT NULL,
  reserved_from TIMESTAMP(6) NOT NULL COMMENT 'UTC timestamp',
  reserved_until TIMESTAMP(6) NOT NULL COMMENT 'UTC timestamp',
  
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_reservations_dates (reserved_from, reserved_until),
  INDEX idx_reservation_item_dates (start_date, end_date, reservation_id);


  CONSTRAINT fk_reservation_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_reservation_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_reservation_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_reservation_product_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE, 

  CONSTRAINT fk_reservation_reservation_status FOREIGN KEY (reservation_status_id)
    REFERENCES reservation_status(reservation_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS reservation_item;
CREATE TABLE reservation_item (
  reservation_item_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  reservation_id INT NOT NULL,
  product_model_id INT NULL,
  asset_id INT NULL,
  quantity INT NOT NULL DEFAULT 1,
  start_date TIMESTAMP(6) NOT NULL,
  end_date TIMESTAMP(6) NOT NULL,
  created_by VARCHAR(255),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_res_item_reservation (reservation_id),
  INDEX idx_res_item_model (product_model_id),
  INDEX idx_reservation_item_dates (start_date, end_date, reservation_id);

  CONSTRAINT fk_reservation_item_reservation FOREIGN KEY (reservation_id)
    REFERENCES reservations(reservation_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
    
  CONSTRAINT fk_reservation_item_product_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_reservation_item_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;


-- =========================================================
-- images for products like
-- Ex: Canon EOS 5D Mark IV, iPhone 13 Pro
DROP TABLE IF EXISTS product_model_images;
CREATE TABLE product_model_images (
  product_model_image_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  product_model_id INT NULL,
  url VARCHAR(1024) NOT NULL,
  alt_text VARCHAR(512),
  is_primary TINYINT(1) DEFAULT 0,
  image_order INT NOT NULL DEFAULT 0,
  
  created_by VARCHAR(255),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_product_model_order (product_model_id, business_id, branch_id, image_order),
  INDEX idx_is_primary (is_primary),

  CONSTRAINT fk_product_image_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_image_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_product_image_product_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- ========================================================
-- STOCK TABLE
DROP TABLE IF EXISTS stock;
CREATE TABLE stock (
  stock_id                                INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT                         NOT NULL,
  branch_id INT                           NOT NULL,
  product_segment_id INT                  NOT NULL,
  product_category_id INT                 NOT NULL,
  product_model_id INT                    NOT NULL,

  quantity_available     INT NOT NULL DEFAULT 0,  -- in the branch and free (not reserved / not on rent / not in maintenance / not damaged / not lost)
  quantity_reserved      INT NOT NULL DEFAULT 0,  -- reserved for inbound/outbound orders or holds (not available)
  quantity_on_rent       INT NOT NULL DEFAULT 0,  -- currently out on rent / leased
  quantity_in_maintenance INT NOT NULL DEFAULT 0, -- in maintenance / servicing
  quantity_damaged       INT NOT NULL DEFAULT 0,  -- physically damaged (repairable or marked)
  quantity_lost          INT NOT NULL DEFAULT 0,  -- lost / irrecoverable


  quantity_total INT AS (
    quantity_available
    + quantity_reserved
    + quantity_on_rent
    + quantity_in_maintenance
    + quantity_damaged
    + quantity_lost
  ) STORED, -- total physical units in branch (sum of all states)

  is_product_model_rentable TINYINT(1) GENERATED ALWAYS AS (
    CASE WHEN quantity_available > 0 THEN 1 ELSE 0 END
  ) STORED,

  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  last_updated_by VARCHAR(255),
  last_updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),

  CONSTRAINT uq_stock_business_branch_model UNIQUE (business_id, branch_id, product_model_id),

  INDEX idx_stock_business_category (business_id, product_category_id),
  INDEX idx_stock_business_segment  (business_id, product_segment_id),
  INDEX idx_stock_business_branch   (business_id, branch_id),
  INDEX idx_stock_last_updated_at      (last_updated_at),

  CONSTRAINT fk_stock_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_stock_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_stock_product_segment FOREIGN KEY (product_segment_id)
    REFERENCES product_segment(product_segment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_stock_product_category FOREIGN KEY (product_category_id)
    REFERENCES product_category(product_category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE, 

  CONSTRAINT fk_stock_product_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CHECK (quantity_available >= 0),
  CHECK (quantity_reserved >= 0),
  CHECK (quantity_on_rent >= 0),
  CHECK (quantity_in_maintenance >= 0),
  CHECK (quantity_damaged >= 0),
  CHECK (quantity_lost >= 0)
) ENGINE=InnoDB;



-- =========================================================
DROP TABLE IF EXISTS location_history;
CREATE TABLE location_history (
  location_history_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  asset_id INT NOT NULL,
  electronics_device_id INT NULL,
  source VARCHAR(255),
  latitude DECIMAL(10,6),
  longitude DECIMAL(10,6),
  road VARCHAR(255),
  city VARCHAR(100),
  district VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100),
  pincode VARCHAR(20),
  recorded_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC timestamp',
  
  INDEX idx_loc_hist_inv (business_id, asset_id, recorded_at),
  
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  CONSTRAINT fk_location_history_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_location_history_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_location_history_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS deposit;
CREATE TABLE deposit (
  deposit_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  customer_id INT NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  held_since TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT 'UTC timestamp',
  released_on TIMESTAMP(6) NULL COMMENT 'UTC timestamp',
  released_amount DECIMAL(14,2),
  notes TEXT,
  
  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  CONSTRAINT fk_deposit_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_deposit_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_deposit_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- LOGGING TABLES (UTC timestamps)
-- =========================================================  

DROP TABLE IF EXISTS notification_log;
CREATE TABLE notification_log (
  notification_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  customer_id INT NOT NULL,        
  rental_id INT NULL,        

  contact_type_id INT NOT NULL,
  contact_value VARCHAR(512) NOT NULL, -- mobile number or email
  channel_id INT NOT NULL,

  template_code VARCHAR(200) NULL, -- e.g. RENTAL_DUE_REMINDER, INVOICE_CREATED
  subject VARCHAR(512) NULL,
  message TEXT NULL,              -- full rendered message sent

  notification_status_id INT NOT NULL,
  provider_response TEXT NULL,
  attempt_count INT NOT NULL DEFAULT 0,
  scheduled_for TIMESTAMP(6) NULL, 
  sent_on TIMESTAMP(6) NULL,       -- when it was actually sent
  delivered_on TIMESTAMP(6) NULL,  -- if provider reports final delivery

  external_reference VARCHAR(512) NULL, -- provider message id / external id
  reference_entity VARCHAR(128) NULL,   -- e.g. 'rental','asset','customer' - helpful for quick queries

  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_notification_business (business_id),
  INDEX idx_notification_branch (branch_id),
  INDEX idx_notification_customer (customer_id),
  INDEX idx_notification_rental (rental_id),
  INDEX idx_notification_status_scheduled (notification_status_id, scheduled_for),
  INDEX idx_notification_contact_value (contact_value),

  CONSTRAINT fk_notification_log_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_notification_log_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT fk_notification_log_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_notification_log_rental FOREIGN KEY (rental_id)
    REFERENCES rental(rental_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_notification_log_contact_type FOREIGN KEY (contact_type_id)
    REFERENCES contact_type(contact_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_notification_log_channel FOREIGN KEY (channel_id)
    REFERENCES notification_channel(notification_channel_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_notification_log_status FOREIGN KEY (notification_status_id)
    REFERENCES notification_status(notification_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE

) ENGINE=InnoDB;

DROP TABLE IF EXISTS proc_error_log;
CREATE TABLE IF NOT EXISTS proc_error_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    proc_name VARCHAR(128) NOT NULL,
    proc_args TEXT,
    mysql_errno INT NULL,
    sql_state CHAR(5) NULL,
    error_message TEXT,
    server_time_utc DATETIME(6) NOT NULL DEFAULT (UTC_TIMESTAMP(6))
);

DROP TABLE IF EXISTS stock_movements;
CREATE TABLE stock_movements (
  stock_movements_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,
  product_model_id INT NOT NULL,
  inventory_movement_type_id INT NOT NULL,
  quantity INT NOT NULL,
  from_branch_id INT NULL,
  to_branch_id INT NULL,
  from_product_status_id INT NULL,
  to_product_status_id INT NULL,

  related_rental_id INT NULL,
  related_reservation_id INT NULL,
  related_maintenance_id INT NULL,
  reference_no VARCHAR(255) NULL,
  note TEXT NULL,
  metadata JSON NULL COMMENT 'extra structured data (photos, condition report, operator, device_id)',

  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_sm_business_model (business_id, branch_id, product_model_id),
  INDEX idx_sm_type (inventory_movement_type_id),
  INDEX idx_sm_dates (created_at),
  INDEX idx_stock_movements_dates (business_id, branch_id, created_at),
  INDEX idx_asset_movements_dates (business_id, branch_id, created_at),

  CONSTRAINT fk_stock_movements_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_product_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_type FOREIGN KEY (inventory_movement_type_id)
    REFERENCES inventory_movement_type(inventory_movement_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_from_branch FOREIGN KEY (from_branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_to_branch FOREIGN KEY (to_branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_from_state FOREIGN KEY (from_product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_to_state FOREIGN KEY (to_product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_rental FOREIGN KEY (related_rental_id)
    REFERENCES rental(rental_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_reservation FOREIGN KEY (related_reservation_id)
    REFERENCES reservations(reservation_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_stock_movements_maintenance FOREIGN KEY (related_maintenance_id)
    REFERENCES maintenance_records(maintenance_id)
    ON DELETE SET NULL ON UPDATE CASCADE

) ENGINE=InnoDB;

DROP TABLE IF EXISTS asset_movements;
CREATE TABLE asset_movements (
  asset_movement_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  business_id INT NOT NULL,
  branch_id INT NOT NULL,                     -- branch where movement was recorded (nullable if cross-branch)
  product_model_id INT NULL,                  -- redundant but useful for fast queries
  asset_id INT NOT NULL,
  inventory_movement_type_id INT NOT NULL,    -- unified enum
  quantity INT NOT NULL DEFAULT 1,            -- normally 1 for serialized assets; keep for compatibility
  from_branch_id INT NULL,
  to_branch_id INT NULL,
  from_product_status_id INT NULL,
  to_product_status_id INT NULL,

  related_rental_id INT NULL,
  related_reservation_id INT NULL,
  related_maintenance_id INT NULL,
  reference_no VARCHAR(255) NULL,
  note TEXT NULL,
  metadata JSON NULL COMMENT 'extra structured data (photos, condition report, operator, device_id)',

  created_by VARCHAR(255) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(255),
  updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted TINYINT(1) DEFAULT 0,

  INDEX idx_asset_mov_asset (business_id, asset_id),
  INDEX idx_asset_mov_model (business_id, product_model_id),
  INDEX idx_asset_mov_type (inventory_movement_type_id),
  INDEX idx_asset_mov_dates (created_at),

  CONSTRAINT fk_asset_movements_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_type FOREIGN KEY (inventory_movement_type_id)
    REFERENCES inventory_movement_type(inventory_movement_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_from_branch FOREIGN KEY (from_branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_to_branch FOREIGN KEY (to_branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_from_state FOREIGN KEY (from_product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_to_state FOREIGN KEY (to_product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_rental FOREIGN KEY (related_rental_id)
    REFERENCES rental(rental_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_reservation FOREIGN KEY (related_reservation_id)
    REFERENCES reservations(reservation_id)
    ON DELETE SET NULL ON UPDATE CASCADE,

  CONSTRAINT fk_asset_movements_maintenance FOREIGN KEY (related_maintenance_id)
    REFERENCES maintenance_records(maintenance_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;


-- ========================================================
-- AUDIT TRIGGER
-- ========================================================

-- Asset status change audit table
DROP TABLE IF EXISTS asset_status_audit;
CREATE TABLE asset_status_audit (
  audit_id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL,
  old_status_id INT,
  new_status_id INT,
  changed_by VARCHAR(255),
  changed_at TIMESTAMP(6) DEFAULT CURRENT_TIMESTAMP(6),
  reason VARCHAR(500),
  
  INDEX idx_audit_asset (asset_id, changed_at),
  INDEX idx_audit_dates (changed_at),
  
  CONSTRAINT fk_audit_asset FOREIGN KEY (asset_id) 
    REFERENCES asset(asset_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Trigger to log status changes
DROP TRIGGER IF EXISTS trg_asset_status_change;
CREATE TRIGGER trg_asset_status_change
AFTER UPDATE ON asset
FOR EACH ROW
BEGIN
  IF OLD.product_status_id != NEW.product_status_id THEN
    INSERT INTO asset_status_audit (
      asset_id, old_status_id, new_status_id, changed_by, reason
    ) VALUES (
      NEW.asset_id, 
      OLD.product_status_id, 
      NEW.product_status_id, 
      NEW.updated_by,
      'Status change via update'
    );
  END IF;
END;