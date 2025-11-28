/**
 * Async error handler wrapper for Express route handlers
 * Eliminates try-catch boilerplate in controllers
 * 
 * Usage: router.post('/path', asyncHandler(controllerMethod))
 */
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

/**
 * Request context helper - attaches context to request for logging
 */
class RequestContext {
  static from(req) {
    return {
      requestId: req.id || req.headers["x-request-id"] || null,
      userId: req.userId || null,
      method: req.method,
      path: req.path,
      ip: req.ip,
      userAgent: req.get("user-agent"),
    };
  }
}

module.exports = {
  asyncHandler,
  RequestContext,
};
