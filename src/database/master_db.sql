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
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_subscription_type;
CREATE TABLE master_subscription_type (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    max_branches INT DEFAULT 1,
    max_users INT DEFAULT 1,
    max_items INT DEFAULT 20,
    created_by VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_subscription_status;
CREATE TABLE master_subscription_status (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_billing_cycle;
CREATE TABLE master_billing_cycle (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

DROP TABLE IF EXISTS master_otp_type;
CREATE TABLE master_otp_type (
    id INT AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    created_by VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0
) ENGINE=InnoDB;

-- =========================================================
-- BUSINESS CORE TABLES
-- =========================================================
DROP TABLE IF EXISTS master_business;
CREATE TABLE master_business (
    business_id INT AUTO_INCREMENT PRIMARY KEY,
    business_name VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    contact_person VARCHAR(255) NOT NULL,
    contact_number VARCHAR(50) NOT NULL,
    website VARCHAR(255),
    street_address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    country VARCHAR(100) DEFAULT 'India',
    pincode VARCHAR(20) NOT NULL,

    status_id INT NOT NULL,
    subscription_type_id INT NOT NULL,
    subscription_status_id INT NOT NULL,
    billing_cycle_id INT NOT NULL,

    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0,

    created_by VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME,

    CONSTRAINT fk_business_status FOREIGN KEY (status_id)
        REFERENCES master_business_status(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_business_subscription_type FOREIGN KEY (subscription_type_id)
        REFERENCES master_subscription_type(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_business_subscription_status FOREIGN KEY (subscription_status_id)
        REFERENCES master_subscription_status(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_business_billing_cycle FOREIGN KEY (billing_cycle_id)
        REFERENCES master_billing_cycle(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS master_branch (
    branch_id INT AUTO_INCREMENT PRIMARY KEY,
    business_id INT NOT NULL,
    branch_name VARCHAR(255) NOT NULL,
    branch_code VARCHAR(100) NOT NULL,
    address_line VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    country VARCHAR(100) DEFAULT 'India',
    pincode VARCHAR(20) NOT NULL,
    contact_number VARCHAR(50) NOT NULL,
    timezone VARCHAR(100) DEFAULT 'Asia/Kolkata',

    created_by VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME,
    is_deleted TINYINT(1) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,

    INDEX idx_branch_business_id (business_id),
    CONSTRAINT fk_branch_business FOREIGN KEY (business_id)
        REFERENCES master_business(business_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS master_user (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    business_id INT NOT NULL,
    branch_id INT NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    contact_number VARCHAR(50) NOT NULL,

    created_by VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0,

    UNIQUE KEY uq_user_email_business (email, business_id),
    INDEX idx_user_email (email),
    INDEX idx_user_business (business_id),

    CONSTRAINT fk_user_business FOREIGN KEY (business_id)
        REFERENCES master_business(business_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_user_branch FOREIGN KEY (branch_id)
        REFERENCES master_branch(branch_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- other master tables left as-is (sessions/otp) but ensure is_deleted
CREATE TABLE IF NOT EXISTS master_user_session (
    id CHAR(36) PRIMARY KEY,
    user_id INT NOT NULL,
    device_id VARCHAR(255) NOT NULL,
    device_name VARCHAR(255),
    ip_address VARCHAR(100),
    user_agent VARCHAR(500),
    session_token VARCHAR(255) NOT NULL UNIQUE,

    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_active DATETIME DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,

    CONSTRAINT fk_session_user FOREIGN KEY (user_id)
        REFERENCES master_user(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS master_otp (
    id CHAR(36) PRIMARY KEY,
    identifier_user_id INT NOT NULL,
    otp_code VARCHAR(10) NOT NULL,
    otp_type_id INT NOT NULL,
    expires_at DATETIME NOT NULL,
    verified_at DATETIME,
    attempts INT DEFAULT 0,
    max_attempts INT DEFAULT 3,
    ip_address VARCHAR(100),

    created_by VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(255),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_otp_user FOREIGN KEY (identifier_user_id)
        REFERENCES master_user(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_otp_type FOREIGN KEY (otp_type_id)
        REFERENCES master_otp_type(id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- -- =========================================================
-- -- SEED DATA
-- -- =========================================================

-- INSERT INTO master_business_status (code, name, description, created_by) VALUES
-- ('ACTIVE', 'Active', 'Business is active', 'system'),
-- ('INACTIVE', 'Inactive', 'Business is inactive', 'system'),
-- ('SUSPENDED', 'Suspended', 'Business temporarily suspended', 'system'),
-- ('TERMINATED', 'Terminated', 'Business permanently closed', 'system'),
-- ('TRIAL', 'Trial', 'Business in trial mode', 'system');

-- INSERT INTO master_subscription_type (code, name, description, max_branches, max_users, max_items, created_by) VALUES
-- ('TRIAL', 'Trial', 'Trial plan', 1, 1, 20, 'system'),
-- ('BASIC', 'Basic', 'Basic plan', 1, 5, 100, 'system'),
-- ('STANDARD', 'Standard', 'Standard plan', 3, 10, 500, 'system'),
-- ('PREMIUM', 'Premium', 'Premium plan', 5, 50, 2000, 'system'),
-- ('ENTERPRISE', 'Enterprise', 'Enterprise plan', 10, 200, 10000, 'system'),
-- ('CUSTOM', 'Custom', 'Custom plan as per requirement', 50, 500, 50000, 'system');

-- INSERT INTO master_subscription_status (code, name, description, created_by) VALUES
-- ('ACTIVE', 'Active', 'Subscription is active', 'system'),
-- ('INACTIVE', 'Inactive', 'Subscription is inactive', 'system'),
-- ('SUSPENDED', 'Suspended', 'Subscription temporarily disabled', 'system'),
-- ('CANCELLED', 'Cancelled', 'Subscription cancelled by user', 'system'),
-- ('EXPIRED', 'Expired', 'Subscription expired', 'system');

-- INSERT INTO master_billing_cycle (code, name, created_by) VALUES
-- ('MONTHLY', 'Monthly', 'system'),
-- ('QUARTERLY', 'Quarterly', 'system'),
-- ('YEARLY', 'Yearly', 'system'),
-- ('LIFETIME', 'Lifetime', 'system');

-- INSERT INTO master_otp_type (code, name, created_by) VALUES
-- ('LOGIN', 'Login Verification', 'system'),
-- ('REGISTER', 'Register Verification', 'system'),
-- ('RESET_PASSWORD', 'Password Reset', 'system'),
-- ('VERIFY_EMAIL', 'Email Verification', 'system'),
-- ('VERIFY_PHONE', 'Phone Verification', 'system'),
-- ('TWO_FACTOR', 'Two Factor Authentication', 'system');


-- =========================================================
-- SEED DATA (idempotent inserts — only insert when code NOT EXISTS)
-- =========================================================

-- master_business_status
INSERT INTO master_business_status (code, name, description, created_by)
SELECT 'ACTIVE','Active','Business is active','system'
WHERE NOT EXISTS (SELECT 1 FROM master_business_status WHERE code = 'ACTIVE');

INSERT INTO master_business_status (code, name, description, created_by)
SELECT 'INACTIVE','Inactive','Business is inactive','system'
WHERE NOT EXISTS (SELECT 1 FROM master_business_status WHERE code = 'INACTIVE');

INSERT INTO master_business_status (code, name, description, created_by)
SELECT 'SUSPENDED','Suspended','Business temporarily suspended','system'
WHERE NOT EXISTS (SELECT 1 FROM master_business_status WHERE code = 'SUSPENDED');

INSERT INTO master_business_status (code, name, description, created_by)
SELECT 'TERMINATED','Terminated','Business permanently closed','system'
WHERE NOT EXISTS (SELECT 1 FROM master_business_status WHERE code = 'TERMINATED');

INSERT INTO master_business_status (code, name, description, created_by)
SELECT 'TRIAL','Trial','Business in trial mode','system'
WHERE NOT EXISTS (SELECT 1 FROM master_business_status WHERE code = 'TRIAL');


-- master_subscription_type
INSERT INTO master_subscription_type (code, name, description, max_branches, max_users, max_items, created_by)
SELECT 'TRIAL','Trial','Trial plan',1,1,20,'system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_type WHERE code = 'TRIAL');

INSERT INTO master_subscription_type (code, name, description, max_branches, max_users, max_items, created_by)
SELECT 'BASIC','Basic','Basic plan',1,5,100,'system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_type WHERE code = 'BASIC');

INSERT INTO master_subscription_type (code, name, description, max_branches, max_users, max_items, created_by)
SELECT 'STANDARD','Standard','Standard plan',3,10,500,'system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_type WHERE code = 'STANDARD');

INSERT INTO master_subscription_type (code, name, description, max_branches, max_users, max_items, created_by)
SELECT 'PREMIUM','Premium','Premium plan',5,50,2000,'system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_type WHERE code = 'PREMIUM');

INSERT INTO master_subscription_type (code, name, description, max_branches, max_users, max_items, created_by)
SELECT 'ENTERPRISE','Enterprise','Enterprise plan',10,200,10000,'system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_type WHERE code = 'ENTERPRISE');

INSERT INTO master_subscription_type (code, name, description, max_branches, max_users, max_items, created_by)
SELECT 'CUSTOM','Custom','Custom plan as per requirement',50,500,50000,'system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_type WHERE code = 'CUSTOM');


-- master_subscription_status
INSERT INTO master_subscription_status (code, name, description, created_by)
SELECT 'ACTIVE','Active','Subscription is active','system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_status WHERE code = 'ACTIVE');

INSERT INTO master_subscription_status (code, name, description, created_by)
SELECT 'INACTIVE','Inactive','Subscription is inactive','system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_status WHERE code = 'INACTIVE');

INSERT INTO master_subscription_status (code, name, description, created_by)
SELECT 'SUSPENDED','Suspended','Subscription temporarily disabled','system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_status WHERE code = 'SUSPENDED');

INSERT INTO master_subscription_status (code, name, description, created_by)
SELECT 'CANCELLED','Cancelled','Subscription cancelled by user','system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_status WHERE code = 'CANCELLED');

INSERT INTO master_subscription_status (code, name, description, created_by)
SELECT 'EXPIRED','Expired','Subscription expired','system'
WHERE NOT EXISTS (SELECT 1 FROM master_subscription_status WHERE code = 'EXPIRED');


-- master_billing_cycle
INSERT INTO master_billing_cycle (code, name, created_by)
SELECT 'MONTHLY','Monthly','system'
WHERE NOT EXISTS (SELECT 1 FROM master_billing_cycle WHERE code = 'MONTHLY');

INSERT INTO master_billing_cycle (code, name, created_by)
SELECT 'QUARTERLY','Quarterly','system'
WHERE NOT EXISTS (SELECT 1 FROM master_billing_cycle WHERE code = 'QUARTERLY');

INSERT INTO master_billing_cycle (code, name, created_by)
SELECT 'YEARLY','Yearly','system'
WHERE NOT EXISTS (SELECT 1 FROM master_billing_cycle WHERE code = 'YEARLY');

INSERT INTO master_billing_cycle (code, name, created_by)
SELECT 'LIFETIME','Lifetime','system'
WHERE NOT EXISTS (SELECT 1 FROM master_billing_cycle WHERE code = 'LIFETIME');


-- master_otp_type
INSERT INTO master_otp_type (code, name, created_by)
SELECT 'LOGIN','Login Verification','system'
WHERE NOT EXISTS (SELECT 1 FROM master_otp_type WHERE code = 'LOGIN');

INSERT INTO master_otp_type (code, name, created_by)
SELECT 'REGISTER','Register Verification','system'
WHERE NOT EXISTS (SELECT 1 FROM master_otp_type WHERE code = 'REGISTER');

INSERT INTO master_otp_type (code, name, created_by)
SELECT 'RESET_PASSWORD','Password Reset','system'
WHERE NOT EXISTS (SELECT 1 FROM master_otp_type WHERE code = 'RESET_PASSWORD');

INSERT INTO master_otp_type (code, name, created_by)
SELECT 'VERIFY_EMAIL','Email Verification','system'
WHERE NOT EXISTS (SELECT 1 FROM master_otp_type WHERE code = 'VERIFY_EMAIL');

INSERT INTO master_otp_type (code, name, created_by)
SELECT 'VERIFY_PHONE','Phone Verification','system'
WHERE NOT EXISTS (SELECT 1 FROM master_otp_type WHERE code = 'VERIFY_PHONE');

INSERT INTO master_otp_type (code, name, created_by)
SELECT 'TWO_FACTOR','Two Factor Authentication','system'
WHERE NOT EXISTS (SELECT 1 FROM master_otp_type WHERE code = 'TWO_FACTOR');
