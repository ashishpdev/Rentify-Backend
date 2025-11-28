// Authentication routes
const express = require("express");
const authController = require("./auth.controller");
const AccessTokenHeaderMiddleware = require("../../middlewares/access-token-header.middleware");

const router = express.Router();

// Public routes for OTP and registration flow
router.post("/send-otp", authController.sendOTP);
router.post("/verify-otp", authController.verifyOTP);
router.post("/login", authController.loginWithOTP);
router.post("/complete-registration", authController.completeRegistration);

// Decrypt access token - requires X-Access-Token header (mandatory)
router.post(
  "/decrypt-token",
  AccessTokenHeaderMiddleware.requireAccessTokenHeader,
  authController.decryptUserData
);

module.exports = router;
