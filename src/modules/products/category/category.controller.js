// src/modules/products/category/category.controller.js
const ResponseUtil = require("../../../utils/response.util");
const logger = require("../../../config/logger.config");
const { CategoryValidator } = require("./category.validator");
const categoryService = require("./category.service");

class CategoryController {
  // ======================== CREATE CATEGORY ========================
  async createCategory(req, res, next) {
    try {
      const { error, value } = CategoryValidator.validateCreateCategory(
        req.body
      );
      if (error) {
        logger.warn("Category creation validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await categoryService.createCategory(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.created(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "createCategory" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to create category"
      );
    }
  }

  // ======================== UPDATE CATEGORY ========================
  async updateCategory(req, res, next) {
    try {
      const { error, value } = CategoryValidator.validateUpdateCategory(
        req.body
      );
      if (error) {
        logger.warn("Category update validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await categoryService.updateCategory(value, userData);

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "updateCategory" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to update category"
      );
    }
  }

  // ======================== GET CATEGORY ========================
  async getCategory(req, res, next) {
    try {
      const { error, value } = CategoryValidator.validateGetCategory(req.body);
      if (error) {
        logger.warn("Get category validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await categoryService.getCategory(
        value.product_category_id,
        userData
      );

      if (!result.success) {
        return ResponseUtil.notFound(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "getCategory" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to get category"
      );
    }
  }

  // ======================== LIST CATEGORIES ========================
  async listCategories(req, res, next) {
    try {
      const { error, value } = CategoryValidator.validateListCategories(
        req.body
      );
      if (error) {
        logger.warn("List categories validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const paginationParams = {
        page: value.page,
        limit: value.limit,
      };
      const result = await categoryService.listCategories(
        userData,
        paginationParams
      );

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "listCategories" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to list categories"
      );
    }
  }

  // ======================== DELETE CATEGORY ========================
  async deleteCategory(req, res, next) {
    try {
      const { error, value } = CategoryValidator.validateDeleteCategory(
        req.body
      );
      if (error) {
        logger.warn("Delete category validation failed", {
          error: error.details[0].message,
        });
        return ResponseUtil.badRequest(res, error.details[0].message);
      }

      const userData = req.user;
      const result = await categoryService.deleteCategory(
        value.product_category_id,
        userData
      );

      if (!result.success) {
        return ResponseUtil.badRequest(res, result.message);
      }

      return ResponseUtil.success(res, result.data, result.message);
    } catch (error) {
      logger.logError(error, req, { operation: "deleteCategory" });
      return ResponseUtil.serverError(
        res,
        error.message || "Failed to delete category"
      );
    }
  }
}

module.exports = new CategoryController();
