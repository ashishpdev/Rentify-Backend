const express = require("express");
const CustomerController = require("./customers.controller");
const {
    requireBothTokens,
    requireAccessToken,
} = require("../../middlewares/token-validation.middleware");
const router = express.Router();

// Customer Routes
router.post("/create", requireAccessToken, CustomerController.createCustomer);
// router.get("/list", getCustomerList);    
// router.get("/details/:customerId", getCustomerDetails);
// router.post("/update/:customerId", updateCustomer);
// router.delete("/delete/:customerId", deleteCustomer);


module.exports = router;