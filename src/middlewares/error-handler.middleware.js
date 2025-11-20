// Error handler middleware
const ResponseUtil = require("../utils/response.util");

const errorHandler = (err, req, res, next) => {
  console.error("Error:", err);

  // Mongoose validation error
  if (err.name === "ValidationError") {
    const errors = Object.values(err.errors).map((e) => e.message);
    return ResponseUtil.badRequest(res, "Validation failed", errors);
  }

  // MySQL duplicate entry error
  if (err.code === "ER_DUP_ENTRY") {
    return ResponseUtil.conflict(res, "Duplicate entry found");
  }

  // JWT errors
  if (err.name === "JsonWebTokenError") {
    return ResponseUtil.unauthorized(res, "Invalid token");
  }

  if (err.name === "TokenExpiredError") {
    return ResponseUtil.unauthorized(res, "Token expired");
  }

  // Default error
  const statusCode = err.statusCode || 500;
  const message = err.message || "Internal server error";

  return ResponseUtil.error(res, message, statusCode);
};

module.exports = errorHandler;
