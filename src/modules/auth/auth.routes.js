// src/modules/auth/auth.routes.js
// HTTP routing configuration
const express = require("express");
const authController = require("./auth.controller");
const {
  requireAccessToken,
  requireSessionToken,
} = require("../../middlewares/token-validation.middleware");

const router = express.Router();

// ========================= PUBLIC ROUTES (No Auth Required) =========================
router.post("/send-otp", authController.sendOTP);

router.post("/verify-otp", authController.verifyOTP);

router.post("/complete-registration", authController.completeRegistration);

router.post("/login/otp", authController.loginWithOTP);

router.post("/login/password", authController.loginWithPassword);

router.post("/reset-password", authController.resetPassword);

// ========================= PROTECTED ROUTES (Auth Required) =========================

router.post(
  "/change-password",
  requireAccessToken,
  authController.changePassword
);

router.post(
  "/decrypt-token",
  requireAccessToken,
  authController.decryptUserData
);

router.post(
  "/refresh-tokens",
  requireSessionToken,
  authController.refreshTokens
);

router.post("/logout", requireAccessToken, authController.logout);

// ========================= HEALTH CHECK ROUTE =========================

router.get("/health", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Auth module is healthy",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

module.exports = router;
