const logger = require("../config/logger.config");
const morgan = require("morgan");

/**
 * HTTP Request Logger Middleware using Morgan + Winston
 */
const httpLogger = morgan(
  ":method :url :status :res[content-length] - :response-time ms",
  {
    stream: logger.stream,
    skip: (req, res) => {
      // Skip logging for health checks in production
      return req.url === "/api/health" && process.env.NODE_ENV === "production";
    },
  }
);

/**
 * Request Context Logger Middleware
 * Logs detailed request information with timing
 */
const requestLogger = (req, res, next) => {
  const startTime = Date.now();

  // Log incoming request
  logger.logRequest(req, {
    headers: {
      "content-type": req.get("content-type"),
      "user-agent": req.get("user-agent"),
    },
    query: req.query,
    body: req.body ? sanitizeBody(req.body) : undefined,
  });

  // Override res.json to log response
  const originalJson = res.json.bind(res);
  res.json = function (data) {
    const responseTime = Date.now() - startTime;

    logger.logResponse(req, res, {
      responseTime,
      dataSize: JSON.stringify(data).length,
    });

    return originalJson(data);
  };

  // Handle response finish
  res.on("finish", () => {
    const responseTime = Date.now() - startTime;

    // Log slow requests (> 1000ms)
    if (responseTime > 1000) {
      logger.warn("Slow Request Detected", {
        method: req.method,
        url: req.originalUrl,
        responseTime: `${responseTime}ms`,
        statusCode: res.statusCode,
      });
    }
  });

  next();
};

/**
 * Sanitize sensitive data from request body
 */
function sanitizeBody(body) {
  const sensitiveFields = [
    "password",
    "token",
    "apiKey",
    "secret",
    "creditCard",
  ];
  const sanitized = { ...body };

  sensitiveFields.forEach((field) => {
    if (sanitized[field]) {
      sanitized[field] = "***REDACTED***";
    }
  });

  return sanitized;
}

/**
 * Error Logger Middleware
 * Should be placed before error handler
 */
const errorLogger = (err, req, res, next) => {
  logger.logError(err, req, {
    timestamp: new Date().toISOString(),
  });

  next(err);
};

/**
 * Performance Logger Middleware
 * Tracks request duration and logs performance metrics
 */
const performanceLogger = (req, res, next) => {
  const startTime = process.hrtime();

  res.on("finish", () => {
    const [seconds, nanoseconds] = process.hrtime(startTime);
    const duration = seconds * 1000 + nanoseconds / 1000000; // Convert to milliseconds

    logger.logPerformance(
      `${req.method} ${req.originalUrl}`,
      duration.toFixed(2),
      {
        statusCode: res.statusCode,
        userId: req.user?.id,
        businessId: req.business?.id,
      }
    );
  });

  next();
};

/**
 * API Version Logger
 * Logs which API version is being used
 */
const apiVersionLogger = (req, res, next) => {
  const apiVersion = req.baseUrl || "v1";
  req.apiVersion = apiVersion;
  next();
};

module.exports = {
  httpLogger,
  requestLogger,
  errorLogger,
  performanceLogger,
  apiVersionLogger,
};
