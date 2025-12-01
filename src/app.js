const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const routes = require("./routes");
const errorHandler = require("./middlewares/error-handler.middleware");
const config = require("./config/env.config");
const {
  httpLogger,
  requestLogger,
  errorLogger,
  performanceLogger,
} = require("./middlewares/logger.middleware");

const app = express();

// Helmet sets various HTTP headers to protect against common vulnerabilities
app.use(helmet());

// CORS - Cross-Origin Resource Sharing configuration
app.use(
  cors({
    origin: config.nodeEnv === "production" ? "rentzfy.com" : "*",
    credentials: true,
  })
);

// Parse JSON request bodies (with size limit to prevent DoS)
app.use(express.json({ limit: "10mb" }));
// Parse URL-encoded bodies (form submissions)
app.use(express.urlencoded({ extended: true, limit: "10mb" }));

// Morgan-based HTTP logger for access logs
app.use(httpLogger);
// Detailed request logger with sanitized body logging
app.use(requestLogger);
// Performance tracking (response time metrics)
app.use(performanceLogger);

// All API routes are prefixed with /api
app.use("/api", routes);

// Logs errors 
app.use(errorLogger);

// Catches all errors and returns appropriate responses
app.use(errorHandler);

module.exports = app;
