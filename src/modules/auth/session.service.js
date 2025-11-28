const dbConnection = require("../../database/connection");
const logger = require("../../config/logger.config");
const {
  DatabaseError,
  AuthenticationError,
} = require("../../utils/errors.util");
const { SESSION_OPERATIONS } = require("../../constants/operations");

class SessionService {
  async extendSession(userId, sessionToken) {
    let connection;
    try {
      if (!userId || !sessionToken) {
        throw new AuthenticationError("User ID and session token are required");
      }

      connection = await dbConnection.getMasterPool().getConnection();

      await connection.query(
        `CALL sp_session_manage(?, ?, ?, @p_is_success, @p_new_expiry_at, @p_error_message)`,
        [SESSION_OPERATIONS.UPDATE, userId, sessionToken]
      );

      const [outputRows] = await connection.query(
        "SELECT @p_is_success as is_success, @p_new_expiry_at as new_expiry_at, @p_error_message as error_message"
      );

      if (!outputRows || outputRows.length === 0) {
        throw new DatabaseError("Failed to retrieve extend session output");
      }

      const output = outputRows[0];

      return {
        isSuccess: output.is_success === 1 || output.is_success === true,
        newExpiryAt: output.new_expiry_at,
        errorMessage: output.error_message,
      };
    } catch (error) {
      if (error.statusCode) {
        throw error;
      }
      logger.error("SessionService.extendSession error", {
        userId,
        error: error.message,
      });
      throw new DatabaseError(
        `Failed to extend session: ${error.message}`,
        error
      );
    } finally {
      if (connection) {
        try {
          connection.release();
        } catch (releaseError) {
          logger.warn("Error releasing database connection", {
            error: releaseError.message,
          });
        }
      }
    }
  }

  async logout(userId) {
    let connection;
    try {
      if (!userId) {
        throw new AuthenticationError("User ID is required");
      }

      connection = await dbConnection.getMasterPool().getConnection();

      await connection.query(
        `CALL sp_session_manage(?, ?, ?, @p_is_success, @p_new_expiry_at, @p_error_message)`,
        [SESSION_OPERATIONS.DELETE, userId, null]
      );

      const [outputRows] = await connection.query(
        "SELECT @p_is_success as is_success, @p_error_message as error_message"
      );

      if (!outputRows || outputRows.length === 0) {
        throw new DatabaseError("Failed to retrieve logout output");
      }

      const output = outputRows[0];

      return {
        isSuccess: output.is_success === 1 || output.is_success === true,
        errorMessage: output.error_message,
      };
    } catch (error) {
      if (error.statusCode) {
        throw error;
      }
      logger.error("SessionService.logout error", {
        userId,
        error: error.message,
      });
      throw new DatabaseError(`Failed to logout: ${error.message}`, error);
    } finally {
      if (connection) {
        try {
          connection.release();
        } catch (releaseError) {
          logger.warn("Error releasing database connection", {
            error: releaseError.message,
          });
        }
      }
    }
  }
}

module.exports = new SessionService();
