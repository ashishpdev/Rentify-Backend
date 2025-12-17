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
-- Diagram : "https://dbdiagram.io/d/tenant_db-691763986735e11170e19b53"
-- ========================================================

SET time_zone = '+00:00';
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE DATABASE IF NOT EXISTS master_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE master_db;

-- =========================================================
-- BUSINESS CORE TABLES
-- =========================================================

DROP TABLE IF EXISTS master_business;
CREATE TABLE master_business (
    business_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    business_name VARCHAR(200) NOT NULL,
    email VARCHAR(255) NOT NULL,
    website VARCHAR(255),
    contact_person VARCHAR(200) NOT NULL,
    contact_number VARCHAR(20) NOT NULL,
    
    address_line VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    country CHAR(2) COMMENT 'ISO 3166-1 alpha-2',
    pincode VARCHAR(20),
    
    status_id TINYINT UNSIGNED NOT NULL,
    subscription_type_id TINYINT UNSIGNED NOT NULL,
    subscription_status_id TINYINT UNSIGNED NOT NULL,
    billing_cycle_id TINYINT UNSIGNED NOT NULL,
    subscription_start_date DATE,
    subscription_end_date DATE,
       
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
        
    UNIQUE KEY uq_business_email (email),
    INDEX idx_business_status (status_id, is_active),
    INDEX idx_business_subscription (subscription_type_id, subscription_status_id),
    INDEX idx_business_created (created_at DESC),
    INDEX idx_business_active_status (is_active, status_id),
        
    INDEX idx_business_list_cover (is_active, status_id, business_name, business_id),
    
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
        ON DELETE RESTRICT ON UPDATE CASCADE,
        
    CONSTRAINT chk_business_dates CHECK (
        subscription_end_date IS NULL OR subscription_end_date >= subscription_start_date
    )
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Business entities with optimized indexing for multi-tenant queries';

DROP TABLE IF EXISTS master_branch;
CREATE TABLE master_branch (
    branch_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    business_id INT UNSIGNED NOT NULL,
    branch_name VARCHAR(200) NOT NULL,
    branch_code VARCHAR(50) NOT NULL,
    
    address_line VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    country CHAR(2) NOT NULL,
    pincode VARCHAR(20) NOT NULL,
    contact_number VARCHAR(20) NOT NULL,
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
        
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
        
    UNIQUE KEY uq_branch_business_code (business_id, branch_code),
    INDEX idx_branch_business_active (business_id, is_active),
    INDEX idx_branch_created (created_at DESC),
        
    INDEX idx_branch_list_cover (business_id, is_active, branch_name, branch_id),
    
    CONSTRAINT fk_branch_business FOREIGN KEY (business_id)
        REFERENCES master_business(business_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Business branches with optimized multi-tenant access';

DROP TABLE IF EXISTS master_user;
CREATE TABLE master_user (
    master_user_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    business_id INT UNSIGNED NOT NULL,
    branch_id INT UNSIGNED DEFAULT NULL,
    role_id TINYINT UNSIGNED NOT NULL,
    is_owner BOOLEAN NOT NULL DEFAULT FALSE,
        
    name VARCHAR(200) NOT NULL,
    email VARCHAR(255) NOT NULL,
    hash_password VARCHAR(255) NOT NULL,
    contact_number VARCHAR(20) NOT NULL,
      
    locked_until TIMESTAMP(6) NULL,
    last_login_at TIMESTAMP(6) NULL,
        
    created_by VARCHAR(100) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(100),
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
        
    UNIQUE KEY uq_user_email_business (email, business_id),
    INDEX idx_user_business_active (business_id, is_active),
    INDEX idx_user_branch (branch_id, is_active),
    INDEX idx_user_role (role_id, is_active),
    INDEX idx_user_owner (is_owner, business_id),
    INDEX idx_user_email_active (email, is_active),
    INDEX idx_user_last_login (last_login_at DESC),
        
    INDEX idx_user_auth_cover (email, is_active, hash_password, master_user_id, role_id),
    
    CONSTRAINT fk_user_business FOREIGN KEY (business_id)
        REFERENCES master_business(business_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    CONSTRAINT fk_user_branch FOREIGN KEY (branch_id)
        REFERENCES master_branch(branch_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    
    CONSTRAINT fk_user_role FOREIGN KEY (role_id)
        REFERENCES master_role_type(master_role_type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='User accounts with enhanced security tracking';

DROP TABLE IF EXISTS master_user_session;
CREATE TABLE master_user_session (
    id CHAR(36) PRIMARY KEY COMMENT 'UUID',
    user_id INT UNSIGNED NOT NULL,
    session_token_hash CHAR(64) NOT NULL COMMENT 'SHA256 hash of token',
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    device_type ENUM('WEB','MOBILE_IOS','MOBILE_ANDROID','TABLET','DESKTOP','OTHER') DEFAULT 'WEB',
    ip_address VARCHAR(45) COMMENT 'IPv4 or IPv6',
        
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expiry_at TIMESTAMP(6) NOT NULL,
    last_active TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
        
    INDEX idx_session_user_active (user_id, is_active, last_active DESC),
    INDEX idx_session_expiry (expiry_at, is_active),
    INDEX idx_session_token (session_token_hash),
    INDEX idx_session_cleanup (is_active, expiry_at),
        
    INDEX idx_session_validate_cover (session_token_hash, is_active, expiry_at, user_id),
    
    CONSTRAINT fk_session_user FOREIGN KEY (user_id)
        REFERENCES master_user(master_user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
        
    CONSTRAINT chk_session_expiry CHECK (expiry_at > created_at)
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='User sessions with token hashing for security';

DROP TABLE IF EXISTS master_otp;
CREATE TABLE master_otp (
    id CHAR(36) PRIMARY KEY COMMENT 'UUID',
    target_identifier VARCHAR(255) NOT NULL COMMENT 'Email or phone',
    user_id INT UNSIGNED NULL,
    otp_code_hash CHAR(64) NOT NULL COMMENT 'SHA256 hash',
    otp_type_id TINYINT UNSIGNED NOT NULL,
    otp_status_id TINYINT UNSIGNED NOT NULL DEFAULT 1,
    attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
    max_attempts TINYINT UNSIGNED NOT NULL DEFAULT 3,
    ip_address VARCHAR(45),
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expires_at TIMESTAMP(6) NOT NULL,
    verified_at TIMESTAMP(6) NULL,
    updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
    
    created_by VARCHAR(100) NOT NULL,
    updated_by VARCHAR(100),
      
    INDEX idx_otp_target_status (target_identifier, otp_status_id, expires_at DESC),
    INDEX idx_otp_user_type (user_id, otp_type_id, otp_status_id),
    INDEX idx_otp_cleanup (expires_at, otp_status_id),
    INDEX idx_otp_hash (otp_code_hash),
        
    INDEX idx_otp_validate_cover (otp_code_hash, otp_status_id, expires_at, attempts, max_attempts),
    
    CONSTRAINT fk_otp_user FOREIGN KEY (user_id)
        REFERENCES master_user(master_user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    
    CONSTRAINT fk_otp_type FOREIGN KEY (otp_type_id)
        REFERENCES master_otp_type(master_otp_type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    
    CONSTRAINT fk_otp_status FOREIGN KEY (otp_status_id)
        REFERENCES master_otp_status(master_otp_status_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
        
    CONSTRAINT chk_otp_attempts CHECK (attempts <= max_attempts),
    CONSTRAINT chk_otp_expiry CHECK (expires_at > created_at)
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='OTP records with enhanced security';

-- ============================
-- CORE: categories, models, asset units
-- ============================

-- product_segment (electronics, furniture, appliances)
DROP TABLE IF EXISTS product_segment;
CREATE TABLE product_segment (
  product_segment_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  code VARCHAR(50) NOT NULL,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  display_order SMALLINT UNSIGNED DEFAULT 0,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  UNIQUE KEY uq_segment_business_branch_code (business_id, branch_id, code),
  INDEX idx_segment_business_active (business_id, is_active, display_order),
  INDEX idx_segment_branch (branch_id, is_active),
  
  INDEX idx_segment_list_cover (business_id, branch_id, is_active, name, product_segment_id),
  
  CONSTRAINT fk_segment_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_segment_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Top-level product segmentation (e.g., Electronics, Furniture)';
  
-- product_category (CAMERA, LAPTOP, MIC)
DROP TABLE IF EXISTS product_category;
CREATE TABLE product_category (
  product_category_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_segment_id INT UNSIGNED NOT NULL,
  code VARCHAR(50) NOT NULL,
  name VARCHAR(200) NOT NULL,
  description TEXT,
  display_order SMALLINT UNSIGNED DEFAULT 0,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  UNIQUE KEY uq_category_business_branch_segment_code (business_id, branch_id, product_segment_id, code),
  INDEX idx_category_segment_active (product_segment_id, is_active, display_order),
  INDEX idx_category_business_active (business_id, is_active),
  INDEX idx_category_branch (branch_id, is_active),
  
  INDEX idx_category_list_cover (product_segment_id, is_active, name, product_category_id),
  
  CONSTRAINT fk_category_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_category_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_category_segment FOREIGN KEY (product_segment_id)
    REFERENCES product_segment(product_segment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Product categories within segments';

-- product_model (Canon EOS 5D Mark IV, iPhone 13 Pro)
DROP TABLE IF EXISTS product_model;
CREATE TABLE product_model (
  product_model_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_segment_id INT UNSIGNED NOT NULL,
  product_category_id INT UNSIGNED NOT NULL,

  model_name VARCHAR(200) NOT NULL,
  description TEXT,
  sku VARCHAR(100) COMMENT 'Stock Keeping Unit',
  
  default_rent_price DECIMAL(12,2) UNSIGNED,
  default_deposit DECIMAL(12,2) UNSIGNED NOT NULL,
  default_sell_price DECIMAL(12,2) UNSIGNED,
  default_warranty_days SMALLINT UNSIGNED,
  
  supports_rent BOOLEAN NOT NULL DEFAULT TRUE,
  supports_sell BOOLEAN NOT NULL DEFAULT FALSE,
  
  primary_image_url VARCHAR(1024),
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  UNIQUE KEY uq_model_business_branch_seg_cat_name (business_id, branch_id, product_segment_id, product_category_id, model_name),
  INDEX idx_model_category_active (product_category_id, is_active),
  INDEX idx_model_segment_active (product_segment_id, is_active),
  INDEX idx_model_business_active (business_id, is_active),
  INDEX idx_model_branch_active (branch_id, is_active),
  INDEX idx_model_sku (sku),
  INDEX idx_model_rent_support (supports_rent, is_active),
  INDEX idx_model_sell_support (supports_sell, is_active),
  INDEX idx_model_name_search (model_name, is_active),
  
  INDEX idx_model_list_cover (business_id, branch_id, is_active, model_name, default_rent_price, product_model_id),
  
  INDEX idx_model_availability (product_category_id, is_active, supports_rent, product_model_id),
  
  CONSTRAINT fk_model_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_model_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_model_segment FOREIGN KEY (product_segment_id)
    REFERENCES product_segment(product_segment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_model_category FOREIGN KEY (product_category_id)
    REFERENCES product_category(product_category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT chk_model_pricing CHECK (
      default_rent_price >= 0 AND
      default_deposit >= 0 AND
      (default_sell_price IS NULL OR default_sell_price >= 0) AND
      ((default_rent_price IS NOT NULL AND default_sell_price IS NULL) OR
       (default_rent_price IS NULL AND default_sell_price IS NOT NULL) OR
       (default_rent_price IS NOT NULL AND default_sell_price IS NOT NULL))
    )
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Product models with optimized indexing for catalog queries';


-- asset (physical serialized item)
-- Ex: Canon EOS 5D Mark IV with serial no XYZ12345
DROP TABLE IF EXISTS asset;
CREATE TABLE asset (
  asset_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  
  serial_number VARCHAR(100) NOT NULL,
  asset_tag VARCHAR(100) COMMENT 'Internal tracking tag/barcode',
  
  product_status_id TINYINT UNSIGNED NOT NULL,
  product_condition_id TINYINT UNSIGNED NOT NULL,
  
  rent_price DECIMAL(12,2) UNSIGNED,
  sell_price DECIMAL(12,2) UNSIGNED,
  
  source_type_id TINYINT UNSIGNED NOT NULL,
  borrowed_from_business_name VARCHAR(200),
  borrowed_from_branch_name VARCHAR(200),
  
  purchase_date DATE,
  purchase_price DECIMAL(12,2) UNSIGNED,
  current_value DECIMAL(12,2) UNSIGNED COMMENT 'Depreciated value',
  
  is_available BOOLEAN GENERATED ALWAYS AS (
    CASE WHEN product_status_id = 2 THEN TRUE ELSE FALSE END
  ) STORED COMMENT 'TRUE when status is AVAILABLE',

  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  UNIQUE KEY uq_asset_business_branch_model_serial (business_id, branch_id, product_model_id, serial_number),
  INDEX idx_asset_model_status (product_model_id, product_status_id, is_active),
  INDEX idx_asset_branch_status (branch_id, product_status_id, is_active),
  INDEX idx_asset_business_active (business_id, is_active),
  INDEX idx_asset_serial (serial_number),
  INDEX idx_asset_tag (asset_tag),
  INDEX idx_asset_source (source_type_id, business_id),
  INDEX idx_asset_condition (product_condition_id, is_active),
  INDEX idx_asset_available (is_available, product_model_id, branch_id, asset_id), -- Critical index for availability queries
  INDEX idx_asset_list_cover (business_id, branch_id, is_active, product_model_id, product_status_id, asset_id), -- Covering index for asset listing
  INDEX idx_asset_rental_ready (product_model_id, branch_id, product_status_id, is_active, asset_id), -- Index for rental assignment queries
  
  CONSTRAINT fk_asset_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_asset_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_asset_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_asset_status FOREIGN KEY (product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_asset_condition FOREIGN KEY (product_condition_id)
    REFERENCES product_condition(product_condition_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_asset_source FOREIGN KEY (source_type_id)
    REFERENCES source_type(source_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT chk_asset_prices CHECK (
    (rent_price IS NULL OR rent_price >= 0) AND
    (sell_price IS NULL OR sell_price >= 0) AND
    (purchase_price IS NULL OR purchase_price >= 0) AND
    (current_value IS NULL OR current_value >= 0)
  ),
  
  CONSTRAINT chk_asset_borrowed CHECK (
    (source_type_id = 2 AND borrowed_from_business_name IS NOT NULL) OR
    (source_type_id != 2)
  )
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Individual asset instances with advanced indexing';

DROP TABLE IF EXISTS customer;
CREATE TABLE customer (
  customer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100),
  full_name VARCHAR(200) GENERATED ALWAYS AS (
    CONCAT(first_name, COALESCE(CONCAT(' ', last_name), ''))
  ) STORED,
  email VARCHAR(255) NULL,
  contact_number VARCHAR(20) NOT NULL,
  
  address_line VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(100),
  country CHAR(2),
  pincode VARCHAR(20),
  
  total_rentals INT UNSIGNED NOT NULL DEFAULT 0,
  total_sales INT UNSIGNED NOT NULL DEFAULT 0,
  total_spent DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  last_rental_date DATE,
  last_sale_date DATE,
  
  customer_tier ENUM('BRONZE','SILVER','GOLD','PLATINUM') DEFAULT 'BRONZE',
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  UNIQUE KEY uq_customer_email_business_branch (email, business_id, branch_id),
  INDEX idx_customer_business_contact (business_id, contact_number),
  INDEX idx_customer_branch_active (branch_id, is_active),
  INDEX idx_customer_email (email, is_active),
  INDEX idx_customer_contact (contact_number, business_id),
  INDEX idx_customer_name_search (full_name, is_active),
  INDEX idx_customer_tier (customer_tier, business_id),
  INDEX idx_customer_last_activity (last_rental_date DESC, last_sale_date DESC), 
  INDEX idx_customer_list_cover (business_id, branch_id, is_active, full_name, email, customer_id), -- Covering index for customer listing
  INDEX idx_customer_metrics (business_id, total_spent DESC, total_rentals DESC), -- Index for customer segmentation queries
  
  CONSTRAINT fk_customer_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_customer_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT chk_customer_metrics CHECK (
    total_rentals >= 0 AND
    total_sales >= 0 AND
    total_spent >= 0
  )
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Customer records with built-in segmentation metrics';

-- Stores each specific item that was rented as part of that rental_order.
DROP TABLE IF EXISTS rental_order;
CREATE TABLE rental_order (
  rental_order_id INT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL COMMENT 'Staff who created order',
  
  order_no VARCHAR(100) NOT NULL,
  reference_no VARCHAR(100) COMMENT 'External reference',
  
  start_date TIMESTAMP(6) NOT NULL,
  due_date TIMESTAMP(6) NOT NULL,
  end_date TIMESTAMP(6) NULL COMMENT 'Actual return date',
  
  total_items SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  
  security_deposit DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0,
  deposit_due_on TIMESTAMP(6) NULL,
  subtotal_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  tax_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  discount_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  total_amount DECIMAL(14,2) UNSIGNED NOT NULL,
  paid_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  balance_due DECIMAL(14,2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
  
  rental_billing_period_id TINYINT UNSIGNED NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'INR',
  
  rental_order_status_id TINYINT UNSIGNED NOT NULL,
  is_overdue BOOLEAN GENERATED ALWAYS AS (
    CASE WHEN end_date IS NULL AND due_date < CURRENT_TIMESTAMP(6) THEN TRUE ELSE FALSE END
  ) STORED,
  
  notes TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  PRIMARY KEY (rental_order_id, start_date),
  
  UNIQUE KEY uq_rental_business_branch_order (business_id, branch_id, order_no),
  INDEX idx_rental_customer_dates (customer_id, start_date DESC, due_date),
  INDEX idx_rental_branch_status (branch_id, rental_order_status_id, is_active),
  INDEX idx_rental_user (user_id, created_at DESC),
  INDEX idx_rental_dates_status (start_date, due_date, rental_order_status_id),
  INDEX idx_rental_overdue (is_overdue, business_id, branch_id),
  INDEX idx_rental_balance (balance_due, business_id, branch_id),

  INDEX idx_rental_list_cover (business_id, branch_id, is_active, start_date DESC, order_no, rental_order_id), -- Covering index for order listing
  
  INDEX idx_rental_financial (business_id, start_date, total_amount DESC, paid_amount), -- Index for financial reconciliation
  
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
  
  CONSTRAINT fk_rental_billing_period FOREIGN KEY (rental_billing_period_id)
    REFERENCES rental_billing_period(rental_billing_period_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_rental_status FOREIGN KEY (rental_order_status_id)
    REFERENCES rental_order_status(rental_order_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT chk_rental_amounts CHECK (
    subtotal_amount >= 0 AND
    tax_amount >= 0 AND
    discount_amount >= 0 AND
    total_amount >= 0 AND
    paid_amount >= 0 AND
    security_deposit >= 0 AND
    paid_amount <= total_amount
  ),
  
  CONSTRAINT chk_rental_dates CHECK (
    start_date <= due_date AND
    (end_date IS NULL OR end_date >= start_date)
  )
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Rental orders with time-based partitioning for scalability'
  PARTITION BY RANGE (YEAR(start_date)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION p_future VALUES LESS THAN MAXVALUE
  );

-- DROP TABLE IF EXISTS rental_item;
DROP TABLE IF EXISTS rental_order_item;
CREATE TABLE rental_order_item (
  rental_order_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  rental_order_id INT UNSIGNED NOT NULL,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,

  product_segment_id INT UNSIGNED NOT NULL,
  product_category_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  rent_price DECIMAL(12,2) UNSIGNED NOT NULL,-- Item snapshot at time of rental
  product_condition_at_rental TINYINT UNSIGNED COMMENT 'Condition when item was rented',
  notes TEXT,-- Audit
  created_by VARCHAR(100),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),-- Optimized indexes


  INDEX idx_rental_item_order (rental_order_id, rental_order_item_id),
  INDEX idx_rental_item_asset (asset_id, rental_order_id),
  INDEX idx_rental_item_model (product_model_id, business_id),
  INDEX idx_rental_item_customer (customer_id, created_at DESC),
  INDEX idx_rental_item_business (business_id, branch_id, created_at DESC),-- Covering index for order details
  INDEX idx_rental_item_cover (rental_order_id, asset_id, rent_price, rental_order_item_id),
  
  CONSTRAINT fk_rental_item_order FOREIGN KEY (rental_order_id)
  REFERENCES rental_order(rental_order_id)
  ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT fk_rental_item_business FOREIGN KEY (business_id)
  REFERENCES master_business(business_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,CONSTRAINT fk_rental_item_branch FOREIGN KEY (branch_id)
  REFERENCES master_branch(branch_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,CONSTRAINT fk_rental_item_segment FOREIGN KEY (product_segment_id)
  REFERENCES product_segment(product_segment_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,CONSTRAINT fk_rental_item_category FOREIGN KEY (product_category_id)
  REFERENCES product_category(product_category_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,CONSTRAINT fk_rental_item_model FOREIGN KEY (product_model_id)
  REFERENCES product_model(product_model_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,CONSTRAINT fk_rental_item_asset FOREIGN KEY (asset_id)
  REFERENCES asset(asset_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,CONSTRAINT fk_rental_item_customer FOREIGN KEY (customer_id)
  REFERENCES customer(customer_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,CONSTRAINT chk_rental_item_price CHECK (rent_price >= 0)
  ) ENGINE=InnoDB
  ROW_FORMAT=DYNAMIC
  COMMENT='Individual items in rental orders';

-- 2.1 sales_order: order-level (can be POS / e-commerce)
DROP TABLE IF EXISTS sales_order;
CREATE TABLE sales_order (
  sales_order_id INT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NULL,
  order_no VARCHAR(100) NOT NULL,
  reference_no VARCHAR(100),
  order_date TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  shipping_date TIMESTAMP(6) NULL,
  invoice_expected_date DATE NULL,
  subtotal_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  tax_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  discount_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  shipping_cost DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  total_amount DECIMAL(14,2) UNSIGNED NOT NULL,
  paid_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  balance_due DECIMAL(14,2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
  currency CHAR(3) NOT NULL DEFAULT 'INR',
  sales_order_status_id TINYINT UNSIGNED NOT NULL,
  notes TEXT,
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  PRIMARY KEY (sales_order_id, order_date),
  UNIQUE KEY uq_sales_business_branch_order (business_id, branch_id, order_no),
  INDEX idx_sales_customer_date (customer_id, order_date DESC),
  INDEX idx_sales_branch_status (branch_id, sales_order_status_id, is_active),
  INDEX idx_sales_user (user_id, created_at DESC),
  INDEX idx_sales_date_status (order_date DESC, sales_order_status_id),
  INDEX idx_sales_balance (balance_due, business_id, branch_id),
  INDEX idx_sales_list_cover (business_id, branch_id, is_active, order_date DESC, order_no, sales_order_id),
  INDEX idx_sales_financial (business_id, order_date, total_amount DESC, paid_amount),

  CONSTRAINT fk_sales_business FOREIGN KEY (business_id)
  REFERENCES master_business(business_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sales_branch FOREIGN KEY (branch_id)
  REFERENCES master_branch(branch_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sales_customer FOREIGN KEY (customer_id)
  REFERENCES customer(customer_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sales_user FOREIGN KEY (user_id)
  REFERENCES master_user(master_user_id)
  ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_sales_status FOREIGN KEY (sales_order_status_id)
  REFERENCES sales_order_status(sales_order_status_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_sales_amounts CHECK (
  subtotal_amount >= 0 AND
  tax_amount >= 0 AND
  discount_amount >= 0 AND
  shipping_cost >= 0 AND
  total_amount >= 0 AND
  paid_amount >= 0 AND
  paid_amount <= total_amount
  ),
  CONSTRAINT chk_sales_dates CHECK (
  (shipping_date IS NULL OR shipping_date >= order_date) AND
  (invoice_expected_date IS NULL OR invoice_expected_date >= DATE(order_date))
  )
  ) ENGINE=InnoDB
  ROW_FORMAT=DYNAMIC
  COMMENT='Sales orders with time-based partitioning'
  PARTITION BY RANGE (YEAR(order_date)) (
  PARTITION p2023 VALUES LESS THAN (2024),
  PARTITION p2024 VALUES LESS THAN (2025),
  PARTITION p2025 VALUES LESS THAN (2026),
  PARTITION p2026 VALUES LESS THAN (2027),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- 2.2 sales_order_item: lines (can reference product_model or specific asset)
DROP TABLE IF EXISTS sales_order_item;
CREATE TABLE sales_order_item (
  sales_order_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  sales_order_id INT UNSIGNED NOT NULL,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,

  product_segment_id INT UNSIGNED NOT NULL,
  product_category_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  sell_price DECIMAL(12,2) UNSIGNED NOT NULL,
  notes TEXT,
  created_by VARCHAR(100),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),

  INDEX idx_sales_item_order (sales_order_id, sales_order_item_id),
  INDEX idx_sales_item_asset (asset_id, sales_order_id),
  INDEX idx_sales_item_model (product_model_id, business_id),
  INDEX idx_sales_item_customer (customer_id, created_at DESC),
  INDEX idx_sales_item_cover (sales_order_id, asset_id, sell_price, sales_order_item_id),

  CONSTRAINT fk_sales_item_order FOREIGN KEY (sales_order_id)
  REFERENCES sales_order(sales_order_id)
  ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_sales_item_business FOREIGN KEY (business_id)
  REFERENCES master_business(business_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sales_item_branch FOREIGN KEY (branch_id)
  REFERENCES master_branch(branch_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sales_item_segment FOREIGN KEY (product_segment_id)
  REFERENCES product_segment(product_segment_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sales_item_category FOREIGN KEY (product_category_id)
  REFERENCES product_category(product_category_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sales_item_model FOREIGN KEY (product_model_id)
  REFERENCES product_model(product_model_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sales_item_asset FOREIGN KEY (asset_id)
  REFERENCES asset(asset_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_sales_item_customer FOREIGN KEY (customer_id)
  REFERENCES customer(customer_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_sales_item_price CHECK (sell_price >= 0)
) ENGINE=InnoDB
ROW_FORMAT=DYNAMIC
COMMENT='Individual items in sales orders';

DROP TABLE IF EXISTS invoices;
CREATE TABLE invoices (
  invoice_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NULL,
  rental_order_id INT UNSIGNED NULL,
  sales_order_id INT UNSIGNED NULL,
  invoice_no VARCHAR(100) NOT NULL,
  invoice_date TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  invoice_type ENUM('FINAL','PROFORMA','CREDIT_NOTE','DEBIT_NOTE') NOT NULL DEFAULT 'FINAL',
  
  storage_provider VARCHAR(100) NOT NULL, -- e.g., aws_s3, google_cloud_
  storage_bucket VARCHAR(255) NOT NULL, -- bucket name
  storage_object_key VARCHAR(255) NOT NULL, -- cloude id and url to stored
  storage_url VARCHAR(2048) NOT NULL,
  invoice_file_name VARCHAR(512),

  notes TEXT,
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_invoice_business_branch_no (business_id, branch_id, invoice_no),

  INDEX idx_invoice_customer (customer_id, invoice_date DESC),
  INDEX idx_invoice_rental (rental_order_id),
  INDEX idx_invoice_sales (sales_order_id),
  INDEX idx_invoice_date_type (invoice_date DESC, invoice_type),
  INDEX idx_invoice_business_date (business_id, branch_id, invoice_date DESC),
  INDEX idx_invoice_list_cover (business_id, branch_id, invoice_date DESC, invoice_no, invoice_id),

  CONSTRAINT fk_invoice_business FOREIGN KEY (business_id)
  REFERENCES master_business(business_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_invoice_branch FOREIGN KEY (branch_id)
  REFERENCES master_branch(branch_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_invoice_customer FOREIGN KEY (customer_id)
  REFERENCES customer(customer_id)
  ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_invoice_rental FOREIGN KEY (rental_order_id)
  REFERENCES rental_order(rental_order_id)
  ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_invoice_sales FOREIGN KEY (sales_order_id)
  REFERENCES sales_order(sales_order_id)
  ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT chk_invoice_order_link CHECK (
  (rental_order_id IS NOT NULL AND sales_order_id IS NULL) OR
  (rental_order_id IS NULL AND sales_order_id IS NOT NULL)
  )
) ENGINE=InnoDB
ROW_FORMAT=DYNAMIC
COMMENT='Invoice records with document storage references';

-- Central payments ledger
DROP TABLE IF EXISTS payments;
CREATE TABLE payments (
  payment_id BIGINT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  payment_reference VARCHAR(255) COMMENT 'Gateway/transaction ID',
  paid_on TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  amount DECIMAL(14,2) UNSIGNED NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'INR',
  mode_of_payment_id TINYINT UNSIGNED NULL,
  payer_customer_id INT UNSIGNED NULL,
  received_by_user_id INT UNSIGNED NULL,
  direction ENUM('IN','OUT') NOT NULL DEFAULT 'IN',
  status ENUM('PENDING','COMPLETED','FAILED','REFUNDED') NOT NULL DEFAULT 'COMPLETED',
  external_response JSON COMMENT 'Raw gateway response',
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),

  PRIMARY KEY (payment_id, paid_on),

  INDEX idx_payment_reference (payment_reference),
  INDEX idx_payment_business_date (business_id, branch_id, paid_on DESC),
  INDEX idx_payment_customer (payer_customer_id, paid_on DESC),
  INDEX idx_payment_user (received_by_user_id, paid_on DESC),
  INDEX idx_payment_status_date (status, paid_on DESC),
  INDEX idx_payment_direction (direction, status, paid_on DESC),
  INDEX idx_payment_recon_cover (business_id, paid_on DESC, amount, status, payment_id),

  CONSTRAINT fk_payment_business FOREIGN KEY (business_id)
  REFERENCES master_business(business_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_payment_branch FOREIGN KEY (branch_id)
  REFERENCES master_branch(branch_id)
  ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_payment_mode FOREIGN KEY (mode_of_payment_id)
  REFERENCES payment_mode(payment_mode_id)
  ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_payment_customer FOREIGN KEY (payer_customer_id)
  REFERENCES customer(customer_id)
  ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_payment_user FOREIGN KEY (received_by_user_id)
  REFERENCES master_user(master_user_id)
  ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_payment_amount CHECK (amount > 0)
) ENGINE=InnoDB
ROW_FORMAT=DYNAMIC
COMMENT='Payment records with time-based partitioning'
PARTITION BY RANGE (YEAR(paid_on)) (
PARTITION p2023 VALUES LESS THAN (2024),
PARTITION p2024 VALUES LESS THAN (2025),
PARTITION p2025 VALUES LESS THAN (2026),
PARTITION p2026 VALUES LESS THAN (2027),
PARTITION p_future VALUES LESS THAN MAXVALUE
);

DROP TABLE IF EXISTS payment_allocation;
CREATE TABLE payment_allocation (
  payment_allocation_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  payment_id BIGINT UNSIGNED NOT NULL,
  rental_order_id INT UNSIGNED NULL,
  sales_order_id INT UNSIGNED NULL,
  allocated_amount DECIMAL(14,2) UNSIGNED NOT NULL,
  allocated_on TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  notes TEXT,

  INDEX idx_alloc_payment (payment_id),
  INDEX idx_alloc_rental (rental_order_id),
  INDEX idx_alloc_sales (sales_order_id),
  INDEX idx_alloc_date (allocated_on DESC),
  INDEX idx_alloc_cover (payment_id, allocated_amount, rental_order_id, sales_order_id),

  CONSTRAINT fk_alloc_payment FOREIGN KEY (payment_id)
    REFERENCES payments(payment_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_alloc_rental FOREIGN KEY (rental_order_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_alloc_sales FOREIGN KEY (sales_order_id)
    REFERENCES sales_order(sales_order_id)
    ON DELETE CASCADE ON UPDATE CASCADE,

  CONSTRAINT chk_alloc_order_link CHECK (
  (rental_order_id IS NOT NULL AND sales_order_id IS NULL) OR
  (rental_order_id IS NULL AND sales_order_id IS NOT NULL)
  ),
  CONSTRAINT chk_alloc_amount CHECK (allocated_amount > 0)
) ENGINE=InnoDB
ROW_FORMAT=DYNAMIC
COMMENT='Payment allocation to orders';


-- -- =========================================================
-- -- MAINTENANCE & TRACKING TABLES (UTC timestamps)
-- -- =========================================================

DROP TABLE IF EXISTS maintenance_records;
CREATE TABLE maintenance_records (
  maintenance_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  maintenance_status_id TINYINT UNSIGNED NOT NULL,
  
  reported_by VARCHAR(100),
  reported_on TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  assigned_to VARCHAR(100),
  scheduled_date TIMESTAMP(6) NULL,
  completed_on TIMESTAMP(6) NULL,
  
  estimated_cost DECIMAL(12,2) UNSIGNED,
  actual_cost DECIMAL(12,2) UNSIGNED,
  
  issue_description TEXT NOT NULL,
  resolution_notes TEXT,
  vendor_name VARCHAR(200),
  vendor_invoice_no VARCHAR(100),
  
  remarks TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  INDEX idx_maint_asset_date (asset_id, reported_on DESC),
  INDEX idx_maint_status_date (maintenance_status_id, scheduled_date),
  INDEX idx_maint_branch_status (branch_id, maintenance_status_id, is_active),
  INDEX idx_maint_business_date (business_id, reported_on DESC),
  INDEX idx_maint_scheduled (scheduled_date, maintenance_status_id),
  INDEX idx_maint_assigned (assigned_to, maintenance_status_id),
  
  INDEX idx_maint_list_cover ( -- Covering index for maintenance listing
    business_id, branch_id, maintenance_status_id, reported_on DESC, 
    asset_id, maintenance_id
  ),
  
  CONSTRAINT fk_maint_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_maint_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_maint_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_maint_status FOREIGN KEY (maintenance_status_id)
    REFERENCES maintenance_status(maintenance_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT chk_maint_dates CHECK (
    (scheduled_date IS NULL OR scheduled_date >= reported_on) AND
    (completed_on IS NULL OR completed_on >= reported_on)
  ),
  
  CONSTRAINT chk_maint_costs CHECK (
    (estimated_cost IS NULL OR estimated_cost >= 0) AND
    (actual_cost IS NULL OR actual_cost >= 0)
  )
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Maintenance records for assets';

DROP TABLE IF EXISTS damage_reports;
CREATE TABLE damage_reports (
  damage_report_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  
  reported_by INT UNSIGNED NULL,
  reported_on TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  description TEXT NOT NULL,
  severity ENUM('MINOR','MODERATE','SEVERE','TOTAL_LOSS') NOT NULL,
  damage_images JSON COMMENT 'Array of image URLs',
  
  estimated_cost DECIMAL(12,2) UNSIGNED,
  actual_repair_cost DECIMAL(12,2) UNSIGNED,
  insurance_claim_no VARCHAR(100),
  insurance_payout DECIMAL(12,2) UNSIGNED,
  
  resolved BOOLEAN NOT NULL DEFAULT FALSE,
  resolved_on TIMESTAMP(6) NULL,
  resolution_notes TEXT,
  
  customer_liable BOOLEAN DEFAULT FALSE,
  customer_id INT UNSIGNED NULL,
  liability_amount DECIMAL(12,2) UNSIGNED,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  INDEX idx_damage_asset_date (asset_id, reported_on DESC),
  INDEX idx_damage_branch_severity (branch_id, severity, resolved),
  INDEX idx_damage_reported_by (reported_by, reported_on DESC),
  INDEX idx_damage_unresolved (resolved, business_id, branch_id),
  INDEX idx_damage_customer (customer_id, resolved),
  
  
  INDEX idx_damage_list_cover ( -- Covering index for damage reports
    business_id, branch_id, resolved, reported_on DESC, 
    severity, asset_id, damage_report_id
  ),
  
  CONSTRAINT fk_damage_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_damage_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_damage_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT fk_damage_reporter FOREIGN KEY (reported_by)
    REFERENCES master_user(master_user_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
    
  CONSTRAINT fk_damage_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
    
  CONSTRAINT chk_damage_costs CHECK (
    (estimated_cost IS NULL OR estimated_cost >= 0) AND
    (actual_repair_cost IS NULL OR actual_repair_cost >= 0) AND
    (insurance_payout IS NULL OR insurance_payout >= 0) AND
    (liability_amount IS NULL OR liability_amount >= 0)
  )
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Damage tracking with insurance and liability management';
  
-- =========================================================
-- RESERVATIONS & DEPOSITS (UTC timestamps)
-- =========================================================

DROP TABLE IF EXISTS reservations;
CREATE TABLE reservations (
  reservation_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  reservation_status_id TINYINT UNSIGNED NOT NULL,
  
  reserved_from TIMESTAMP(6) NOT NULL,
  reserved_until TIMESTAMP(6) NOT NULL,
  
  quantity_requested SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  advance_payment DECIMAL(12,2) UNSIGNED DEFAULT 0,
  
  notes TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  INDEX idx_res_customer_date (customer_id, reserved_from DESC),
  INDEX idx_res_model_dates (product_model_id, reserved_from, reserved_until, reservation_status_id),
  INDEX idx_res_branch_status (branch_id, reservation_status_id, is_active),
  INDEX idx_res_dates (reserved_from, reserved_until, reservation_status_id),
  INDEX idx_res_status (reservation_status_id, reserved_from),
  
  INDEX idx_res_availability_cover ( -- Covering index for reservation checking
    product_model_id, branch_id, reservation_status_id, 
    reserved_from, reserved_until, quantity_requested
  ),
  
  CONSTRAINT fk_res_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_res_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_res_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_res_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_res_status FOREIGN KEY (reservation_status_id)
    REFERENCES reservation_status(reservation_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT chk_res_dates CHECK (reserved_until > reserved_from),
  CONSTRAINT chk_res_quantity CHECK (quantity_requested > 0),
  CONSTRAINT chk_res_payment CHECK (advance_payment >= 0)
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Product reservations with availability tracking';

DROP TABLE IF EXISTS reservation_item;
CREATE TABLE reservation_item (
  reservation_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reservation_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NULL COMMENT 'Specific asset assigned, NULL if not yet assigned',
  
  start_date TIMESTAMP(6) NOT NULL,
  end_date TIMESTAMP(6) NOT NULL,
  
  created_by VARCHAR(100),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  INDEX idx_res_item_reservation (reservation_id),
  INDEX idx_res_item_model_dates (product_model_id, start_date, end_date),
  INDEX idx_res_item_asset (asset_id, start_date, end_date),
  
  CONSTRAINT fk_res_item_reservation FOREIGN KEY (reservation_id)
    REFERENCES reservations(reservation_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  
  CONSTRAINT fk_res_item_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_res_item_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT chk_res_item_dates CHECK (end_date > start_date),
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Individual items in reservations';

-- -- =========================================================
-- -- images for products like
-- -- Ex: Canon EOS 5D Mark IV, iPhone 13 Pro
DROP TABLE IF EXISTS product_model_images;
CREATE TABLE product_model_images (
  product_model_image_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  
  url VARCHAR(1024) NOT NULL, -- canonical/original image (high-res) for zoom, downloads or print
  thumbnail_url VARCHAR(1024), -- pre-generated small/optimized version used in lists, cards and anywhere you want fast load and lower bandwidth.
  alt_text VARCHAR(512),
  file_size_bytes INT UNSIGNED,
  width_px SMALLINT UNSIGNED,
  height_px SMALLINT UNSIGNED,
  
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  image_order TINYINT UNSIGNED NOT NULL DEFAULT 0,
  image_category ENUM('MAIN','DETAIL','LIFESTYLE','DAMAGE','OTHER') DEFAULT 'MAIN',
  
  created_by VARCHAR(100),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  INDEX idx_img_model_order (product_model_id, is_active, image_order),
  INDEX idx_img_model_primary (product_model_id, is_primary, is_active),
  INDEX idx_img_business (business_id, branch_id),
  
  INDEX idx_img_cover ( -- Covering index for image retrieval
    product_model_id, is_active, is_primary, image_order, 
    url, thumbnail_url, product_model_image_id
  ),
  
  CONSTRAINT fk_img_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_img_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_img_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Product model images with ordering and categorization';

-- ========================================================
-- STOCK TABLE
DROP TABLE IF EXISTS stock;
CREATE TABLE stock (
  stock_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_segment_id INT UNSIGNED NOT NULL,
  product_category_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  quantity_available SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  quantity_reserved SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  quantity_on_rent SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  quantity_sold SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  quantity_in_maintenance SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  quantity_damaged SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  quantity_lost SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  quantity_total SMALLINT UNSIGNED GENERATED ALWAYS AS (
    quantity_available + 
    quantity_reserved + 
    quantity_on_rent +
    quantity_in_maintenance + 
    quantity_damaged + 
    quantity_lost
  ) STORED,
  is_rentable BOOLEAN GENERATED ALWAYS AS (
    quantity_available > 0
  ) STORED,
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  last_updated_by VARCHAR(100),
  last_updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),

  UNIQUE KEY uq_stock_business_branch_model (business_id, branch_id, product_model_id),

  INDEX idx_stock_branch_segment (branch_id, product_segment_id),
  INDEX idx_stock_branch_category (branch_id, product_category_id),
  INDEX idx_stock_available (is_rentable, business_id, branch_id),
  INDEX idx_stock_model_branch (product_model_id, branch_id),
  INDEX idx_stock_summary_cover ( business_id, branch_id, product_model_id, quantity_available, quantity_on_rent, quantity_total ),
  INDEX idx_stock_low_alert (business_id, quantity_available, product_model_id),

  CONSTRAINT fk_stock_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_segment FOREIGN KEY (product_segment_id)
    REFERENCES product_segment(product_segment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_category FOREIGN KEY (product_category_id)
    REFERENCES product_category(product_category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_stock_quantities CHECK (
    quantity_available >= 0 AND
    quantity_reserved >= 0 AND
    quantity_on_rent >= 0 AND
    quantity_sold >= 0 AND
    quantity_in_maintenance >= 0 AND
    quantity_damaged >= 0 AND
    quantity_lost >= 0
  )
) ENGINE=InnoDB
ROW_FORMAT=DYNAMIC
COMMENT='Aggregate stock levels per model per branch';

-- =========================================================
DROP TABLE IF EXISTS location_history;
CREATE TABLE location_history (
  location_history_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  
  source ENUM('GPS','MANUAL','GEOFENCE','RFID','NFC') NOT NULL,
  
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),
  accuracy_meters SMALLINT UNSIGNED COMMENT 'GPS accuracy',
  
  road VARCHAR(255),
  city VARCHAR(100),
  district VARCHAR(100),
  state VARCHAR(100),
  country CHAR(2),
  pincode VARCHAR(20),
  
  recorded_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  device_battery_percent TINYINT UNSIGNED,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  INDEX idx_loc_asset_time (asset_id, recorded_at DESC),
  INDEX idx_loc_business_time (business_id, recorded_at DESC),
  INDEX idx_loc_coordinates (latitude, longitude),
  INDEX idx_loc_city (city, recorded_at DESC),
  
  SPATIAL INDEX idx_loc_spatial (latitude, longitude) COMMENT 'Requires POINT type in MySQL 8.0+',
  
  CONSTRAINT fk_loc_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_loc_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_loc_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,

  CONSTRAINT chk_loc_coordinates CHECK (
    (latitude IS NULL AND longitude IS NULL) OR
    (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)
  ),
  CONSTRAINT chk_loc_battery CHECK (device_battery_percent IS NULL OR device_battery_percent <= 100)
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='GPS and location tracking history';


DROP TABLE IF EXISTS deposit;
CREATE TABLE deposit (
  deposit_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  
  rental_order_id INT UNSIGNED NULL,
  
  amount DECIMAL(12,2) UNSIGNED NOT NULL,
  held_since TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  released_on TIMESTAMP(6) NULL,
  released_amount DECIMAL(12,2) UNSIGNED,
  deduction_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  deduction_reason TEXT,
  
  is_released BOOLEAN NOT NULL DEFAULT FALSE,
  
  notes TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  INDEX idx_deposit_customer (customer_id, held_since DESC),
  INDEX idx_deposit_rental (rental_order_id),
  INDEX idx_deposit_unreleased (is_released, business_id, branch_id),
  INDEX idx_deposit_branch_date (branch_id, held_since DESC),  
  INDEX idx_deposit_cover ( business_id, branch_id, is_released, amount, held_since DESC, customer_id ), -- Covering index for deposit tracking
  
  CONSTRAINT fk_deposit_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_deposit_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_deposit_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_deposit_rental FOREIGN KEY (rental_order_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
    
  CONSTRAINT chk_deposit_amounts CHECK (
    amount >= 0 AND
    (released_amount IS NULL OR released_amount >= 0) AND
    (deduction_amount IS NULL OR deduction_amount >= 0) AND
    (released_amount IS NULL OR (released_amount + deduction_amount) = amount)
  )
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Security deposit tracking with release management';

-- =========================================================
-- LOGGING TABLES (UTC timestamps)
-- =========================================================  


DROP TABLE IF EXISTS notification_log;
CREATE TABLE notification_log (
  notification_id BIGINT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  rental_order_id INT UNSIGNED NULL,
  -- Contact details
  contact_type_id TINYINT UNSIGNED NOT NULL,
  contact_value VARCHAR(255) NOT NULL,
  channel_id TINYINT UNSIGNED NOT NULL,
  -- Message content
  template_code VARCHAR(100) COMMENT 'Template identifier',
  subject VARCHAR(512),
  message TEXT,
  -- Status and delivery
  notification_status_id TINYINT UNSIGNED NOT NULL,
  provider_response TEXT,
  attempt_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
  max_attempts TINYINT UNSIGNED NOT NULL DEFAULT 3,
  -- Scheduling
  scheduled_for TIMESTAMP(6) NULL,
  sent_on TIMESTAMP(6) NULL,
  delivered_on TIMESTAMP(6) NULL,
  -- External tracking
  external_reference VARCHAR(255) COMMENT 'Provider message ID',
  reference_entity VARCHAR(50) COMMENT 'rental_order, asset, customer, etc',
  -- Audit
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  PRIMARY KEY (notification_id, created_at),

  INDEX idx_notif_customer (customer_id, created_at DESC),
  INDEX idx_notif_rental (rental_order_id, created_at DESC),
  INDEX idx_notif_status_scheduled (notification_status_id, scheduled_for),
  INDEX idx_notif_business_date (business_id, created_at DESC),
  INDEX idx_notif_pending (notification_status_id, attempt_count, scheduled_for),
  INDEX idx_notif_contact (contact_value, created_at DESC),
  INDEX idx_notif_process_cover (notification_status_id, scheduled_for, attempt_count, max_attempts, channel_id, notification_id), -- Covering index for notification processing
  
  CONSTRAINT fk_notif_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_notif_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_notif_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_notif_rental FOREIGN KEY (rental_order_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_notif_contact_type FOREIGN KEY (contact_type_id)
    REFERENCES contact_type(contact_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_notif_channel FOREIGN KEY (channel_id)
    REFERENCES notification_channel(notification_channel_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  
  CONSTRAINT fk_notif_status FOREIGN KEY (notification_status_id)
    REFERENCES notification_status(notification_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
    
  CONSTRAINT chk_notif_attempts CHECK (attempt_count <= max_attempts)
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Notification log with time-based partitioning'
  PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION p_future VALUES LESS THAN MAXVALUE
  );

-- ========================================================
-- ERROR LOGGING (Optimized)
-- ========================================================

DROP TABLE IF EXISTS proc_error_log;
CREATE TABLE proc_error_log (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    proc_name VARCHAR(128) NOT NULL,
    proc_args JSON,
    mysql_errno INT NULL,
    sql_state CHAR(5) NULL,
    error_message TEXT,
    stack_trace TEXT,
    server_time_utc TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    -- Optimized indexes
    INDEX idx_error_proc (proc_name, server_time_utc DESC),
    INDEX idx_error_time (server_time_utc DESC),
    INDEX idx_error_errno (mysql_errno, server_time_utc DESC)
) ENGINE=InnoDB 
  ROW_FORMAT=DYNAMIC
  COMMENT='Stored procedure and trigger error logging';

-- =========================================================
DROP TABLE IF EXISTS stock_movements;
CREATE TABLE stock_movements (
  stock_movement_id INT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  inventory_movement_type_id TINYINT UNSIGNED NOT NULL,
  quantity SMALLINT NOT NULL COMMENT 'Positive or negative',
  -- Branch transfer
  from_branch_id INT UNSIGNED NULL,
  to_branch_id INT UNSIGNED NULL,
  -- Status change
  from_product_status_id TINYINT UNSIGNED NULL,
  to_product_status_id TINYINT UNSIGNED NULL,
  -- Order linkage
  related_rental_id INT UNSIGNED NULL,
  related_reservation_id INT UNSIGNED NULL,
  related_maintenance_id INT UNSIGNED NULL,
  reference_no VARCHAR(100),
  note TEXT,
  metadata JSON COMMENT 'Additional structured data',
  -- Audit
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (stock_movement_id, created_at),
  -- Optimized indexes
  INDEX idx_stock_mov_model_date (product_model_id, created_at DESC),
  INDEX idx_stock_mov_branch_date (branch_id, created_at DESC),
  INDEX idx_stock_mov_type (inventory_movement_type_id, created_at DESC),
  INDEX idx_stock_mov_rental (related_rental_id),
  INDEX idx_stock_mov_history_cover ( business_id, branch_id, product_model_id, created_at DESC, quantity, inventory_movement_type_id), -- Covering index for movement history
  
  CONSTRAINT fk_stock_mov_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_type FOREIGN KEY (inventory_movement_type_id)
    REFERENCES inventory_movement_type(inventory_movement_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_from_branch FOREIGN KEY (from_branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_to_branch FOREIGN KEY (to_branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_from_status FOREIGN KEY (from_product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_to_status FOREIGN KEY (to_product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_rental FOREIGN KEY (related_rental_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_reservation FOREIGN KEY (related_reservation_id)
    REFERENCES reservations(reservation_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_stock_mov_maintenance FOREIGN KEY (related_maintenance_id)
    REFERENCES maintenance_records(maintenance_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB
ROW_FORMAT=DYNAMIC
COMMENT='Stock movement audit trail with time-based partitioning'
PARTITION BY RANGE (YEAR(created_at)) (
PARTITION p2023 VALUES LESS THAN (2024),
PARTITION p2024 VALUES LESS THAN (2025),
PARTITION p2025 VALUES LESS THAN (2026),
PARTITION p2026 VALUES LESS THAN (2027),
PARTITION p_future VALUES LESS THAN MAXVALUE
);

DROP TABLE IF EXISTS asset_movements;
CREATE TABLE asset_movements (
  asset_movement_id INT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NULL,
  asset_id INT UNSIGNED NOT NULL,
  inventory_movement_type_id TINYINT UNSIGNED NOT NULL,
  -- Branch transfer
  from_branch_id INT UNSIGNED NULL,
  to_branch_id INT UNSIGNED NULL,
  -- Status change
  from_product_status_id TINYINT UNSIGNED NULL,
  to_product_status_id TINYINT UNSIGNED NULL,
  -- Order linkage
  related_rental_id INT UNSIGNED NULL,
  related_reservation_id INT UNSIGNED NULL,
  related_maintenance_id INT UNSIGNED NULL,
  reference_no VARCHAR(100),
  note TEXT,
  metadata JSON,
  -- Audit
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  PRIMARY KEY (asset_movement_id, created_at),

  INDEX idx_asset_mov_asset_date (asset_id, created_at DESC),
  INDEX idx_asset_mov_model_date (product_model_id, created_at DESC),
  INDEX idx_asset_mov_type (inventory_movement_type_id, created_at DESC),
  INDEX idx_asset_mov_rental (related_rental_id),
  INDEX idx_asset_mov_history_cover ( asset_id, created_at DESC, inventory_movement_type_id, from_product_status_id, to_product_status_id), -- Covering index for asset history

  CONSTRAINT fk_asset_mov_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_type FOREIGN KEY (inventory_movement_type_id)
    REFERENCES inventory_movement_type(inventory_movement_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_from_branch FOREIGN KEY (from_branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_to_branch FOREIGN KEY (to_branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_from_status FOREIGN KEY (from_product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_to_status FOREIGN KEY (to_product_status_id)
    REFERENCES product_status(product_status_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_rental FOREIGN KEY (related_rental_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_reservation FOREIGN KEY (related_reservation_id)
    REFERENCES reservations(reservation_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_asset_mov_maintenance FOREIGN KEY (related_maintenance_id)
    REFERENCES maintenance_records(maintenance_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB
ROW_FORMAT=DYNAMIC
COMMENT='Individual asset movement tracking with time-based partitioning'
PARTITION BY RANGE (YEAR(created_at)) (
PARTITION p2023 VALUES LESS THAN (2024),
PARTITION p2024 VALUES LESS THAN (2025),
PARTITION p2025 VALUES LESS THAN (2026),
PARTITION p2026 VALUES LESS THAN (2027),
PARTITION p_future VALUES LESS THAN MAXVALUE
);