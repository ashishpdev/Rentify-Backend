// Express app setup
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const routes = require("./routes");
const errorHandler = require("./middlewares/error-handler.middleware");
const config = require("./config/env.config");
// const setupSwagger = require("./config/swagger.config");
const {
  httpLogger,
  requestLogger,
  errorLogger,
  performanceLogger,
} = require("./middlewares/logger.middleware");

const app = express();

// Security middleware (with Swagger UI exception)
app.use(
  helmet({
    contentSecurityPolicy: false, // Disable CSP for Swagger UI
  })
);

// CORS configuration
app.use(
  cors({
    origin:
      config.nodeEnv === "production" ? "rentzfy.com" : "*",
    credentials: true,
  })
);

// Body parser middleware
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Logging middleware
app.use(httpLogger); // HTTP request/response logger
app.use(requestLogger); // Detailed request logger with context
app.use(performanceLogger); // Performance tracking

// API Documentation
// setupSwagger(app);

// API routes
app.use("/api", routes);

// Error logging middleware (before error handler)
app.use(errorLogger);

// Error handling middleware (must be last)
app.use(errorHandler);

module.exports = app;
