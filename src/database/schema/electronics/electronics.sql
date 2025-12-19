DROP TABLE IF EXISTS electronics_model_spec;
CREATE TABLE electronics_model_spec (
  electronics_model_spec_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_model_id INT UNSIGNED NOT NULL UNIQUE,
  brand VARCHAR(200),
  cpu VARCHAR(200),
  ram_gb SMALLINT UNSIGNED,
  storage_gb SMALLINT UNSIGNED,
  battery_wh SMALLINT UNSIGNED COMMENT 'Battery capacity in watt-hours',
  power_adapter_required BOOLEAN DEFAULT FALSE,
  screen_size_inch DECIMAL(5,2) UNSIGNED,
  resolution VARCHAR(50) COMMENT 'e.g., 1920x1080',
  operating_system VARCHAR(100),
  warranty_months TINYINT UNSIGNED,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_elec_model_brand (brand, product_model_id),
  INDEX idx_elec_model_ram (ram_gb, storage_gb, product_model_id),
  
  CONSTRAINT fk_elec_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

DROP TABLE IF EXISTS electronics_asset_detail;
CREATE TABLE electronics_asset_detail (
  electronics_asset_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  asset_id INT UNSIGNED NOT NULL UNIQUE,
  imei_1 VARCHAR(20),
  imei_2 VARCHAR(20),
  mac_address VARCHAR(20),
  warranty_expiry DATE,
  accessory_list TEXT COMMENT 'JSON array of accessories',
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_elec_asset_imei (imei_1, imei_2),
  INDEX idx_elec_asset_warranty (warranty_expiry),
  
  CONSTRAINT fk_elec_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;




-- =========================================================
DROP TABLE IF EXISTS electronics_location_history;
CREATE TABLE electronics_location_history (
  electronics_location_history_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  business_id INT UNSIGNED NOT NULL,
  branch_id INT UNSIGNED NOT NULL,
  asset_id INT UNSIGNED NOT NULL,
  -- Remove this ENUM from filed definitions and put in ENUM table 
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

