DROP TABLE IF EXISTS clothing_model_detail;
CREATE TABLE clothing_model_detail (
  clothing_model_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_model_id INT UNSIGNED NOT NULL UNIQUE,
  brand VARCHAR(200),
  gender ENUM('MEN','WOMEN','UNISEX','KIDS') DEFAULT 'UNISEX',
  material VARCHAR(200),
  season ENUM('SUMMER','WINTER','MONSOON','ALL_SEASON') DEFAULT 'ALL_SEASON',
  care_instructions TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_clothing_model_gender (gender, product_model_id),
  INDEX idx_clothing_model_season (season, product_model_id),
  
  CONSTRAINT fk_clothing_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

DROP TABLE IF EXISTS clothing_asset_detail;
CREATE TABLE clothing_asset_detail (
  clothing_asset_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  asset_id INT UNSIGNED NOT NULL UNIQUE,
  size VARCHAR(20) COMMENT 'S, M, L, XL, XXL, or numeric',
  color VARCHAR(50),
  tags VARCHAR(255) COMMENT 'Comma-separated tags',
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_clothing_asset_size (size, asset_id),
  INDEX idx_clothing_asset_color (color, asset_id),
  
  CONSTRAINT fk_clothing_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;