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

function sanitizeBody(body) {
  const sensitiveFields = [
    "password",
    "token",
    "apiKey",
    "accessToken",
    "refreshToken",
    "secret",
    "creditCard",
    "ssn",
  ];

  const sanitized = { ...body };

  sensitiveFields.forEach((field) => {
    if (sanitized[field]) {
      sanitized[field] = "***REDACTED***";
    }
  });

  return sanitized;
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
