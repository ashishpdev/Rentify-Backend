DROP TABLE IF EXISTS clothing_model_detail;
CREATE TABLE clothing_model_detail (
  clothing_model_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_model_id INT UNSIGNED NOT NULL UNIQUE,
  brand VARCHAR(200),
  gender_id TINYINT UNSIGNED NOT NULL,
  material VARCHAR(200),
  clothing_season_id TINYINT UNSIGNED NOT NULL,
  care_instructions TEXT,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  
  INDEX idx_clothing_model_gender (gender_id, product_model_id),
  INDEX idx_clothing_model_season (clothing_season_id, product_model_id),
  
  CONSTRAINT fk_clothing_model FOREIGN KEY (product_model_id)
    REFERENCES product_model(product_model_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_clothing_season FOREIGN KEY (clothing_season_id)
    REFERENCES clothing_season(clothing_season_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_clothing_gender FOREIGN KEY (gender_id)
    REFERENCES master_gender(master_gender_id)
    ON DELETE RESTRICT ON UPDATE CASCADE

) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;

DROP TABLE IF EXISTS clothing_asset_detail;
CREATE TABLE clothing_asset_detail (
  clothing_asset_detail_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  asset_id INT UNSIGNED NOT NULL UNIQUE,
  clothing_size_id TINYINT UNSIGNED NOT NULL,
  clothing_colour_id TINYINT UNSIGNED NOT NULL,
  tags VARCHAR(255) COMMENT 'Comma-separated tags',
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),

  INDEX idx_clothing_asset_size (clothing_size_id, asset_id),
  INDEX idx_clothing_asset_color (clothing_colour, asset_id),
  
  CONSTRAINT fk_clothing_asset FOREIGN KEY (asset_id)
    REFERENCES asset(asset_id)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_clothing_size FOREIGN KEY (clothing_size_id)
    REFERENCES clothing_size(clothing_size_id)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_clothing_colour FOREIGN KEY (clothing_colour_id)
    REFERENCES clothing_colour(clothing_colour_id)
    ON DELETE RESTRICT ON UPDATE CASCADE

) ENGINE=InnoDB ROW_FORMAT=COMPRESSED;