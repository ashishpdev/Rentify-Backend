
-- PHASE 2 
-- ========================================================
-- Vendor rental order (header)
-- ========================================================
DROP TABLE IF EXISTS vendor_rental_order;
CREATE TABLE vendor_rental_order (
    vendor_rental_order_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    business_id INT NOT NULL,
    branch_id INT NOT NULL,

    vendor_name VARCHAR(255) NOT NULL,
    vendor_contact_name VARCHAR(255),
    vendor_contact_phone VARCHAR(80),
    vendor_contact_email VARCHAR(255),
    vendor_address VARCHAR(1024),
    vendor_reference_no VARCHAR(255), -- vendor's invoice or reference number

    order_date TIMESTAMP(6) NOT NULL,
    expected_return_date TIMESTAMP(6) NULL,
    actual_return_date TIMESTAMP(6) NULL,

    currency VARCHAR(16) DEFAULT 'INR',
    subtotal_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(14,2) NOT NULL DEFAULT 0,

    rental_status_id INT NULL,
    notes TEXT,

    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0,

    INDEX idx_vendor_rental_business (business_id),
    INDEX idx_vendor_rental_branch (branch_id),
    INDEX idx_vendor_rental_vendor_ref (vendor_reference_no),
    INDEX idx_vendor_rental_dates (order_date, expected_return_date),

    CONSTRAINT fk_vendor_rental_business FOREIGN KEY (business_id)
        REFERENCES master_business(business_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_vendor_rental_branch FOREIGN KEY (branch_id)
        REFERENCES master_branch(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_vendor_rental_status FOREIGN KEY (rental_status_id)
        REFERENCES product_rental_status(product_rental_status_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- PHASE 2
-- ========================================================
-- Asset procurement detail (line / unit detail) -- one-to-one with asset
-- ========================================================
DROP TABLE IF EXISTS asset_procurement_detail;
CREATE TABLE asset_procurement_detail (
    asset_procurement_detail_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    business_id INT NOT NULL,
    branch_id INT NOT NULL,
    vendor_rental_order_id INT NOT NULL,
    asset_id INT NOT NULL,
    daily_rate DECIMAL(10,2) NULL,     -- rental rate charged by vendor (if applicable)
    received_condition_id INT NULL,    -- FK -> product_condition
    notes TEXT,

    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_by VARCHAR(255),
    updated_at TIMESTAMP(6) NULL DEFAULT NULL ON UPDATE CURRENT_TIMESTAMP(6),
    deleted_at TIMESTAMP(6) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted TINYINT(1) DEFAULT 0,

    CONSTRAINT chk_asset_procurement_images_json CHECK (JSON_VALID(received_images)),
    INDEX idx_asset_procurement_vendor_order (vendor_rental_order_id),
    INDEX idx_asset_procurement_asset (asset_id),
    INDEX idx_asset_procurement_business (business_id),

    CONSTRAINT fk_asset_procurement_vendor_order FOREIGN KEY (vendor_rental_order_id)
        REFERENCES vendor_rental_order(vendor_rental_order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,

    CONSTRAINT fk_asset_procurement_asset FOREIGN KEY (asset_id)
        REFERENCES asset(asset_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_asset_procurement_received_condition FOREIGN KEY (received_condition_id)
        REFERENCES product_condition(product_condition_id)
        ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT fk_asset_procurement_business FOREIGN KEY (business_id)
        REFERENCES master_business(business_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    CONSTRAINT fk_asset_procurement_branch FOREIGN KEY (branch_id)
        REFERENCES master_branch(branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
