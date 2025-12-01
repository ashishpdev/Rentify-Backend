const logger = require("../config/logger.config");
const morgan = require("morgan");

const httpLogger = morgan(
  ":method :url :status :res[content-length] - :response-time ms",
  {
    stream: logger.stream,
    skip: (req, res) => {
      return req.url === "/api/health" && process.env.NODE_ENV === "production";
    },
  }
);

const requestLogger = (req, res, next) => {
  const startTime = Date.now();

  try {
    logger.logRequest(req, {
      headers: {
        "content-type": req.get("content-type"),
        "user-agent": req.get("user-agent"),
      },
      query: req.query,
      body: req.body ? sanitizeBody(req.body) : undefined,
    });

    // Capture and log response
    const originalJson = res.json.bind(res);
    res.json = function (data) {
      const responseTime = Date.now() - startTime;

      logger.logResponse(req, res, {
        responseTime,
        dataSize: JSON.stringify(data).length,
      });

      return originalJson(data);
    };

    // Log slow requests as warnings
    res.on("finish", () => {
      const responseTime = Date.now() - startTime;

      if (responseTime > 1000) {
        logger.warn("Slow request detected", {
          method: req.method,
          url: req.originalUrl,
          responseTime: `${responseTime}ms`,
          statusCode: res.statusCode,
          userId: req.user?.id,
        });
      }
    });

    next();
  } catch (error) {
    logger.error("Error in request logger", {
      error: error.message,
      path: req.path,
    });
    next(error);
  }
};

// Set of sensitive field names (lowercase for case-insensitive matching)
const SENSITIVE_FIELDS = new Set([
  "password",
  "token",
  "apikey",
  "api_key",
  "accesstoken",
  "access_token",
  "refreshtoken",
  "refresh_token",
  "secret",
  "secretkey",
  "secret_key",
  "creditcard",
  "credit_card",
  "cardnumber",
  "card_number",
  "cvv",
  "cvc",
  "ssn",
  "socialsecurity",
  "social_security",
  "pin",
  "otp",
  "authorization",
  "auth",
  "privatekey",
  "private_key",
]);

/**
 * Deep sanitize an object by recursively redacting sensitive fields.
 * Handles nested objects and arrays.
 * @param {any} obj - The object to sanitize
 * @param {Set<string>} sensitiveFields - Set of lowercase field names to redact
 * @param {number} maxDepth - Maximum recursion depth to prevent stack overflow
 * @returns {any} - Sanitized copy of the object
 */
function deepSanitize(obj, sensitiveFields = SENSITIVE_FIELDS, maxDepth = 10) {
  // Base cases
  if (maxDepth <= 0) return "[MAX_DEPTH_EXCEEDED]";
  if (obj === null || obj === undefined) return obj;
  if (typeof obj !== "object") return obj;

  // Handle arrays
  if (Array.isArray(obj)) {
    return obj.map((item) => deepSanitize(item, sensitiveFields, maxDepth - 1));
  }

  // Handle objects
  const sanitized = {};
  for (const key of Object.keys(obj)) {
    const lowerKey = key.toLowerCase();
    if (sensitiveFields.has(lowerKey)) {
      sanitized[key] = "***REDACTED***";
    } else {
      sanitized[key] = deepSanitize(obj[key], sensitiveFields, maxDepth - 1);
    }
  }
  return sanitized;
}

function sanitizeBody(body) {
  return deepSanitize(body);
}

const errorLogger = (err, req, res, next) => {
  try {
    logger.logError(err, req, {
      timestamp: new Date().toISOString(),
      stack: err.stack,
    });
  } catch (logError) {
    console.error("Failed to log error:", logError.message);
  }

  next(err);
};

const performanceLogger = (req, res, next) => {
  const startTime = process.hrtime();

  res.on("finish", () => {
    try {
      const [seconds, nanoseconds] = process.hrtime(startTime);
      const duration = seconds * 1000 + nanoseconds / 1000000;

      logger.logPerformance(
        `${req.method} ${req.originalUrl}`,
        duration.toFixed(2),
        {
          statusCode: res.statusCode,
          userId: req.user?.id,
          businessId: req.user?.business_id,
          path: req.path,
        }
      );
    } catch (error) {
      console.error("Failed to log performance:", error.message);
    }
  });

  next();
};

const apiVersionLogger = (req, res, next) => {
  try {
    const apiVersion = req.baseUrl.match(/v\d+/)?.[0] || "v1";
    req.apiVersion = apiVersion;
    next();
  } catch (error) {
    logger.error("Error in API version logger", {
      error: error.message,
      path: req.path,
    });
    next(error);
  }
};

module.exports = {
  httpLogger,
  requestLogger,
  errorLogger,
  performanceLogger,
  apiVersionLogger,
};
