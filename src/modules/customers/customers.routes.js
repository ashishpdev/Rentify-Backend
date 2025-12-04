const express = require("express");
const CustomerController = require("./customers.controller");
const { requireBothTokens } = require("../../middlewares/token-validation.middleware");

const router = express.Router();

// Customer Routes - All data from request body
router.post("/create", requireBothTokens, CustomerController.createCustomer);
router.post("/update", requireBothTokens, CustomerController.updateCustomer);
router.post("/get", requireBothTokens, CustomerController.getCustomer);
router.post("/list", requireBothTokens, CustomerController.listCustomers);
router.post("/delete", requireBothTokens, CustomerController.deleteCustomer);

module.exports = router;