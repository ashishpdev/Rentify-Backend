const express = require("express");
const authController = require("./auth.controller");
const {
  requireBothTokens,
  requireAccessToken,
} = require("../../middlewares/token-validation.middleware");

const router = express.Router();

router.post("/send-otp", authController.sendOTP);
router.post("/verify-otp", authController.verifyOTP);
router.post("/login", authController.loginWithOTP);
router.post("/complete-registration", authController.completeRegistration);
router.post("/decrypt-token", requireAccessToken, authController.decryptUserData);
router.post("/extend-session", requireBothTokens, authController.extendSession);
router.post("/logout", requireAccessToken, authController.logout);

module.exports = router;
