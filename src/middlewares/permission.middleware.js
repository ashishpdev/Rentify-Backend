const authRepository = require('../modules/auth/auth.repository');

const requirePermission = (permissionCode) => {
  return async (req, res, next) => {
    try {
      const userId = req.user?.user_id;

      if (!userId) {
        return res.status(401).json({
          success: false,
          error_code: 'ERR_UNAUTHORIZED',
          message: 'Authentication required',
        });
      }

      // Check permission
      const permissionCheck = await authRepository.checkPermission(userId, permissionCode);

      if (!permissionCheck.hasPermission) {
        return res.status(403).json({
          success: false,
          error_code: permissionCheck.errorCode || 'ERR_PERMISSION_DENIED',
          message: permissionCheck.errorMessage || 'Insufficient permissions',
        });
      }

      // Permission granted, proceed
      next();
    } catch (error) {
      console.error('Permission check error:', error);
      return res.status(500).json({
        success: false,
        error_code: 'ERR_PERMISSION_CHECK_FAILED',
        message: 'Failed to verify permissions',
      });
    }
  };
};

const requireAnyPermission = (...permissionCodes) => {
  return async (req, res, next) => {
    try {
      const userId = req.user?.user_id;

      if (!userId) {
        return res.status(401).json({
          success: false,
          error_code: 'ERR_UNAUTHORIZED',
          message: 'Authentication required',
        });
      }

      // Check each permission
      for (const permissionCode of permissionCodes) {
        const permissionCheck = await authRepository.checkPermission(userId, permissionCode);
        if (permissionCheck.hasPermission) {
          return next(); // User has at least one required permission
        }
      }

      // No permissions matched
      return res.status(403).json({
        success: false,
        error_code: 'ERR_PERMISSION_DENIED',
        message: 'Insufficient permissions',
      });
    } catch (error) {
      console.error('Permission check error:', error);
      return res.status(500).json({
        success: false,
        error_code: 'ERR_PERMISSION_CHECK_FAILED',
        message: 'Failed to verify permissions',
      });
    }
  };
};

module.exports = {
  requirePermission,
  requireAnyPermission,
};