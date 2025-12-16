DROP TABLE IF EXISTS clothing_model_detail;
CREATE TABLE clothing_model_detail (
  clothing_model_detail_id INT AUTO_INCREMENT PRIMARY KEY,
  product_model_id INT NOT NULL UNIQUE,
  brand VARCHAR(255),
  gender ENUM('MEN','WOMEN','UNISEX') DEFAULT 'UNISEX',
  material VARCHAR(255),
  season VARCHAR(64),
  care_instructions TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_clothing_model FOREIGN KEY (product_model_id) REFERENCES product_model(product_model_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

DROP TABLE IF EXISTS clothing_asset_detail;
CREATE TABLE clothing_asset_detail (
  clothing_asset_detail_id INT AUTO_INCREMENT PRIMARY KEY,
  asset_id INT NOT NULL UNIQUE,
  size VARCHAR(32), -- S, M, L, XL or numeric
  color VARCHAR(64),
  tags VARCHAR(255),
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_clothing_asset FOREIGN KEY (asset_id) REFERENCES asset(asset_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;
