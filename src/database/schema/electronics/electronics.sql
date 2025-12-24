DROP TABLE IF EXISTS electronics_model_spec;
CREATE TABLE electronics_model_spec (
  electronics_model_spec_id INT AUTO_INCREMENT PRIMARY KEY,
  product_model_id INT NOT NULL UNIQUE, -- 1:1
  brand VARCHAR(255),
  cpu VARCHAR(255),
  ram_gb INT,
  storage_gb INT,
  battery_wh INT,
  power_adapter_required TINYINT(1) DEFAULT 0,
  screen_size_inch DECIMAL(5,2),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_elec_model FOREIGN KEY (product_model_id) REFERENCES product_model(product_model_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS electronics_asset_detail;
CREATE TABLE electronics_asset_detail (
  electronics_asset_detail_id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL UNIQUE, -- 1:1
  imei_1 VARCHAR(100),
  imei_2 VARCHAR(100),
  mac_address VARCHAR(100),
  warranty_expiry DATE,
  accessory_list TEXT, -- comma/list of serials of chargers, cables etc.
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_elec_asset FOREIGN KEY (asset_id) REFERENCES asset(asset_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
