-- ========================================================
-- RENTAL MANAGEMENT SYSTEM - OPTIMIZED DATABASE SCHEMA
-- Version: 2.0
-- Last Updated: 2024
-- ========================================================
-- IMPROVEMENTS APPLIED:
-- 1. Multi-salesman cart system with single billing
-- 2. Comprehensive darji/tailor management
-- 3. Manufacturing and BOM tracking
-- 4. Incentive and commission system
-- 5. Complete supplier and purchase management
-- 6. Delivery and logistics tracking
-- 7. Order progress and readiness tracking
-- 8. Enhanced billing with GST, soft delete, approvals
-- 9. Audit logging and compliance
-- 10. Business configuration and settings
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
    country CHAR(2),
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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

-- =========================================================
-- ENHANCED USER MANAGEMENT
-- =========================================================

CREATE TABLE master_permission (
  permission_id SMALLINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(200) NOT NULL,
  module VARCHAR(100) NOT NULL COMMENT 'billing, asset, customer, etc',
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_perm_module (module, is_active)
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

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
    
    base_salary DECIMAL(12,2) UNSIGNED DEFAULT 0,
    employee_code VARCHAR(50),
    joining_date DATE,
      
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
    INDEX idx_user_employee_code (employee_code),
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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE role_permission (
  role_permission_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  role_id TINYINT UNSIGNED NOT NULL,
  permission_id SMALLINT UNSIGNED NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_role_permission (role_id, permission_id),
  INDEX idx_role_perms (role_id),
  
  CONSTRAINT fk_role_perm_role FOREIGN KEY (role_id)
    REFERENCES master_role_type(master_role_type_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_role_perm_permission FOREIGN KEY (permission_id)
    REFERENCES master_permission(permission_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE master_user_session (
    id CHAR(36) PRIMARY KEY,
    user_id INT UNSIGNED NOT NULL,
    session_token_hash CHAR(64) NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    device_type_id TINYINT UNSIGNED NOT NULL,
    ip_address VARCHAR(45),
        
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    expiry_at TIMESTAMP(6) NOT NULL,
    last_active TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
        
    INDEX idx_session_user_active (user_id, is_active, last_active DESC),
    INDEX idx_session_expiry (expiry_at, is_active),
    INDEX idx_session_token (session_token_hash),
    INDEX idx_session_cleanup (is_active, expiry_at),
    INDEX idx_user_device_type_id (device_type_id),
    INDEX idx_session_validate_cover (session_token_hash, is_active, expiry_at, user_id),
    
    CONSTRAINT fk_session_user FOREIGN KEY (user_id)
        REFERENCES master_user(master_user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_session_device_type FOREIGN KEY (device_type_id)
        REFERENCES master_device_type(master_device_type_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_session_expiry CHECK (expiry_at > created_at)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE master_otp (
    id CHAR(36) PRIMARY KEY,
    target_identifier VARCHAR(255) NOT NULL,
    user_id INT UNSIGNED NULL,
    otp_code_hash CHAR(64) NOT NULL,
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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

-- =========================================================
-- PRODUCT HIERARCHY
-- =========================================================

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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE product_model (
  product_model_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_segment_id INT UNSIGNED NOT NULL,
  product_category_id INT UNSIGNED NOT NULL,

  model_name VARCHAR(200) NOT NULL,
  description TEXT,
  sku VARCHAR(100),
  
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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE product_model_images (
  product_model_image_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  
  url VARCHAR(1024) NOT NULL,
  thumbnail_url VARCHAR(1024),
  alt_text VARCHAR(512),
  file_size_bytes INT UNSIGNED,
  width_px SMALLINT UNSIGNED,
  height_px SMALLINT UNSIGNED,
  
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  image_order TINYINT UNSIGNED NOT NULL DEFAULT 0,
  product_model_image_category_id TINYINT UNSIGNED NOT NULL,

  created_by VARCHAR(100),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  INDEX idx_img_model_order (product_model_id, is_active, image_order),
  INDEX idx_img_model_primary (product_model_id, is_primary, is_active),
  INDEX idx_img_business (business_id, branch_id),
  INDEX idx_img_image_category_id (product_model_image_category_id),
  INDEX idx_img_cover (product_model_id, is_active, is_primary, image_order, url, thumbnail_url, product_model_image_id),
  
  CONSTRAINT fk_img_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_img_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_img_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_img_category FOREIGN KEY (product_model_image_category_id)
    REFERENCES product_model_image_category(product_model_image_category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

-- =========================================================
-- ASSET MANAGEMENT (ENHANCED)
-- =========================================================

CREATE TABLE asset (
  asset_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  
  serial_number VARCHAR(100) NOT NULL,
  asset_tag VARCHAR(100),
  qr_code VARCHAR(100) UNIQUE,
  
  product_status_id TINYINT UNSIGNED NOT NULL,
  product_condition_id TINYINT UNSIGNED NOT NULL,
  
  rent_price DECIMAL(12,2) UNSIGNED,
  sell_price DECIMAL(12,2) UNSIGNED,
  
  source_type_id TINYINT UNSIGNED NOT NULL,
  borrowed_from_business_name VARCHAR(200),
  borrowed_from_branch_name VARCHAR(200),
  
  purchase_date DATE,
  purchase_price DECIMAL(12,2) UNSIGNED,
  current_value DECIMAL(12,2) UNSIGNED,
  
  upper_body_measurement VARCHAR(50),
  lower_body_measurement VARCHAR(50),
  size_range VARCHAR(50),
  color_name VARCHAR(100),
  fabric_type VARCHAR(100),
  movement_category VARCHAR(20) DEFAULT 'NORMAL',
  
  total_rent_count INT UNSIGNED DEFAULT 0,
  total_rent_revenue DECIMAL(14,2) UNSIGNED DEFAULT 0,
  last_rented_date DATE,
  last_cleaned_date DATE,
  next_available_date DATE,
  manufacturing_date DATE,
  manufacturing_cost DECIMAL(12,2) UNSIGNED,
  
  is_available BOOLEAN GENERATED ALWAYS AS (
    CASE WHEN product_status_id = 2 THEN TRUE ELSE FALSE END
  ) STORED,

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
  INDEX idx_asset_qr (qr_code),
  INDEX idx_asset_source (source_type_id, business_id),
  INDEX idx_asset_condition (product_condition_id, is_active),
  INDEX idx_asset_movement (movement_category, business_id),
  INDEX idx_asset_next_available (next_available_date, product_status_id),
  INDEX idx_asset_performance (total_rent_count DESC, total_rent_revenue DESC),
  INDEX idx_asset_available (is_available, product_model_id, branch_id, asset_id),
  INDEX idx_asset_list_cover (business_id, branch_id, is_active, product_model_id, product_status_id, asset_id),
  INDEX idx_asset_rental_ready (product_model_id, branch_id, product_status_id, is_active, asset_id),
  
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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE asset_measurement (
  measurement_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  asset_id INT UNSIGNED NOT NULL UNIQUE,
  chest_cm DECIMAL(6,2),
  waist_cm DECIMAL(6,2),
  hip_cm DECIMAL(6,2),
  shoulder_cm DECIMAL(6,2),
  sleeve_length_cm DECIMAL(6,2),
  length_cm DECIMAL(6,2),
  inseam_cm DECIMAL(6,2),
  neck_cm DECIMAL(6,2),
  custom_measurements JSON,
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  
  CONSTRAINT fk_measurement_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE asset_availability (
  availability_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  asset_id INT UNSIGNED NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  status VARCHAR(50) NOT NULL COMMENT 'BOOKED, BLOCKED, MAINTENANCE',
  rental_order_id INT UNSIGNED NULL,
  reservation_id INT UNSIGNED NULL,
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_avail_asset_dates (asset_id, start_date, end_date),
  INDEX idx_avail_dates (start_date, end_date, status),
  
    CONSTRAINT fk_avail_asset FOREIGN KEY (asset_id)
        REFERENCES asset(asset_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_avail_rental FOREIGN KEY (rental_order_id)
        REFERENCES rental_order(rental_order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_avail_reservation FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
        ON DELETE CASCADE ON UPDATE CASCADE;


  CONSTRAINT chk_avail_dates CHECK (end_date >= start_date)
) ENGINE=InnoDB;

-- =========================================================
-- CUSTOMER MANAGEMENT (ENHANCED)
-- =========================================================

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
  
  wedding_date DATE,
  event_type VARCHAR(100),
  alternate_contact VARCHAR(20),
  whatsapp_number VARCHAR(20),
  preferred_communication_channel TINYINT UNSIGNED,
  
  total_rentals INT UNSIGNED NOT NULL DEFAULT 0,
  total_sales INT UNSIGNED NOT NULL DEFAULT 0,
  total_spent DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  last_rental_date DATE,
  last_sale_date DATE,
  customer_tier_id TINYINT UNSIGNED NOT NULL,
  
  loyalty_points INT UNSIGNED DEFAULT 0,
  referral_source VARCHAR(200),
  notes TEXT,
  
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
  INDEX idx_customer_tier (customer_tier_id, business_id),
  INDEX idx_customer_customer_tier_id (customer_tier_id),
  INDEX idx_customer_wedding_date (wedding_date),
  INDEX idx_customer_whatsapp (whatsapp_number),
  INDEX idx_customer_last_activity (last_rental_date DESC, last_sale_date DESC), 
  INDEX idx_customer_list_cover (business_id, branch_id, is_active, full_name, email, customer_id),
  INDEX idx_customer_metrics (business_id, total_spent DESC, total_rentals DESC),
  
  CONSTRAINT fk_customer_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_customer_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_customer_tier FOREIGN KEY (customer_tier_id)
    REFERENCES master_customer_tier(master_customer_tier_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_customer_metrics CHECK (
    total_rentals >= 0 AND
    total_sales >= 0 AND
    total_spent >= 0
  )
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE customer_contact (
  customer_contact_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id INT UNSIGNED NOT NULL,
  business_id INT UNSIGNED NOT NULL,
  contact_type VARCHAR(50) NOT NULL COMMENT 'PICKUP, RETURN, EMERGENCY',
  contact_name VARCHAR(200) NOT NULL,
  contact_mobile VARCHAR(20) NOT NULL,
  relationship VARCHAR(100),
  is_default BOOLEAN DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_contact_customer (customer_id, contact_type),
  INDEX idx_contact_mobile (contact_mobile),
  
  CONSTRAINT fk_customer_contact_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_customer_contact_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE customer_communication_log (
  communication_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  customer_id INT UNSIGNED NOT NULL,
  business_id INT UNSIGNED NOT NULL,
  channel_id TINYINT UNSIGNED NOT NULL,
  message_type VARCHAR(100),
  message_content TEXT,
  sent_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  delivered_at TIMESTAMP(6) NULL,
  read_at TIMESTAMP(6) NULL,
  status VARCHAR(50),
  external_message_id VARCHAR(255),
  direction VARCHAR(10),
  created_by VARCHAR(100),
  
  INDEX idx_comm_customer_date (customer_id, sent_at DESC),
  INDEX idx_comm_channel (channel_id, sent_at DESC),
  
  CONSTRAINT fk_comm_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_comm_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_comm_channel FOREIGN KEY (channel_id)
    REFERENCES notification_channel(notification_channel_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB
PARTITION BY RANGE (YEAR(sent_at)) (
  PARTITION p2024 VALUES LESS THAN (2025),
  PARTITION p2025 VALUES LESS THAN (2026),
  PARTITION p2026 VALUES LESS THAN (2027),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- =========================================================
-- MULTI-SALESMAN CART SYSTEM
-- =========================================================

CREATE TABLE shopping_cart (
  cart_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  cart_type VARCHAR(20) NOT NULL DEFAULT 'RENTAL',
  status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
  
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  converted_at TIMESTAMP(6) NULL,
  expires_at TIMESTAMP(6) NULL,
  
  INDEX idx_cart_customer (customer_id, status),
  INDEX idx_cart_user (user_id, created_at DESC),
  INDEX idx_cart_status (status, expires_at),
  
  CONSTRAINT fk_cart_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cart_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cart_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_cart_user FOREIGN KEY (user_id)
    REFERENCES master_user(master_user_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE shopping_cart_item (
  cart_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cart_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  added_by_user_id INT UNSIGNED NOT NULL,
  
  item_type VARCHAR(20) NOT NULL,
  rent_price DECIMAL(12,2) UNSIGNED,
  sale_price DECIMAL(12,2) UNSIGNED,
  security_deposit DECIMAL(12,2) UNSIGNED,
  
  rental_start_date TIMESTAMP(6) NULL,
  rental_end_date TIMESTAMP(6) NULL,
  
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_cart_item_cart (cart_id),
  INDEX idx_cart_item_asset (asset_id),
  INDEX idx_cart_item_user (added_by_user_id),
  
  CONSTRAINT fk_cart_item_cart FOREIGN KEY (cart_id)
    REFERENCES shopping_cart(cart_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_cart_item_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cart_item_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cart_item_user FOREIGN KEY (added_by_user_id)
    REFERENCES master_user(master_user_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- RENTAL ORDERS (ENHANCED)
-- =========================================================

CREATE TABLE rental_order (
  rental_order_id INT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  user_id INT UNSIGNED NOT NULL,
  
  order_no VARCHAR(100) NOT NULL,
  reference_no VARCHAR(100),
  
  start_date TIMESTAMP(6) NOT NULL,
  due_date TIMESTAMP(6) NOT NULL,
  end_date TIMESTAMP(6) NULL,
  
  total_items SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  
  security_deposit DECIMAL(12,2) UNSIGNED NOT NULL DEFAULT 0,
  deposit_due_on TIMESTAMP(6) NULL,
  subtotal_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  tax_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  discount_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  
  cancellation_charge DECIMAL(12,2) UNSIGNED DEFAULT 0,
  late_fee DECIMAL(12,2) UNSIGNED DEFAULT 0,
  delivery_charge DECIMAL(12,2) UNSIGNED DEFAULT 0,
  additional_charges DECIMAL(12,2) UNSIGNED DEFAULT 0,
  additional_charges_desc TEXT,
  
  gst_percentage DECIMAL(5,2) UNSIGNED DEFAULT 0,
  cgst_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  sgst_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  igst_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  round_off DECIMAL(10,2) DEFAULT 0,
  
  total_amount DECIMAL(14,2) UNSIGNED NOT NULL,
  paid_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  balance_due DECIMAL(14,2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
  
  rental_billing_period_id TINYINT UNSIGNED NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'INR',
  
  rental_order_status_id TINYINT UNSIGNED NOT NULL,
  is_overdue BOOLEAN GENERATED ALWAYS AS (
    CASE WHEN end_date IS NULL AND due_date < CURRENT_TIMESTAMP(6) THEN TRUE ELSE FALSE END
  ) STORED,
  
  pickup_person_name VARCHAR(200),
  pickup_person_mobile VARCHAR(20),
  return_person_name VARCHAR(200),
  return_person_mobile VARCHAR(20),
  actual_pickup_time TIMESTAMP(6) NULL,
  actual_return_time TIMESTAMP(6) NULL,
  expected_pickup_time TIMESTAMP(6) NULL,
  buffer_days TINYINT UNSIGNED DEFAULT 0,
  
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_reason TEXT,
  deleted_by VARCHAR(100),
  deleted_at TIMESTAMP(6) NULL,
  approved_by INT UNSIGNED,
  approved_at TIMESTAMP(6) NULL,
  
  notes TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  PRIMARY KEY (rental_order_id, start_date),
  
  UNIQUE KEY uq_rental_business_branch_order (business_id, branch_id, order_no),
  INDEX idx_rental_customer_dates (customer_id, start_date DESC, due_date),
  INDEX idx_rental_branch_status (branch_id, rental_order_status_id, is_active),
  INDEX idx_rental_user (user_id, created_at DESC),
  INDEX idx_rental_dates_status (start_date, due_date, rental_order_status_id),
  INDEX idx_rental_overdue (is_overdue, business_id, branch_id),
  INDEX idx_rental_balance (balance_due, business_id, branch_id),
  INDEX idx_rental_deleted (is_deleted, business_id),
  INDEX idx_rental_approval (approved_by, approved_at),
  INDEX idx_rental_list_cover (business_id, branch_id, is_active, start_date DESC, order_no, rental_order_id),
  INDEX idx_rental_financial (business_id, start_date, total_amount DESC, paid_amount),
  INDEX idx_rental_order_dates_business (business_id, start_date DESC, due_date),
  
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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (YEAR(start_date)) (
  PARTITION p2023 VALUES LESS THAN (2024),
  PARTITION p2024 VALUES LESS THAN (2025),
  PARTITION p2025 VALUES LESS THAN (2026),
  PARTITION p2026 VALUES LESS THAN (2027),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

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
  
  rent_price DECIMAL(12,2) UNSIGNED NOT NULL,
  product_condition_at_rental TINYINT UNSIGNED,
  
  added_by_user_id INT UNSIGNED,
  incentive_amount DECIMAL(10,2) UNSIGNED DEFAULT 0,
  
  notes TEXT,
  created_by VARCHAR(100),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),

  INDEX idx_rental_item_order (rental_order_id, rental_order_item_id),
  INDEX idx_rental_item_asset (asset_id, rental_order_id),
  INDEX idx_rental_item_model (product_model_id, business_id),
  INDEX idx_rental_item_customer (customer_id, created_at DESC),
  INDEX idx_rental_item_business (business_id, branch_id, created_at DESC),
  INDEX idx_rental_item_salesman (added_by_user_id, created_at DESC),
  INDEX idx_rental_item_cover (rental_order_id, asset_id, rent_price, rental_order_item_id),
  
  CONSTRAINT fk_rental_item_order FOREIGN KEY (rental_order_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rental_item_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rental_item_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rental_item_segment FOREIGN KEY (product_segment_id)
    REFERENCES product_segment(product_segment_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rental_item_category FOREIGN KEY (product_category_id)
    REFERENCES product_category(product_category_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rental_item_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rental_item_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rental_item_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_rental_item_salesman FOREIGN KEY (added_by_user_id)
    REFERENCES master_user(master_user_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_rental_item_price CHECK (rent_price >= 0)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

-- =========================================================
-- SALES ORDERS (ENHANCED)
-- =========================================================

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
  
  cancellation_charge DECIMAL(12,2) UNSIGNED DEFAULT 0,
  delivery_charge DECIMAL(12,2) UNSIGNED DEFAULT 0,
  additional_charges DECIMAL(12,2) UNSIGNED DEFAULT 0,
  additional_charges_desc TEXT,
  
  gst_percentage DECIMAL(5,2) UNSIGNED DEFAULT 0,
  cgst_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  sgst_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  igst_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  round_off DECIMAL(10,2) DEFAULT 0,
  
  total_amount DECIMAL(14,2) UNSIGNED NOT NULL,
  paid_amount DECIMAL(14,2) UNSIGNED NOT NULL DEFAULT 0,
  balance_due DECIMAL(14,2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
  currency CHAR(3) NOT NULL DEFAULT 'INR',
  
  sales_order_status_id TINYINT UNSIGNED NOT NULL,
  
  is_deleted BOOLEAN DEFAULT FALSE,
  deleted_reason TEXT,
  deleted_by VARCHAR(100),
  deleted_at TIMESTAMP(6) NULL,
  approved_by INT UNSIGNED,
  approved_at TIMESTAMP(6) NULL,
  
  notes TEXT,
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  PRIMARY KEY (sales_order_id, order_date),
  
  UNIQUE KEY uq_sales_business_branch_order (business_id, branch_id, order_no),
  INDEX idx_sales_customer_date (customer_id, order_date DESC),
  INDEX idx_sales_branch_status (branch_id, sales_order_status_id, is_active),
  INDEX idx_sales_user (user_id, created_at DESC),
  INDEX idx_sales_date_status (order_date DESC, sales_order_status_id),
  INDEX idx_sales_balance (balance_due, business_id, branch_id),
  INDEX idx_sales_deleted (is_deleted, business_id),
  INDEX idx_sales_list_cover (business_id, branch_id, is_active, order_date DESC, order_no, sales_order_id),
  INDEX idx_sales_financial (business_id, order_date, total_amount DESC, paid_amount),
  INDEX idx_sales_order_dates_business (business_id, order_date DESC),

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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (YEAR(order_date)) (
  PARTITION p2023 VALUES LESS THAN (2024),
  PARTITION p2024 VALUES LESS THAN (2025),
  PARTITION p2025 VALUES LESS THAN (2026),
  PARTITION p2026 VALUES LESS THAN (2027),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

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
  
  added_by_user_id INT UNSIGNED,
  incentive_amount DECIMAL(10,2) UNSIGNED DEFAULT 0,
  
  notes TEXT,
  created_by VARCHAR(100),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),

  INDEX idx_sales_item_order (sales_order_id, sales_order_item_id),
  INDEX idx_sales_item_asset (asset_id, sales_order_id),
  INDEX idx_sales_item_model (product_model_id, business_id),
  INDEX idx_sales_item_customer (customer_id, created_at DESC),
  INDEX idx_sales_item_salesman (added_by_user_id, created_at DESC),
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
  CONSTRAINT fk_sales_item_salesman FOREIGN KEY (added_by_user_id)
    REFERENCES master_user(master_user_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_sales_item_price CHECK (sell_price >= 0)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;


-- =========================================================
-- INVOICES & BILLING
-- =========================================================

CREATE TABLE invoices (
  invoice_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NULL,
  rental_order_id INT UNSIGNED NULL,
  sales_order_id INT UNSIGNED NULL,
  invoice_no VARCHAR(100) NOT NULL,
  invoice_date TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  invoice_type_id TINYINT UNSIGNED NOT NULL,
  
  storage_provider VARCHAR(100) NOT NULL,
  storage_bucket VARCHAR(255) NOT NULL,
  storage_object_key VARCHAR(255) NOT NULL,
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
  INDEX idx_invoice_date_type (invoice_date DESC, invoice_type_id),
  INDEX idx_invoices_invoice_type_id (invoice_type_id),
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
  CONSTRAINT fk_invoice_type FOREIGN KEY (invoice_type_id)
    REFERENCES master_invoice_type(master_invoice_type_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_invoice_order_link CHECK (
    (rental_order_id IS NOT NULL AND sales_order_id IS NULL) OR
    (rental_order_id IS NULL AND sales_order_id IS NOT NULL)
  )
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE credit_debit_note (
  note_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  note_type VARCHAR(20) NOT NULL,
  note_no VARCHAR(100) NOT NULL,
  
  original_invoice_id BIGINT UNSIGNED NULL,
  rental_order_id INT UNSIGNED NULL,
  sales_order_id INT UNSIGNED NULL,
  customer_id INT UNSIGNED NOT NULL,
  
  note_date DATE NOT NULL,
  amount DECIMAL(14,2) NOT NULL,
  gst_amount DECIMAL(12,2) DEFAULT 0,
  total_amount DECIMAL(14,2) NOT NULL,
  
  reason TEXT NOT NULL,
  adjustment_type VARCHAR(100),
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  approved_by INT UNSIGNED,
  approved_at TIMESTAMP(6) NULL,
  
  UNIQUE KEY uq_note_business_no (business_id, note_no),
  INDEX idx_note_customer (customer_id, note_date DESC),
  INDEX idx_note_invoice (original_invoice_id),
  INDEX idx_note_type_date (note_type, note_date DESC),
  
  CONSTRAINT fk_note_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_note_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_note_invoice FOREIGN KEY (original_invoice_id)
    REFERENCES invoices(invoice_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_note_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_note_rental FOREIGN KEY (rental_order_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_note_sales FOREIGN KEY (sales_order_id)
    REFERENCES sales_order(sales_order_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE general_voucher (
  voucher_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  voucher_no VARCHAR(100) NOT NULL,
  voucher_type VARCHAR(50) NOT NULL,
  voucher_date DATE NOT NULL,
  
  party_type VARCHAR(50),
  party_id INT UNSIGNED,
  party_name VARCHAR(200),
  
  amount DECIMAL(14,2) NOT NULL,
  payment_mode_id TINYINT UNSIGNED,
  reference_no VARCHAR(255),
  
  description TEXT,
  narration TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_voucher_business_no (business_id, voucher_no),
  INDEX idx_voucher_party (party_type, party_id, voucher_date DESC),
  INDEX idx_voucher_type_date (voucher_type, voucher_date DESC),
  
  CONSTRAINT fk_voucher_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_voucher_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_voucher_payment_mode FOREIGN KEY (payment_mode_id)
    REFERENCES payment_mode(payment_mode_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- PAYMENTS
-- =========================================================

CREATE TABLE payments (
  payment_id BIGINT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  payment_reference VARCHAR(255),
  paid_on TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  amount DECIMAL(14,2) UNSIGNED NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'INR',
  mode_of_payment_id TINYINT UNSIGNED NULL,
  payer_customer_id INT UNSIGNED NULL,
  received_by_user_id INT UNSIGNED NULL,
  payment_direction_id TINYINT UNSIGNED NOT NULL,
  payment_status_id TINYINT UNSIGNED NOT NULL,
  external_response JSON,
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),

  PRIMARY KEY (payment_id, paid_on),

  INDEX idx_payment_reference (payment_reference),
  INDEX idx_payment_business_date (business_id, branch_id, paid_on DESC),
  INDEX idx_payment_customer (payer_customer_id, paid_on DESC),
  INDEX idx_payment_user (received_by_user_id, paid_on DESC),
  INDEX idx_payment_status_date (payment_status_id, paid_on DESC),
  INDEX idx_pay_direction_id (payment_direction_id),
  INDEX idx_pay_status_id (payment_status_id),
  INDEX idx_payment_direction (payment_direction_id, payment_status_id, paid_on DESC),
  INDEX idx_payment_recon_cover (business_id, paid_on DESC, amount, payment_status_id, payment_id),

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
  CONSTRAINT fk_payment_direction FOREIGN KEY (payment_direction_id)
    REFERENCES master_payment_direction(master_payment_direction_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_payment_status FOREIGN KEY (payment_status_id)
    REFERENCES master_payment_status(master_payment_status_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_payment_amount CHECK (amount > 0)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (YEAR(paid_on)) (
  PARTITION p2023 VALUES LESS THAN (2024),
  PARTITION p2024 VALUES LESS THAN (2025),
  PARTITION p2025 VALUES LESS THAN (2026),
  PARTITION p2026 VALUES LESS THAN (2027),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

-- =========================================================
-- MAINTENANCE & DAMAGE TRACKING
-- =========================================================

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
  
  washer_id INT UNSIGNED,
  cleaning_job_id INT UNSIGNED,
  
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
  INDEX idx_maint_washer (washer_id),
  INDEX idx_maint_list_cover (business_id, branch_id, maintenance_status_id, reported_on DESC, asset_id, maintenance_id),
  
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
    CONSTRAINT fk_maint_washer FOREIGN KEY (washer_id)
    REFERENCES washer_vendor(washer_id)
    ON DELETE SET NULL ON UPDATE CASCADE;

  CONSTRAINT chk_maint_dates CHECK (
    (scheduled_date IS NULL OR scheduled_date >= reported_on) AND
    (completed_on IS NULL OR completed_on >= reported_on)
  ),
  CONSTRAINT chk_maint_costs CHECK (
    (estimated_cost IS NULL OR estimated_cost >= 0) AND
    (actual_cost IS NULL OR actual_cost >= 0)
  )
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE damage_reports (
  damage_report_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  
  reported_by INT UNSIGNED NULL,
  reported_on TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  description TEXT NOT NULL,
  severity_id TINYINT UNSIGNED NOT NULL,
  damage_images JSON,
  
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
  
  INDEX idx_damage_severity_id (severity_id),
  INDEX idx_damage_asset_date (asset_id, reported_on DESC),
  INDEX idx_damage_branch_severity (branch_id, severity_id, resolved),
  INDEX idx_damage_reported_by (reported_by, reported_on DESC),
  INDEX idx_damage_unresolved (resolved, business_id, branch_id),
  INDEX idx_damage_customer (customer_id, resolved),
  INDEX idx_damage_list_cover (business_id, branch_id, resolved, reported_on DESC, severity_id, asset_id, damage_report_id),
  
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
  CONSTRAINT fk_damage_severity FOREIGN KEY (severity_id)
    REFERENCES damage_severity(damage_severity_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_damage_costs CHECK (
    (estimated_cost IS NULL OR estimated_cost >= 0) AND
    (actual_repair_cost IS NULL OR actual_repair_cost >= 0) AND
    (insurance_payout IS NULL OR insurance_payout >= 0) AND
    (liability_amount IS NULL OR liability_amount >= 0)
  )
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

-- =========================================================
-- RESERVATIONS & DEPOSITS
-- =========================================================

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
  INDEX idx_res_availability_cover (product_model_id, branch_id, reservation_status_id, reserved_from, reserved_until, quantity_requested),
  
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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE reservation_item (
  reservation_item_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reservation_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NULL,
  
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
  CONSTRAINT chk_res_item_dates CHECK (end_date > start_date)
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

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
  INDEX idx_deposit_cover (business_id, branch_id, is_released, amount, held_since DESC, customer_id),
  
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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;


-- =========================================================
-- STOCK MANAGEMENT
-- =========================================================

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
    quantity_available + quantity_reserved + quantity_on_rent +
    quantity_in_maintenance + quantity_damaged + quantity_lost
  ) STORED,
  
  is_rentable BOOLEAN GENERATED ALWAYS AS (quantity_available > 0) STORED,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  last_updated_by VARCHAR(100),
  last_updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),

  UNIQUE KEY uq_stock_business_branch_model (business_id, branch_id, product_model_id),
  INDEX idx_stock_branch_segment (branch_id, product_segment_id),
  INDEX idx_stock_branch_category (branch_id, product_category_id),
  INDEX idx_stock_available (is_rentable, business_id, branch_id),
  INDEX idx_stock_model_branch (product_model_id, branch_id),
  INDEX idx_stock_summary_cover (business_id, branch_id, product_model_id, quantity_available, quantity_on_rent, quantity_total),
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
    quantity_available >= 0 AND quantity_reserved >= 0 AND
    quantity_on_rent >= 0 AND quantity_sold >= 0 AND
    quantity_in_maintenance >= 0 AND quantity_damaged >= 0 AND
    quantity_lost >= 0
  )
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC;

CREATE TABLE stock_movements (
  stock_movement_id INT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  inventory_movement_type_id TINYINT UNSIGNED NOT NULL,
  quantity SMALLINT NOT NULL,
  
  from_branch_id INT UNSIGNED NULL,
  to_branch_id INT UNSIGNED NULL,
  from_product_status_id TINYINT UNSIGNED NULL,
  to_product_status_id TINYINT UNSIGNED NULL,
  
  related_rental_id INT UNSIGNED NULL,
  related_reservation_id INT UNSIGNED NULL,
  related_maintenance_id INT UNSIGNED NULL,
  reference_no VARCHAR(100),
  note TEXT,
  metadata JSON,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  deleted_at TIMESTAMP(6) NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  PRIMARY KEY (stock_movement_id, created_at),
  
  INDEX idx_stock_mov_model_date (product_model_id, created_at DESC),
  INDEX idx_stock_mov_branch_date (branch_id, created_at DESC),
  INDEX idx_stock_mov_type (inventory_movement_type_id, created_at DESC),
  INDEX idx_stock_mov_rental (related_rental_id),
  INDEX idx_stock_mov_history_cover (business_id, branch_id, product_model_id, created_at DESC, quantity, inventory_movement_type_id),
  
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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (YEAR(created_at)) (
  PARTITION p2023 VALUES LESS THAN (2024),
  PARTITION p2024 VALUES LESS THAN (2025),
  PARTITION p2025 VALUES LESS THAN (2026),
  PARTITION p2026 VALUES LESS THAN (2027),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

CREATE TABLE asset_movements (
  asset_movement_id INT UNSIGNED AUTO_INCREMENT,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NULL,
  asset_id INT UNSIGNED NOT NULL,
  inventory_movement_type_id TINYINT UNSIGNED NOT NULL,
  
  from_branch_id INT UNSIGNED NULL,
  to_branch_id INT UNSIGNED NULL,
  from_product_status_id TINYINT UNSIGNED NULL,
  to_product_status_id TINYINT UNSIGNED NULL,
  
  related_rental_id INT UNSIGNED NULL,
  related_reservation_id INT UNSIGNED NULL,
  related_maintenance_id INT UNSIGNED NULL,
  reference_no VARCHAR(100),
  note TEXT,
  metadata JSON,
  
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
  INDEX idx_asset_mov_history_cover (asset_id, created_at DESC, inventory_movement_type_id, from_product_status_id, to_product_status_id),

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
) ENGINE=InnoDB ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (YEAR(created_at)) (
  PARTITION p2023 VALUES LESS THAN (2024),
  PARTITION p2024 VALUES LESS THAN (2025),
  PARTITION p2025 VALUES LESS THAN (2026),
  PARTITION p2026 VALUES LESS THAN (2027),
  PARTITION p_future VALUES LESS THAN MAXVALUE
);

-- =========================================================
-- ORDER PROGRESS TRACKING
-- =========================================================

CREATE TABLE order_progress (
  progress_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  rental_order_id INT UNSIGNED NOT NULL,
  stage_id TINYINT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NULL,
  
  status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  started_at TIMESTAMP(6) NULL,
  completed_at TIMESTAMP(6) NULL,
  assigned_to VARCHAR(100),
  
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  INDEX idx_progress_order (rental_order_id, stage_id),
  INDEX idx_progress_asset (asset_id, stage_id),
  INDEX idx_progress_status (status, stage_id),
  
  CONSTRAINT fk_progress_order FOREIGN KEY (rental_order_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_progress_stage FOREIGN KEY (stage_id)
    REFERENCES order_progress_stage(stage_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_progress_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- DRY CLEANING & WASHER MANAGEMENT
-- =========================================================

CREATE TABLE washer_vendor (
  washer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  vendor_name VARCHAR(200) NOT NULL,
  contact_person VARCHAR(200),
  contact_number VARCHAR(20) NOT NULL,
  email VARCHAR(255),
  
  address_line VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(100),
  pincode VARCHAR(20),
  
  gstin VARCHAR(15),
  pan_no VARCHAR(10),
  
  default_cleaning_charge DECIMAL(10,2) UNSIGNED,
  default_pressing_charge DECIMAL(10,2) UNSIGNED,
  default_stitching_charge DECIMAL(10,2) UNSIGNED,
  
  payment_terms VARCHAR(200),
  credit_days SMALLINT UNSIGNED DEFAULT 0,
  credit_limit DECIMAL(12,2) UNSIGNED DEFAULT 0,
  
  outstanding_amount DECIMAL(14,2) DEFAULT 0,
  
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  INDEX idx_washer_business (business_id, is_active),
  INDEX idx_washer_name (vendor_name),
  
  CONSTRAINT fk_washer_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cleaning_job (
  cleaning_job_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  washer_id INT UNSIGNED NOT NULL,
  
  job_no VARCHAR(100) NOT NULL,
  job_date DATE NOT NULL,
  expected_completion_date DATE,
  actual_completion_date DATE NULL,
  
  total_items SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  cleaning_charge DECIMAL(12,2) UNSIGNED DEFAULT 0,
  pressing_charge DECIMAL(12,2) UNSIGNED DEFAULT 0,
  stitching_charge DECIMAL(12,2) UNSIGNED DEFAULT 0,
  total_charge DECIMAL(12,2) UNSIGNED NOT NULL,
  
  status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  
  notes TEXT,
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_cleaning_job_business_no (business_id, job_no),
  INDEX idx_cleaning_washer_date (washer_id, job_date DESC),
  INDEX idx_cleaning_status (status, expected_completion_date),
  
  CONSTRAINT fk_cleaning_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cleaning_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cleaning_washer FOREIGN KEY (washer_id)
    REFERENCES washer_vendor(washer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cleaning_job_item (
  cleaning_job_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  cleaning_job_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  
  service_type VARCHAR(100) NOT NULL,
  charge DECIMAL(10,2) UNSIGNED NOT NULL,
  
  received_condition VARCHAR(50),
  returned_condition VARCHAR(50),
  
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_cleaning_item_job (cleaning_job_id),
  INDEX idx_cleaning_item_asset (asset_id),
  
  CONSTRAINT fk_cleaning_item_job FOREIGN KEY (cleaning_job_id)
    REFERENCES cleaning_job(cleaning_job_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_cleaning_item_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- ALTERATION MANAGEMENT
-- =========================================================

CREATE TABLE alteration_request (
  alteration_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  
  rental_order_id INT UNSIGNED NULL,
  asset_id INT UNSIGNED NOT NULL,
  customer_id INT UNSIGNED NOT NULL,
  
  request_no VARCHAR(100) NOT NULL,
  request_date DATE NOT NULL,
  required_by_date DATE,
  
  alteration_type VARCHAR(100) NOT NULL,
  description TEXT NOT NULL,
  measurements JSON,
  
  estimated_charge DECIMAL(10,2) UNSIGNED DEFAULT 0,
  actual_charge DECIMAL(10,2) UNSIGNED,
  is_chargeable BOOLEAN DEFAULT TRUE,
  
  status VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  assigned_to VARCHAR(100),
  
  requested_by VARCHAR(100) NOT NULL,
  approved_by INT UNSIGNED NULL,
  approved_at TIMESTAMP(6) NULL,
  completed_at TIMESTAMP(6) NULL,
  
  rejection_reason TEXT,
  
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_alteration_business_no (business_id, request_no),
  INDEX idx_alteration_asset (asset_id, status),
  INDEX idx_alteration_rental (rental_order_id),
  INDEX idx_alteration_status_date (status, required_by_date),
  
  CONSTRAINT fk_alteration_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_alteration_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_alteration_rental FOREIGN KEY (rental_order_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_alteration_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_alteration_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;


-- =========================================================
-- DARJI / TAILOR MANAGEMENT
-- =========================================================

CREATE TABLE darji_master (
  darji_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  
  darji_name VARCHAR(200) NOT NULL,
  contact_number VARCHAR(20) NOT NULL,
  email VARCHAR(255),
  
  address_line VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(100),
  pincode VARCHAR(20),
  
  specialization VARCHAR(200),
  experience_years TINYINT UNSIGNED,
  
  payment_type VARCHAR(50),
  rate_per_piece DECIMAL(10,2) UNSIGNED,
  monthly_salary DECIMAL(12,2) UNSIGNED,
  commission_percentage DECIMAL(5,2) UNSIGNED,
  
  bank_account_no VARCHAR(50),
  ifsc_code VARCHAR(11),
  bank_name VARCHAR(200),
  pan_no VARCHAR(10),
  aadhar_no VARCHAR(12),
  
  outstanding_payment DECIMAL(14,2) DEFAULT 0,
  total_pieces_completed INT UNSIGNED DEFAULT 0,
  total_earnings DECIMAL(14,2) UNSIGNED DEFAULT 0,
  
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  INDEX idx_darji_business (business_id, is_active),
  INDEX idx_darji_name (darji_name),
  INDEX idx_darji_outstanding (outstanding_payment DESC),
  
  CONSTRAINT fk_darji_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE darji_work_assignment (
  assignment_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  darji_id INT UNSIGNED NOT NULL,
  
  assignment_no VARCHAR(100) NOT NULL,
  assignment_date DATE NOT NULL,
  due_date DATE,
  
  work_type VARCHAR(100) NOT NULL,
  asset_id INT UNSIGNED NULL,
  rental_order_id INT UNSIGNED NULL,
  alteration_request_id INT UNSIGNED NULL,
  
  description TEXT,
  specifications JSON,
  
  agreed_rate DECIMAL(10,2) UNSIGNED NOT NULL,
  advance_paid DECIMAL(10,2) UNSIGNED DEFAULT 0,
  balance_due DECIMAL(10,2) UNSIGNED,
  
  status VARCHAR(50) NOT NULL DEFAULT 'ASSIGNED',
  
  started_at DATE NULL,
  completed_at DATE NULL,
  delivered_at DATE NULL,
  
  quality_rating TINYINT UNSIGNED,
  quality_notes TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_darji_assignment_business_no (business_id, assignment_no),
  INDEX idx_darji_work_darji (darji_id, status, due_date),
  INDEX idx_darji_work_asset (asset_id),
  INDEX idx_darji_work_status (status, due_date),
  
  CONSTRAINT fk_darji_work_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_darji_work_darji FOREIGN KEY (darji_id)
    REFERENCES darji_master(darji_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_darji_work_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_darji_work_rental FOREIGN KEY (rental_order_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_darji_work_alteration FOREIGN KEY (alteration_request_id)
    REFERENCES alteration_request(alteration_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_darji_work_rating CHECK (quality_rating IS NULL OR quality_rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

CREATE TABLE darji_payment (
  payment_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  darji_id INT UNSIGNED NOT NULL,
  
  payment_no VARCHAR(100) NOT NULL,
  payment_date DATE NOT NULL,
  
  payment_type VARCHAR(50) NOT NULL,
  amount DECIMAL(12,2) NOT NULL,
  payment_mode_id TINYINT UNSIGNED NOT NULL,
  reference_no VARCHAR(255),
  
  assignment_ids JSON,
  
  notes TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_darji_payment_business_no (business_id, payment_no),
  INDEX idx_darji_payment_darji (darji_id, payment_date DESC),
  INDEX idx_darji_payment_date (payment_date DESC),
  
  CONSTRAINT fk_darji_payment_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_darji_payment_darji FOREIGN KEY (darji_id)
    REFERENCES darji_master(darji_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_darji_payment_mode FOREIGN KEY (payment_mode_id)
    REFERENCES payment_mode(payment_mode_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- MANUFACTURING & BILL OF MATERIALS
-- =========================================================

CREATE TABLE raw_material (
  material_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  
  material_code VARCHAR(100) NOT NULL,
  material_name VARCHAR(200) NOT NULL,
  material_category VARCHAR(100),
  
  unit_of_measure VARCHAR(50) NOT NULL,
  current_stock DECIMAL(12,3) DEFAULT 0,
  reorder_level DECIMAL(12,3),
  
  unit_cost DECIMAL(12,2) UNSIGNED,
  supplier_id INT UNSIGNED,
  
  description TEXT,
  
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_material_business_code (business_id, material_code),
  INDEX idx_material_category (material_category, business_id),
  INDEX idx_material_stock (current_stock, reorder_level),
  
  CONSTRAINT fk_material_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE bill_of_materials (
  bom_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  product_model_id INT UNSIGNED NOT NULL,
  
  bom_version VARCHAR(20) DEFAULT '1.0',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  
  total_material_cost DECIMAL(12,2) UNSIGNED,
  total_labor_cost DECIMAL(12,2) UNSIGNED,
  overhead_cost DECIMAL(12,2) UNSIGNED,
  total_cost DECIMAL(12,2) UNSIGNED,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  INDEX idx_bom_model (product_model_id, is_active),
  INDEX idx_bom_business (business_id),
  
  CONSTRAINT fk_bom_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_bom_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE bom_item (
  bom_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  bom_id INT UNSIGNED NOT NULL,
  material_id INT UNSIGNED NOT NULL,
  
  quantity_required DECIMAL(12,3) NOT NULL,
  unit_of_measure VARCHAR(50) NOT NULL,
  unit_cost DECIMAL(12,2) UNSIGNED,
  total_cost DECIMAL(12,2) UNSIGNED,
  
  wastage_percentage DECIMAL(5,2) UNSIGNED DEFAULT 0,
  
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_bom_item_bom (bom_id),
  INDEX idx_bom_item_material (material_id),
  
  CONSTRAINT fk_bom_item_bom FOREIGN KEY (bom_id)
    REFERENCES bill_of_materials(bom_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_bom_item_material FOREIGN KEY (material_id)
    REFERENCES raw_material(material_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE production_order (
  production_order_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  
  production_no VARCHAR(100) NOT NULL,
  production_date DATE NOT NULL,
  expected_completion_date DATE,
  
  product_model_id INT UNSIGNED NOT NULL,
  bom_id INT UNSIGNED NOT NULL,
  quantity INT UNSIGNED NOT NULL DEFAULT 1,
  
  status VARCHAR(50) NOT NULL DEFAULT 'PLANNED',
  
  darji_id INT UNSIGNED,
  assigned_date DATE,
  
  total_material_cost DECIMAL(14,2) UNSIGNED,
  total_labor_cost DECIMAL(14,2) UNSIGNED,
  total_cost DECIMAL(14,2) UNSIGNED,
  
  completed_quantity INT UNSIGNED DEFAULT 0,
  rejected_quantity INT UNSIGNED DEFAULT 0,
  
  notes TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_production_business_no (business_id, production_no),
  INDEX idx_production_model (product_model_id, status),
  INDEX idx_production_darji (darji_id, status),
  INDEX idx_production_status_date (status, expected_completion_date),
  
  CONSTRAINT fk_production_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_production_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_production_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_production_bom FOREIGN KEY (bom_id)
    REFERENCES bill_of_materials(bom_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_production_darji FOREIGN KEY (darji_id)
    REFERENCES darji_master(darji_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE production_output (
  output_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  production_order_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  
  output_date DATE NOT NULL,
  quality_status VARCHAR(50),
  
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_production_output_order (production_order_id),
  INDEX idx_production_output_asset (asset_id),
  
  CONSTRAINT fk_production_output_order FOREIGN KEY (production_order_id)
    REFERENCES production_order(production_order_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_production_output_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- SUPPLIER & PURCHASE MANAGEMENT
-- =========================================================

CREATE TABLE supplier (
  supplier_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  
  supplier_code VARCHAR(100) NOT NULL,
  supplier_name VARCHAR(200) NOT NULL,
  supplier_type VARCHAR(100),
  
  contact_person VARCHAR(200),
  contact_number VARCHAR(20) NOT NULL,
  email VARCHAR(255),
  whatsapp_number VARCHAR(20),
  
  address_line VARCHAR(255),
  city VARCHAR(100),
  state VARCHAR(100),
  pincode VARCHAR(20),
  
  gstin VARCHAR(15),
  pan_no VARCHAR(10),
  
  payment_terms VARCHAR(200),
  credit_days SMALLINT UNSIGNED DEFAULT 0,
  credit_limit DECIMAL(14,2) UNSIGNED DEFAULT 0,
  
  outstanding_amount DECIMAL(14,2) DEFAULT 0,
  total_purchases DECIMAL(16,2) UNSIGNED DEFAULT 0,
  
  bank_account_no VARCHAR(50),
  ifsc_code VARCHAR(11),
  bank_name VARCHAR(200),
  
  rating TINYINT UNSIGNED,
  
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_supplier_business_code (business_id, supplier_code),
  INDEX idx_supplier_business (business_id, is_active),
  INDEX idx_supplier_name (supplier_name),
  INDEX idx_supplier_outstanding (outstanding_amount DESC),
  
  CONSTRAINT fk_supplier_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT chk_supplier_rating CHECK (rating IS NULL OR rating BETWEEN 1 AND 5)
) ENGINE=InnoDB;

-- Add FK to raw_material for supplier
ALTER TABLE raw_material
ADD CONSTRAINT fk_material_supplier FOREIGN KEY (supplier_id)
  REFERENCES supplier(supplier_id)
  ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE purchase_order (
  purchase_order_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  supplier_id INT UNSIGNED NOT NULL,
  
  po_no VARCHAR(100) NOT NULL,
  po_date DATE NOT NULL,
  expected_delivery_date DATE,
  
  purchase_type VARCHAR(50) NOT NULL,
  
  subtotal_amount DECIMAL(14,2) UNSIGNED NOT NULL,
  cgst_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  sgst_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  igst_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  other_charges DECIMAL(12,2) UNSIGNED DEFAULT 0,
  total_amount DECIMAL(14,2) UNSIGNED NOT NULL,
  
  paid_amount DECIMAL(14,2) UNSIGNED DEFAULT 0,
  balance_due DECIMAL(14,2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
  
  status VARCHAR(50) NOT NULL DEFAULT 'DRAFT',
  
  payment_due_date DATE,
  
  bill_type VARCHAR(20),
  supplier_invoice_no VARCHAR(100),
  supplier_invoice_date DATE,
  invoice_upload_url VARCHAR(1024),
  
  notes TEXT,
  terms_conditions TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_po_business_no (business_id, po_no),
  INDEX idx_po_supplier_date (supplier_id, po_date DESC),
  INDEX idx_po_status (status, expected_delivery_date),
  INDEX idx_po_payment_due (payment_due_date, balance_due),
  
  CONSTRAINT fk_po_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_po_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_po_supplier FOREIGN KEY (supplier_id)
    REFERENCES supplier(supplier_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE purchase_order_item (
  po_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  purchase_order_id INT UNSIGNED NOT NULL,
  
  item_type VARCHAR(50) NOT NULL,
  
  material_id INT UNSIGNED,
  product_model_id INT UNSIGNED,
  
  item_description TEXT NOT NULL,
  quantity DECIMAL(12,3) NOT NULL,
  unit_of_measure VARCHAR(50) NOT NULL,
  
  unit_price DECIMAL(12,2) UNSIGNED NOT NULL,
  total_price DECIMAL(14,2) UNSIGNED NOT NULL,
  
  received_quantity DECIMAL(12,3) DEFAULT 0,
  
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_po_item_order (purchase_order_id),
  INDEX idx_po_item_material (material_id),
  INDEX idx_po_item_model (product_model_id),
  
  CONSTRAINT fk_po_item_order FOREIGN KEY (purchase_order_id)
    REFERENCES purchase_order(purchase_order_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_po_item_material FOREIGN KEY (material_id)
    REFERENCES raw_material(material_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_po_item_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE goods_received_note (
  grn_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  purchase_order_id INT UNSIGNED NOT NULL,
  
  grn_no VARCHAR(100) NOT NULL,
  grn_date DATE NOT NULL,
  
  received_by VARCHAR(100) NOT NULL,
  supplier_delivery_note VARCHAR(100),
  
  total_items INT UNSIGNED DEFAULT 0,
  total_quantity DECIMAL(12,3) DEFAULT 0,
  
  quality_status VARCHAR(50),
  
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_grn_business_no (business_id, grn_no),
  INDEX idx_grn_po (purchase_order_id, grn_date DESC),
  INDEX idx_grn_date (grn_date DESC),
  
  CONSTRAINT fk_grn_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_grn_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_grn_po FOREIGN KEY (purchase_order_id)
    REFERENCES purchase_order(purchase_order_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE grn_item (
  grn_item_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  grn_id INT UNSIGNED NOT NULL,
  po_item_id INT UNSIGNED NOT NULL,
  
  received_quantity DECIMAL(12,3) NOT NULL,
  accepted_quantity DECIMAL(12,3) NOT NULL,
  rejected_quantity DECIMAL(12,3) DEFAULT 0,
  
  quality_status VARCHAR(50),
  rejection_reason TEXT,
  
  notes TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_grn_item_grn (grn_id),
  INDEX idx_grn_item_po (po_item_id),
  
  CONSTRAINT fk_grn_item_grn FOREIGN KEY (grn_id)
    REFERENCES goods_received_note(grn_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_grn_item_po FOREIGN KEY (po_item_id)
    REFERENCES purchase_order_item(po_item_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE supplier_payment (
  payment_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  supplier_id INT UNSIGNED NOT NULL,
  
  payment_no VARCHAR(100) NOT NULL,
  payment_date DATE NOT NULL,
  
  amount DECIMAL(14,2) NOT NULL,
  payment_mode_id TINYINT UNSIGNED NOT NULL,
  reference_no VARCHAR(255),
  
  purchase_order_ids JSON,
  
  tds_amount DECIMAL(12,2) UNSIGNED DEFAULT 0,
  net_payment DECIMAL(14,2) NOT NULL,
  
  notes TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_supplier_payment_business_no (business_id, payment_no),
  INDEX idx_supplier_payment_supplier (supplier_id, payment_date DESC),
  INDEX idx_supplier_payment_date (payment_date DESC),
  
  CONSTRAINT fk_supplier_payment_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_supplier_payment_supplier FOREIGN KEY (supplier_id)
    REFERENCES supplier(supplier_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_supplier_payment_mode FOREIGN KEY (payment_mode_id)
    REFERENCES payment_mode(payment_mode_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- DELIVERY & LOGISTICS
-- =========================================================

CREATE TABLE delivery_person (
  delivery_person_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  
  person_name VARCHAR(200) NOT NULL,
  contact_number VARCHAR(20) NOT NULL,
  alternate_contact VARCHAR(20),
  
  vehicle_type VARCHAR(100),
  vehicle_number VARCHAR(50),
  
  license_number VARCHAR(50),
  aadhar_no VARCHAR(12),
  
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  INDEX idx_delivery_person_business (business_id, is_active),
  INDEX idx_delivery_person_name (person_name),
  
  CONSTRAINT fk_delivery_person_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE delivery_schedule (
  delivery_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  
  delivery_no VARCHAR(100) NOT NULL,
  delivery_type VARCHAR(50) NOT NULL,
  
  rental_order_id INT UNSIGNED NULL,
  sales_order_id INT UNSIGNED NULL,
  customer_id INT UNSIGNED NOT NULL,
  
  scheduled_date DATE NOT NULL,
  scheduled_time_from TIME,
  scheduled_time_to TIME,
  
  delivery_person_id INT UNSIGNED,
  
  delivery_address TEXT NOT NULL,
  customer_contact_name VARCHAR(200),
  customer_contact_mobile VARCHAR(20) NOT NULL,
  
  delivery_charge DECIMAL(10,2) UNSIGNED DEFAULT 0,
  
  status VARCHAR(50) NOT NULL DEFAULT 'SCHEDULED',
  
  actual_delivery_date DATE,
  actual_delivery_time TIME,
  
  received_by_name VARCHAR(200),
  received_by_signature_url VARCHAR(1024),
  delivery_proof_url VARCHAR(1024),
  
  notes TEXT,
  failure_reason TEXT,
  
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_delivery_business_no (business_id, delivery_no),
  INDEX idx_delivery_scheduled (scheduled_date, status),
  INDEX idx_delivery_person (delivery_person_id, scheduled_date),
  INDEX idx_delivery_customer (customer_id, delivery_type),
  INDEX idx_delivery_order (rental_order_id, sales_order_id),
  
  CONSTRAINT fk_delivery_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_delivery_branch FOREIGN KEY (branch_id)
    REFERENCES master_branch(branch_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_delivery_person FOREIGN KEY (delivery_person_id)
    REFERENCES delivery_person(delivery_person_id)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_delivery_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_delivery_rental FOREIGN KEY (rental_order_id)
    REFERENCES rental_order(rental_order_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_delivery_sales FOREIGN KEY (sales_order_id)
    REFERENCES sales_order(sales_order_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- TERMS & CONDITIONS MANAGEMENT
-- =========================================================

CREATE TABLE terms_and_conditions (
  tc_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  
  tc_type VARCHAR(50) NOT NULL COMMENT 'RENTAL, SALES, GENERAL',
  tc_title VARCHAR(200) NOT NULL,
  tc_content TEXT NOT NULL,
  
  version VARCHAR(20) DEFAULT '1.0',
  language CHAR(5) DEFAULT 'en-IN',
  
  display_order TINYINT UNSIGNED DEFAULT 0,
  is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
  
  effective_from DATE NOT NULL,
  effective_to DATE NULL,
  
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  INDEX idx_tc_business_type (business_id, tc_type, is_active),
  INDEX idx_tc_effective (effective_from, effective_to),
  
  CONSTRAINT fk_tc_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================================================
-- NOTIFICATION TEMPLATES
-- =========================================================

CREATE TABLE notification_template (
  template_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  
  template_code VARCHAR(100) NOT NULL,
  template_name VARCHAR(200) NOT NULL,
  template_type VARCHAR(50) NOT NULL COMMENT 'BOOKING_CONFIRM, PICKUP_REMINDER, READY_NOTIFY, RETURN_REMINDER, OVERDUE',
  
  notification_channel_id TINYINT UNSIGNED NOT NULL,
  
  subject VARCHAR(500),
  template_body TEXT NOT NULL,
  template_footer TEXT,
  
  variables JSON COMMENT 'Available placeholders like {{customer_name}}, {{order_no}}',
  
  language CHAR(5) DEFAULT 'en-IN',
  
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_by VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_by VARCHAR(100),
  updated_at TIMESTAMP(6) NULL ON UPDATE CURRENT_TIMESTAMP(6),
  
  UNIQUE KEY uq_template_business_code (business_id, template_code),
  INDEX idx_template_business_type (business_id, template_type, is_active),
  INDEX idx_template_channel (notification_channel_id),
  
  CONSTRAINT fk_template_business FOREIGN KEY (business_id)
    REFERENCES master_business(business_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_template_channel FOREIGN KEY (notification_channel_id)
    REFERENCES notification_channel(notification_channel_id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;