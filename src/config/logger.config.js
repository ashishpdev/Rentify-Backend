const winston = require("winston");
const DailyRotateFile = require("winston-daily-rotate-file");
const path = require("path");
const fs = require("fs");
const config = require("./env.config");

// Define log levels
const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4,
};

// Define colors for each level
const colors = {
  error: "red",
  warn: "yellow",
  info: "green",
  http: "magenta",
  debug: "blue",
};

// Tell winston about the colors
winston.addColors(colors);

// Determine the log level based on environment
const level = () => {
  const env = config.nodeEnv || "development";
  const isDevelopment = env === "development";
  return isDevelopment ? "debug" : "info";
};

// Define log format
const logFormat = winston.format.combine(
  winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss" }),
  winston.format.errors({ stack: true }),
  winston.format.splat(),
  winston.format.json()
);

// Console format with colors for development
const consoleFormat = winston.format.combine(
  winston.format.colorize({ all: true }),
  winston.format.timestamp({ format: "YYYY-MM-DD HH:mm:ss" }),
  winston.format.printf((info) => {
    const { timestamp, level, message, ...meta } = info;
    const metaString = Object.keys(meta).length
      ? `\n${JSON.stringify(meta, null, 2)}`
      : "";
    return `${timestamp} [${level}]: ${message}${metaString}`;
  })
);

// Define logs directory and ensure it exists
const logsDir = path.join(__dirname, "../../logs");
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir, { recursive: true });
}

// Transport: Console
const consoleTransport = new winston.transports.Console({
  format: consoleFormat,
});

// Transport: All logs (combined)
const combinedFileTransport = new DailyRotateFile({
  filename: path.join(logsDir, "combined-%DATE%.log"),
  datePattern: "YYYY-MM-DD",
  zippedArchive: true,
  maxSize: "20m",
  maxFiles: "14d",
  format: logFormat,
});

// Transport: Error logs
const errorFileTransport = new DailyRotateFile({
  filename: path.join(logsDir, "error-%DATE%.log"),
  datePattern: "YYYY-MM-DD",
  zippedArchive: true,
  maxSize: "20m",
  maxFiles: "30d",
  level: "error",
  format: logFormat,
});

// Transport: HTTP/Access logs
const httpFileTransport = new DailyRotateFile({
  filename: path.join(logsDir, "access-%DATE%.log"),
  datePattern: "YYYY-MM-DD",
  zippedArchive: true,
  maxSize: "20m",
  maxFiles: "7d",
  level: "http",
  format: logFormat,
});

// Transport: Warning logs
const warnFileTransport = new DailyRotateFile({
  filename: path.join(logsDir, "warn-%DATE%.log"),
  datePattern: "YYYY-MM-DD",
  zippedArchive: true,
  maxSize: "20m",
  maxFiles: "14d",
  level: "warn",
  format: logFormat,
});

// Create the logger
const logger = winston.createLogger({
  level: level(),
  levels,
  format: logFormat,
  transports: [
    combinedFileTransport,
    errorFileTransport,
    httpFileTransport,
    warnFileTransport,
  ],
  // Handle exceptions
  exceptionHandlers: [
    new DailyRotateFile({
      filename: path.join(logsDir, "exceptions-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      zippedArchive: true,
      maxSize: "20m",
      maxFiles: "30d",
    }),
  ],
  // Handle promise rejections
  rejectionHandlers: [
    new DailyRotateFile({
      filename: path.join(logsDir, "rejections-%DATE%.log"),
      datePattern: "YYYY-MM-DD",
      zippedArchive: true,
      maxSize: "20m",
      maxFiles: "30d",
    }),
  ],
  exitOnError: false,
});

// Add console transport in development
if (config.nodeEnv !== "production") {
  logger.add(consoleTransport);
}

// Create a stream object for Morgan HTTP logger
logger.stream = {
  write: (message) => {
    logger.http(message.trim());
  },
};

// Helper methods for structured logging
logger.logRequest = (req, metadata = {}) => {
  logger.http("HTTP Request", {
    method: req.method,
    url: req.originalUrl,
    ip: req.ip || req.connection.remoteAddress,
    userAgent: req.get("user-agent"),
    userId: req.user?.id,
    businessId: req.business?.id,
    ...metadata,
  });
};

logger.logResponse = (req, res, metadata = {}) => {
  logger.http("HTTP Response", {
    method: req.method,
    url: req.originalUrl,
    statusCode: res.statusCode,
    responseTime: metadata.responseTime,
    userId: req.user?.id,
    businessId: req.business?.id,
    ...metadata,
  });
};

logger.logError = (error, req = null, metadata = {}) => {
  const errorLog = {
    message: error.message,
    stack: error.stack,
    name: error.name,
    code: error.code,
    ...metadata,
  };

  if (req) {
    errorLog.request = {
      method: req.method,
      url: req.originalUrl,
      ip: req.ip || req.connection.remoteAddress,
      userId: req.user?.id,
      businessId: req.business?.id,
    };
  }

  logger.error(errorLog);
};

logger.logDatabase = (operation, metadata = {}) => {
  logger.info("Database Operation", {
    operation,
    ...metadata,
  });
};

logger.logAuth = (action, metadata = {}) => {
  logger.info("Authentication Event", {
    action,
    ...metadata,
  });
};

logger.logPerformance = (operation, duration, metadata = {}) => {
  logger.info("Performance Metric", {
    operation,
    duration: `${duration}ms`,
    ...metadata,
  });
};

module.exports = logger;
