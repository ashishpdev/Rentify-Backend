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

const errorHandler = (err, req, res, next) => {
  const context = {
    timestamp: new Date().toISOString(),
    method: req.method,
    path: req.path,
    ip: req.ip,
  };

  if (err.statusCode && err.statusCode < 500) {
    logger.warn(`${err.code || "ERROR"} - ${err.message}`, context);
  } else {
    logger.error(`${err.code || "INTERNAL_ERROR"} - ${err.message}`, {
      ...context,
      stack: err.stack,
    });
  }

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
    logger.error("Database operation failed", { ...context, code: err.code });
    return ResponseUtil.serverError(res, "Database operation failed");
  }

  if (err instanceof AppError) {
    return ResponseUtil.error(res, err.message, err.statusCode);
  }

  if (err.name === "ValidationError" || err.details) {
    const errors = err.details?.map((e) => e.message) || [err.message];
    return ResponseUtil.badRequest(res, "Validation failed", errors);
  }

  if (err.code === "ER_DUP_ENTRY") {
    return ResponseUtil.conflict(res, "Duplicate entry found");
  }

  if (err.code?.startsWith("ER_")) {
    logger.error("Database error", { ...context, code: err.code });
    return ResponseUtil.serverError(res, "Database operation failed");
  }

  if (err.name === "JsonWebTokenError") {
    return ResponseUtil.unauthorized(res, "Invalid token");
  }

  if (err.name === "TokenExpiredError") {
    return ResponseUtil.unauthorized(res, "Token expired");
  }

  const statusCode = err.statusCode || err.status || 500;
  const message =
    statusCode < 500
      ? err.message || "Bad request"
      : "Internal server error";

  return ResponseUtil.error(res, message, statusCode);
};

module.exports = errorHandler;
