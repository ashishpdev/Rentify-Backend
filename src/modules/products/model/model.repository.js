// src/modules/products/model/model.repository.js
const db = require("../../../database/connection");
const logger = require("../../../config/logger.config");

class ModelRepository {
  async manageProductModel(params) {
    try {
      const imagesJson = params.productModelImages
        ? JSON.stringify(params.productModelImages)
        : null;

      logger.info("ModelRepository.manageProductModel", {
        action: params.action,
        hasImages: !!params.productModelImages,
        imageCount: Array.isArray(params.productModelImages)
          ? params.productModelImages.length
          : 0,
        imagesJsonLength: imagesJson?.length || 0,
      });

      // Call stored procedure
      await db.executeSP(
        "CALL sp_manage_product_model(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, @p_success, @p_id, @p_data, @p_error_code, @p_error_message)",
        [
          params.action,
          params.productModelId,
          params.businessId,
          params.branchId,
          params.productSegmentId,
          params.productCategoryId,
          params.modelName,
          params.description,
          imagesJson,
          params.defaultRent,
          params.defaultDeposit,
          params.defaultSell,
          params.defaultWarrantyDays,
          params.userId,
          params.roleId,
        ]
      );

      // Fetch OUT vars
      const output = await db.executeSelect(
        "SELECT @p_success AS success, @p_id AS product_model_id, @p_data AS data, @p_error_code AS error_code, @p_error_message AS error_message"
      );

      const success =
        output && (output.success == 1 || output.success === true);

      let parsedData = null;
      if (output && output.data) {
        try {
          parsedData =
            typeof output.data === "string"
              ? JSON.parse(output.data)
              : output.data;
          
          // Handle nested JSON strings recursively
          parsedData = this._parseNestedJson(parsedData);
          
        } catch (err) {
          logger.warn("Failed to parse model p_data JSON", {
            err: err.message,
          });
          parsedData = output.data;
        }
      }

      if (!success) {
        logger.warn("sp_manage_product_model returned error", {
          action: params.action,
          errorCode: output ? output.error_code : null,
          errorMessage: output ? output.error_message : null,
        });
      }

      return {
        success,
        productModelId: output ? output.product_model_id : null,
        data: parsedData,
        errorCode: output ? output.error_code : null,
        message: output ? output.error_message : null,
      };
    } catch (err) {
      logger.error("ModelRepository.manageProductModel error", {
        error: err.message,
        action: params.action,
      });
      return {
        success: false,
        productModelId: null,
        data: null,
        errorCode: "ERR_DATABASE",
        message: err.message || "Database error",
      };
    }
  }

  /**
   * Recursively parse nested JSON strings in an object
   */
  _parseNestedJson(obj) {
    if (obj === null || obj === undefined) {
      return obj;
    }

    // If it's a string, try to parse it as JSON
    if (typeof obj === 'string') {
      // Check if it looks like JSON
      const trimmed = obj.trim();
      if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
        try {
          const parsed = JSON.parse(obj);
          // Recursively parse the result
          return this._parseNestedJson(parsed);
        } catch (e) {
          // Not valid JSON, return as-is
          return obj;
        }
      }
      return obj;
    }

    // If it's an array, parse each element
    if (Array.isArray(obj)) {
      return obj.map(item => this._parseNestedJson(item));
    }

    // If it's an object, parse each property
    if (typeof obj === 'object') {
      const result = {};
      for (const key in obj) {
        if (obj.hasOwnProperty(key)) {
          result[key] = this._parseNestedJson(obj[key]);
        }
      }
      return result;
    }

    // Primitive value, return as-is
    return obj;
  }
}

module.exports = new ModelRepository();