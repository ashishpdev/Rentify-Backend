// Combines all module routes
const express = require("express");
const authRoutes = require("../modules/auth/auth.routes");
const customersRoutes = require("../modules/customers/customers.routes");
const segmentRoutes = require("../modules/products/segment/segment.routes");
const categoryRoutes = require("../modules/products/category/category.routes");

const router = express.Router();

// Health check route
router.get("/health", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Server is running",
    timestamp: new Date().toISOString(),
  });
});

// Root route
router.get("/", (req, res) => {
  res.status(200).json({
    success: true,
    message: "Welcome to Rentify API",
    version: "1.0.0",
    endpoints: {
      health: "/api/health",
      auth: "/api/auth",
      docs: "/docs",
    },
  });
});

// Module routes
router.use("/auth", authRoutes);
router.use("/customer", customersRoutes);
router.use("/segment", segmentRoutes);
router.use("/category", categoryRoutes);

// 404 handler - changed from "*" to catch-all middleware
router.use((req, res) => {
  res.status(404).json({
    success: false,
    message: "Route not found",
  });
});

module.exports = router;
