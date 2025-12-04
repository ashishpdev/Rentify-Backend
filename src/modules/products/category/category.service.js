// src/modules/products/category/category.service.js
const categoryRepository = require("./category.repository");
const logger = require("../../../config/logger.config");

class CategoryService {
  // ======================== CREATE CATEGORY ========================
  async createCategory(categoryData, userData) {
    try {
      const result = await categoryRepository.manageProductCategory({
        action: 1, // Create
        productCategoryId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: categoryData.product_segment_id,
        code: categoryData.code,
        name: categoryData.name,
        description: categoryData.description || null,
        user: userData.user_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success
          ? { product_category_id: result.productCategoryId }
          : null,
      };
    } catch (error) {
      logger.error("CategoryService.createCategory error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== UPDATE CATEGORY ========================
  async updateCategory(categoryData, userData) {
    try {
      const result = await categoryRepository.manageProductCategory({
        action: 2, // Update
        productCategoryId: categoryData.product_category_id,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: categoryData.product_segment_id,
        code: categoryData.code,
        name: categoryData.name,
        description: categoryData.description || null,
        user: userData.user_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success
          ? { product_category_id: categoryData.product_category_id }
          : null,
      };
    } catch (error) {
      logger.error("CategoryService.updateCategory error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== GET CATEGORY ========================
  async getCategory(productCategoryId, userData) {
    try {
      const result = await categoryRepository.manageProductCategory({
        action: 4, // Get Single
        productCategoryId: productCategoryId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        code: null,
        name: null,
        description: null,
        user: userData.user_id,
      });

      if (!result.success || !result.data) {
        return {
          success: false,
          message: "Product category not found",
          data: null,
        };
      }

      return {
        success: true,
        message: "Product category retrieved successfully",
        data: { category: result.data },
      };
    } catch (error) {
      logger.error("CategoryService.getCategory error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== LIST CATEGORIES ========================
  async listCategories(userData, paginationParams = {}) {
    try {
      const result = await categoryRepository.manageProductCategory({
        action: 5, // Get List
        productCategoryId: null,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        code: null,
        name: null,
        description: null,
        user: userData.user_id,
      });

      // Apply pagination on the result
      const allCategories = result.data || [];
      const total = allCategories.length;
      const page = paginationParams.page || 1;
      const limit = paginationParams.limit || 50;
      const totalPages = Math.ceil(total / limit);
      const startIndex = (page - 1) * limit;
      const endIndex = startIndex + limit;
      const paginatedCategories = allCategories.slice(startIndex, endIndex);

      return {
        success: result.success,
        message: result.message,
        data: {
          categories: paginatedCategories,
          pagination: {
            page: page,
            limit: limit,
            total: total,
            total_pages: totalPages,
            has_next: page < totalPages,
            has_prev: page > 1,
          },
        },
      };
    } catch (error) {
      logger.error("CategoryService.listCategories error", {
        error: error.message,
      });
      throw error;
    }
  }

  // ======================== DELETE CATEGORY ========================
  async deleteCategory(productCategoryId, userData) {
    try {
      const result = await categoryRepository.manageProductCategory({
        action: 3, // Delete
        productCategoryId: productCategoryId,
        businessId: userData.business_id,
        branchId: userData.branch_id,
        productSegmentId: null,
        code: null,
        name: null,
        description: null,
        user: userData.user_id,
      });

      return {
        success: result.success,
        message: result.message,
        data: result.success
          ? { product_category_id: productCategoryId }
          : null,
      };
    } catch (error) {
      logger.error("CategoryService.deleteCategory error", {
        error: error.message,
      });
      throw error;
    }
  }
}

module.exports = new CategoryService();
