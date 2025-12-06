const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const routes = require('./routes');
const errorHandler = require('./middlewares/error-handler.middleware');
const config = require('./config/env.config');
const {
  httpLogger,
  requestLogger,
  errorLogger,
  performanceLogger,
} = require('./middlewares/logger.middleware');
const cookieParser = require('cookie-parser');

const app = express();

// Helmet sets various HTTP headers to protect against common vulnerabilities
app.use(helmet());

// CORS - Cross-Origin Resource Sharing configuration
app.use(
  cors({
    origin:
      config.nodeEnv === 'production'
        ? process.env.API_URL || 'https://rentzfy.com'
        : process.env.API_URL || 'http://localhost:3000',
    credentials: true, // Allow cookies to be sent
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }),
);

// Parse JSON request bodies (with size limit to prevent DoS)
app.use(express.json({ limit: '10mb' }));
// Parse URL-encoded bodies (form submissions)
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use(cookieParser());

// Morgan-based HTTP logger for access logs
app.use(httpLogger);
// Detailed request logger with sanitized body logging
app.use(requestLogger);
// Performance tracking (response time metrics)
app.use(performanceLogger);

// All API routes are prefixed with /api
app.use('/api', routes);

// Logs errors
app.use(errorLogger);

// Catches all errors and returns appropriate responses
app.use(errorHandler);

module.exports = app;
