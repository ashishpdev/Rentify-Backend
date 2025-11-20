// Authentication routes
const express = require("express");
const authController = require("./auth.controller");

const router = express.Router();

// Public routes
router.post("/signup", authController.signup);
router.post("/login", authController.login);
router.post("/logout", authController.logout);

// Protected routes (require authentication)
router.get("/me", authController.getCurrentUser);

module.exports = router;