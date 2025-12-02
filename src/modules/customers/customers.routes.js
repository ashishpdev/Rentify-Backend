const express = require("express");
const CustomerController = require("./customers.controller");
const { requireBothTokens } = require("../../middlewares/token-validation.middleware");

const router = express.Router();

// Customer Routes
router.post("/create", requireBothTokens, CustomerController.createCustomer);
router.post("/update/:customerId", requireBothTokens, CustomerController.updateCustomer);
router.post("/get/:customerId", requireBothTokens, CustomerController.getCustomer);
router.post("/list", requireBothTokens, CustomerController.getAllCustomers);
router.post("/delete/:customerId", requireBothTokens, CustomerController.deleteCustomer);

module.exports = router;