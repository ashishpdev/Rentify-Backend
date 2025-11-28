// Authentication routes
const express = require("express");
const authController = require("./auth.controller");
const AccessTokenHeaderMiddleware = require("../../middlewares/access-token-header.middleware");
const SessionValidatorHeader = require("../../middlewares/session-validator-header.middleware");
const TokenUtil = require("../../utils/token.util");
const ResponseUtil = require("../../utils/response.util");
const logger = require("../../config/logger.config");

const router = express.Router();

// Public routes for OTP and registration flow
router.post("/send-otp", authController.sendOTP);
router.post("/verify-otp", authController.verifyOTP);
router.post("/login", authController.loginWithOTP);
router.post("/complete-registration", authController.completeRegistration);

// Decrypt access token - requires X-Access-Token header (mandatory)
router.post(
  "/decrypt-token",
  AccessTokenHeaderMiddleware.requireAccessTokenHeader,
  authController.decryptUserData
);

/**
 * Logout route
 * Requires x-access-token header only
 * Decrypts the access token to get user_id and removes the session entry via stored procedure
 */
router.post("/logout", async (req, res, next) => {
  let connection;
  try {
    // Extract access token from x-access-token header
    const accessToken = req.headers["x-access-token"];

    if (!accessToken) {
      logger.warn("Logout request without access token", {
        ip: req.ip,
        path: req.path,
      });
      return ResponseUtil.badRequest(
        res,
        "Access token is required for logout. Please provide x-access-token header."
      );
    }

    // Validate token structure
    if (!TokenUtil.isValidTokenStructure(accessToken)) {
      logger.warn("Invalid access token structure in logout request", {
        ip: req.ip,
      });
      return ResponseUtil.badRequest(res, "Invalid access token format");
    }

    // Decrypt the token to get user data
    const userData = TokenUtil.decryptAccessToken(accessToken);

    if (!userData || !userData.user_id) {
      logger.warn("Failed to extract user data from access token in logout", {
        ip: req.ip,
      });
      return ResponseUtil.unauthorized(res, "Invalid access token");
    }

    const userId = userData.user_id;

    // Call stored procedure to logout user
    const pool = require("../../database/connection").getMasterPool();
    connection = await pool.getConnection();

    await connection.query(
      `CALL sp_logout(?, @p_is_success, @p_error_message)`,
      [userId]
    );

    // Get output variables
    const [outputRows] = await connection.query(
      "SELECT @p_is_success as is_success, @p_error_message as error_message"
    );

    if (outputRows.length === 0) {
      logger.error("Failed to retrieve logout stored procedure output", {
        userId,
      });
      return ResponseUtil.serverError(res, "Failed to logout");
    }

    const output = outputRows[0];

    if (!output.is_success) {
      logger.warn("Logout failed from stored procedure", {
        userId,
        errorMessage: output.error_message,
      });
      return ResponseUtil.serverError(res, output.error_message || "Failed to logout");
    }

    logger.logAuth("LOGOUT_SUCCESS", {
      userId,
      ip: req.ip,
    });

    return ResponseUtil.success(
      res,
      { logged_out: true, userId },
      "Logged out successfully"
    );
  } catch (err) {
    // Handle different error types
    if (err.message.includes("tampered")) {
      logger.warn("Tampered access token in logout request", {
        error: err.message,
        ip: req.ip,
      });
      return ResponseUtil.unauthorized(
        res,
        "Access token has been compromised"
      );
    }

    if (err.message.includes("expired")) {
      logger.warn("Expired access token in logout request", {
        error: err.message,
        ip: req.ip,
      });
      return ResponseUtil.unauthorized(res, "Access token has expired");
    }

    logger.error("Error during logout", {
      error: err.message,
      ip: req.ip,
      stack: err.stack,
    });

    return ResponseUtil.serverError(res, "Failed to logout");
  } finally {
    if (connection) {
      connection.release();
    }
  }
});

module.exports = router;
