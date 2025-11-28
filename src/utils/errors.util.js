/**
 * Custom error classes for consistent error handling
 * Follows industry standard error hierarchy
 */

/**
 * Base application error
 */
class AppError extends Error {
  constructor(message, statusCode = 500, code = "INTERNAL_ERROR") {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.timestamp = new Date().toISOString();
    Error.captureStackTrace(this, this.constructor);
  }
}

/**
 * Validation error (400)
 */
class ValidationError extends AppError {
  constructor(message, errors = null) {
    super(message, 400, "VALIDATION_ERROR");
    this.errors = errors;
  }
}

/**
 * Authentication error (401)
 */
class AuthenticationError extends AppError {
  constructor(message) {
    super(message, 401, "AUTHENTICATION_ERROR");
  }
}

/**
 * Authorization error (403)
 */
class AuthorizationError extends AppError {
  constructor(message) {
    super(message, 403, "AUTHORIZATION_ERROR");
  }
}

/**
 * Not found error (404)
 */
class NotFoundError extends AppError {
  constructor(message) {
    super(message, 404, "NOT_FOUND");
  }
}

/**
 * Conflict error (409)
 */
class ConflictError extends AppError {
  constructor(message) {
    super(message, 409, "CONFLICT");
  }
}

/**
 * Database error
 */
class DatabaseError extends AppError {
  constructor(message, originalError = null) {
    super(message, 500, "DATABASE_ERROR");
    this.originalError = originalError;
  }
}

/**
 * External service error
 */
class ExternalServiceError extends AppError {
  constructor(message, service = "Unknown") {
    super(message, 503, "EXTERNAL_SERVICE_ERROR");
    this.service = service;
  }
}

module.exports = {
  AppError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  NotFoundError,
  ConflictError,
  DatabaseError,
  ExternalServiceError,
};
