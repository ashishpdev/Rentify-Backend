DROP TABLE IF EXISTS vehicle_model_detail;
CREATE TABLE vehicle_model_detail (
  vehicle_model_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_model_id INT UNSIGNED NOT NULL UNIQUE,
  fuel_type ENUM('PETROL','DIESEL','EV','HYBRID','CNG','LPG') NOT NULL,
  transmission ENUM('MANUAL','AUTOMATIC','CVT','DCT') NOT NULL,
  seating_capacity TINYINT UNSIGNED NOT NULL,
  manufacturer_year SMALLINT UNSIGNED,
  engine_cc SMALLINT UNSIGNED COMMENT 'Engine displacement in cc',
  mileage_kmpl DECIMAL(5,2) UNSIGNED COMMENT 'Fuel efficiency',
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_vehicle_model_fuel (fuel_type, product_model_id),
  INDEX idx_vehicle_model_seats (seating_capacity, product_model_id),
  
  CONSTRAINT fk_vehicle_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

DROP TABLE IF EXISTS vehicle_asset_detail;
CREATE TABLE vehicle_asset_detail (
  vehicle_asset_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  asset_id INT UNSIGNED NOT NULL UNIQUE,
  registration_no VARCHAR(20) UNIQUE,
  engine_no VARCHAR(100),
  chassis_no VARCHAR(100) UNIQUE,
  insurance_expiry DATE,
  pollution_cert_expiry DATE,
  last_service_km INT UNSIGNED,
  current_odometer_km INT UNSIGNED,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_vehicle_asset_reg (registration_no),
  INDEX idx_vehicle_asset_insurance (insurance_expiry),
  INDEX idx_vehicle_asset_pollution (pollution_cert_expiry),
  
  CONSTRAINT fk_vehicle_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;