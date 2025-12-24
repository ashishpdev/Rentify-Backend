DROP TABLE IF EXISTS vehicle_model_detail;
CREATE TABLE vehicle_model_detail (
  vehicle_model_detail_id INT AUTO_INCREMENT PRIMARY KEY,
  product_model_id INT NOT NULL UNIQUE,
  fuel_type ENUM('PETROL','DIESEL','EV','HYBRID'),
  transmission ENUM('MANUAL','AUTOMATIC'),
  seating_capacity INT,
  manufacturer_year INT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_vehicle_model FOREIGN KEY (product_model_id) REFERENCES product_model(product_model_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS vehicle_asset_detail;
CREATE TABLE vehicle_asset_detail (
  vehicle_asset_detail_id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL UNIQUE,
  registration_no VARCHAR(100),
  engine_no VARCHAR(255),
  chassis_no VARCHAR(255),
  insurance_expiry DATE,
  pollution_cert_expiry DATE,
  last_service_km INT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_vehicle_asset FOREIGN KEY (asset_id) REFERENCES asset(asset_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
