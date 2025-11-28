/**
 * Error handling middleware
 * Centralized error handling following industry standards
 * Converts custom AppError instances and system errors to appropriate HTTP responses
 */

const ResponseUtil = require("../utils/response.util");
const logger = require("../config/logger.config");
const {
  AppError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  ConflictError,
  DatabaseError,
} = require("../utils/errors.util");

/**
 * Comprehensive error handler middleware
 * Must be registered last in middleware stack
 */
const errorHandler = (err, req, res, next) => {
  const context = {
    timestamp: new Date().toISOString(),
    method: req.method,
    path: req.path,
    ip: req.ip,
    requestId: req.id || req.headers["x-request-id"],
  };

  // Log the error with context
  if (err.statusCode && err.statusCode < 500) {
    logger.warn(`${err.code || "ERROR"} - ${err.message}`, context);
  } else {
    logger.error(`${err.code || "INTERNAL_ERROR"} - ${err.message}`, {
      ...context,
      stack: err.stack,
      originalError: err.originalError?.message,
    });
  }

  // Handle custom AppError instances
  if (err instanceof ValidationError) {
    return ResponseUtil.badRequest(res, err.message, err.errors);
  }

  if (err instanceof AuthenticationError) {
    return ResponseUtil.unauthorized(res, err.message);
  }

  if (err instanceof AuthorizationError) {
    return ResponseUtil.forbidden(res, err.message);
  }

  if (err instanceof NotFoundError) {
    return ResponseUtil.notFound(res, err.message);
  }

  if (err instanceof ConflictError) {
    return ResponseUtil.conflict(res, err.message);
  }

  if (err instanceof DatabaseError) {
    // Log database errors with more details
    logger.error("Database operation failed", {
      ...context,
      code: err.code,
      message: err.message,
      originalError: err.originalError?.message,
    });
    return ResponseUtil.serverError(res, "Database operation failed");
  }

  if (err instanceof AppError) {
    return ResponseUtil.error(res, err.message, err.statusCode);
  }

  // Handle standard error types
  // Validation errors from Joi or other validators
  if (err.name === "ValidationError" || err.details) {
    const errors = err.details?.map((e) => e.message) || [err.message];
    return ResponseUtil.badRequest(res, "Validation failed", errors);
  }

  // MySQL errors
  if (err.code === "ER_DUP_ENTRY") {
    return ResponseUtil.conflict(res, "Duplicate entry found");
  }

  if (err.code?.startsWith("ER_")) {
    logger.error("MySQL error", {
      ...context,
      code: err.code,
      message: err.message,
      sqlMessage: err.sqlMessage,
    });
    return ResponseUtil.serverError(res, "Database operation failed");
  }

  // JWT errors
  if (err.name === "JsonWebTokenError") {
    return ResponseUtil.unauthorized(res, "Invalid token");
  }

  if (err.name === "TokenExpiredError") {
    return ResponseUtil.unauthorized(res, "Token expired");
  }

  // Default error handling
  const statusCode = err.statusCode || err.status || 500;
  const message =
    statusCode < 500
      ? err.message || "Bad request"
      : "Internal server error";

  return ResponseUtil.error(res, message, statusCode);
};

module.exports = errorHandler;
