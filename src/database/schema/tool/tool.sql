DROP TABLE IF EXISTS tool_model_spec;
CREATE TABLE tool_model_spec (
  tool_model_spec_id INT AUTO_INCREMENT PRIMARY KEY,
  product_model_id INT NOT NULL UNIQUE,
  power_source ENUM('ELECTRIC','BATTERY','MANUAL'),
  rated_power_watts INT,
  weight_kg DECIMAL(6,2),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_tool_model FOREIGN KEY (product_model_id) REFERENCES product_model(product_model_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS tool_asset_detail;
CREATE TABLE tool_asset_detail (
  tool_asset_detail_id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL UNIQUE,
  serial_tool_no VARCHAR(255),
  calibration_date DATE,
  next_calibration_due DATE,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_tool_asset FOREIGN KEY (asset_id) REFERENCES asset(asset_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
