const express = require("express");
const CustomerController = require("./customers.controller");
const AccessTokenHeaderMiddleware = require("../../middlewares/access-token-header.middleware");
const router = express.Router();

// Customer Routes
router.post("/create",AccessTokenHeaderMiddleware.requireAccessTokenHeader, CustomerController.createCustomer);
// router.get("/list", getCustomerList);
// router.get("/details/:customerId", getCustomerDetails);
// router.post("/update/:customerId", updateCustomer);
// router.delete("/delete/:customerId", deleteCustomer);


module.exports = router;