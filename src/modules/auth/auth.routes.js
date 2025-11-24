// Authentication routes
const express = require("express");
const authController = require("./auth.controller");

const router = express.Router();

// Public routes for OTP and registration flow
router.post("/send-otp", authController.sendOTP);
router.post("/verify-otp", authController.verifyOTP);
router.post("/complete-registration", authController.completeRegistration);

// Legacy routes
// router.post("/signup", authController.signup);
// router.post("/login", authController.login);
// router.post("/logout", authController.logout);

// Protected routes (require authentication)
// router.get("/me", authController.getCurrentUser);

module.exports = router;
