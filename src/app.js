// Express app setup
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const routes = require("./routes");
const errorHandler = require("./middlewares/error-handler.middleware");
const config = require("./config/env.config");
const setupSwagger = require("./config/swagger.config");

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
      config.nodeEnv === "production" ? "your-production-domain.com" : "*",
    credentials: true,
  })
);

// Body parser middleware
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// HTTP request logger
if (config.nodeEnv === "development") {
  app.use(morgan("dev"));
}

// API Documentation
setupSwagger(app);

// API routes
app.use("/api", routes);

// Error handling middleware (must be last)
app.use(errorHandler);

module.exports = app;
