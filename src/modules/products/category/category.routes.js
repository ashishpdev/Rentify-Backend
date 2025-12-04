const express = require("express");
const CategoryController = require("./category.controller");
const {
  requireBothTokens,
} = require("../../../middlewares/token-validation.middleware");

const router = express.Router();

// Category Routes - All data from request body
router.post("/create", requireBothTokens, CategoryController.createCategory);
router.post("/update", requireBothTokens, CategoryController.updateCategory);
router.post("/get", requireBothTokens, CategoryController.getCategory);
router.post("/list", requireBothTokens, CategoryController.listCategories);
router.post("/delete", requireBothTokens, CategoryController.deleteCategory);

module.exports = router;
