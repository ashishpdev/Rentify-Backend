DROP TABLE IF EXISTS tool_model_spec;
CREATE TABLE tool_model_spec (
  tool_model_spec_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_model_id INT UNSIGNED NOT NULL UNIQUE,
  -- Remove this ENUM from filed definitions and put in ENUM table
  power_source ENUM('ELECTRIC','BATTERY','MANUAL','PNEUMATIC','HYDRAULIC') NOT NULL,
  rated_power_watts SMALLINT UNSIGNED,
  weight_kg DECIMAL(6,2) UNSIGNED,
  voltage TINYINT UNSIGNED COMMENT 'Operating voltage',
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_tool_model_power (power_source, product_model_id),
  
  CONSTRAINT fk_tool_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

DROP TABLE IF EXISTS tool_asset_detail;
CREATE TABLE tool_asset_detail (
  tool_asset_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  asset_id INT UNSIGNED NOT NULL UNIQUE,
  serial_tool_no VARCHAR(100),
  calibration_date DATE,
  next_calibration_due DATE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_tool_asset_calibration (next_calibration_due),
  
  CONSTRAINT fk_tool_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;