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