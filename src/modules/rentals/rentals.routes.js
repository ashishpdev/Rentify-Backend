// src/modules/rentals/rentals.routes.js
const express = require("express");
const RentalController = require("./rentals.controller");
const {
  requireBothTokens,
} = require("../../middlewares/token-validation.middleware");

const router = express.Router();

router.post("/issue", requireBothTokens, RentalController.issueRental);
router.post("/get", requireBothTokens, RentalController.getRental);
router.post("/list", requireBothTokens, RentalController.listRentals);
router.post("/update", requireBothTokens, RentalController.updateRental);
router.post("/return", requireBothTokens, RentalController.returnRental);

// TODO: Implement rental payment routes in future
// router.post(
//   "/record-payment",
//   requireBothTokens,
//   RentalController.recordPayment
// );
// router.post(
//   "/get-payments",
//   requireBothTokens,
//   RentalController.getRentalPayments
// );

module.exports = router;
