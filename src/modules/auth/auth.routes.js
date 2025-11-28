// Authentication routes
const express = require("express");
const authController = require("./auth.controller");
const AccessTokenHeaderMiddleware = require("../../middlewares/access-token-header.middleware");
const SessionValidatorHeader = require("../../middlewares/session-validator-header.middleware");
const { asyncHandler } = require("../../utils/async-handler.util");

const router = express.Router();

// Public routes for OTP and registration flow
router.post("/send-otp", asyncHandler(authController.sendOTP));
router.post("/verify-otp", asyncHandler(authController.verifyOTP));
router.post("/login", asyncHandler(authController.loginWithOTP));
router.post("/complete-registration", asyncHandler(authController.completeRegistration));

// Decrypt access token - requires X-Access-Token header (mandatory)
router.post(
  "/decrypt-token",
  AccessTokenHeaderMiddleware.requireAccessTokenHeader,
  asyncHandler(authController.decryptUserData)
);

/**
 * Extend session expiry
 * Requires x-access-token and x-session-token headers
 * Updates session expiry_at to 1 hour from now
 * Returns new session_expires_at
 */
router.post("/extend-session", asyncHandler(authController.extendSession));

/**
 * Logout route
 * Requires x-access-token header only
 * Decrypts the access token to get user_id and removes the session entry via stored procedure
 */
router.post("/logout", asyncHandler(authController.logout));

module.exports = router;
