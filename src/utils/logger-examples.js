/**
 * Logger Usage Examples
 *
 * This file demonstrates various ways to use the logger in the Rentify application.
 * Copy and adapt these examples in your own modules.
 */

const logger = require("../config/logger.config");

// ============================================
// 1. BASIC LOGGING EXAMPLES
// ============================================

function basicLoggingExamples() {
  // Info level - general information
  logger.info("Application started successfully");

  // Info with metadata
  logger.info("User action completed", {
    action: "profile_update",
    userId: 123,
    timestamp: new Date(),
  });

  // Warning - something concerning but not critical
  logger.warn("API rate limit approaching", {
    endpoint: "/api/users",
    currentCount: 95,
    limit: 100,
  });

  // Error - something went wrong
  logger.error("Failed to send email", {
    recipient: "user@example.com",
    error: "SMTP connection timeout",
  });

  // Debug - detailed information (only in development)
  logger.debug("Processing request", {
    requestId: "req-12345",
    params: { id: 1 },
  });
}

// ============================================
// 2. CONTROLLER EXAMPLES
// ============================================

class ExampleController {
  async createUser(req, res) {
    const startTime = Date.now();

    try {
      logger.info("Creating new user", {
        email: req.body.email,
        businessType: req.body.businessType,
        ip: req.ip,
      });

      // Simulate user creation
      const user = { id: 123, email: req.body.email };

      const duration = Date.now() - startTime;
      logger.logPerformance("createUser", duration, {
        userId: user.id,
        success: true,
      });

      logger.info("User created successfully", {
        userId: user.id,
        email: user.email,
      });

      return res.json(user);
    } catch (error) {
      logger.logError(error, req, {
        operation: "createUser",
        email: req.body.email,
      });

      return res.status(500).json({ error: error.message });
    }
  }

  async getUser(req, res) {
    logger.debug("Fetching user details", {
      userId: req.params.id,
      requestedBy: req.user?.id,
    });

    // ... implementation
  }
}

// ============================================
// 3. SERVICE LAYER EXAMPLES
// ============================================

class ExampleService {
  async processPayment(orderId, amount) {
    logger.info("Starting payment processing", {
      orderId,
      amount,
    });

    try {
      // Payment processing logic
      const result = { transactionId: "txn-12345", status: "success" };

      logger.info("Payment processed successfully", {
        orderId,
        transactionId: result.transactionId,
        amount,
      });

      return result;
    } catch (error) {
      logger.error("Payment processing failed", {
        orderId,
        amount,
        error: error.message,
        stack: error.stack,
      });

      throw error;
    }
  }

  async sendNotification(userId, message) {
    logger.info("Sending notification", {
      userId,
      messageType: message.type,
    });

    // ... implementation
  }
}

// ============================================
// 4. AUTHENTICATION EXAMPLES
// ============================================

class AuthExamples {
  async login(email, password, req) {
    logger.logAuth("LOGIN_ATTEMPT", {
      email,
      ip: req.ip,
      userAgent: req.get("user-agent"),
    });

    try {
      // Validate credentials
      const user = { id: 123, email };

      logger.logAuth("LOGIN_SUCCESS", {
        userId: user.id,
        email: user.email,
        ip: req.ip,
      });

      return user;
    } catch (error) {
      logger.logAuth("LOGIN_FAILED", {
        email,
        reason: error.message,
        ip: req.ip,
      });

      throw error;
    }
  }

  async logout(userId) {
    logger.logAuth("LOGOUT", {
      userId,
      timestamp: new Date(),
    });
  }

  async refreshToken(userId) {
    logger.logAuth("TOKEN_REFRESH", {
      userId,
    });
  }
}

// ============================================
// 5. DATABASE OPERATION EXAMPLES
// ============================================

class DatabaseExamples {
  async insertRecord(table, data) {
    const startTime = Date.now();

    try {
      // Database insert
      const result = { insertId: 123 };
      const duration = Date.now() - startTime;

      logger.logDatabase("INSERT", {
        table,
        recordId: result.insertId,
        duration: `${duration}ms`,
      });

      return result;
    } catch (error) {
      logger.error("Database insert failed", {
        table,
        error: error.message,
        sqlState: error.sqlState,
      });

      throw error;
    }
  }

  async updateRecord(table, id, data) {
    const startTime = Date.now();

    logger.debug("Updating record", { table, id });

    try {
      // Database update
      const duration = Date.now() - startTime;

      logger.logDatabase("UPDATE", {
        table,
        recordId: id,
        duration: `${duration}ms`,
      });

      return true;
    } catch (error) {
      logger.error("Database update failed", {
        table,
        id,
        error: error.message,
      });

      throw error;
    }
  }

  async slowQuery(query) {
    const startTime = Date.now();

    // Execute query
    const duration = Date.now() - startTime;

    if (duration > 1000) {
      logger.warn("Slow database query detected", {
        query,
        duration: `${duration}ms`,
      });
    }
  }
}

// ============================================
// 6. BACKGROUND JOB EXAMPLES
// ============================================

class JobExamples {
  async runDailyReport() {
    logger.info("Starting daily report generation job");

    try {
      const startTime = Date.now();

      // Generate report
      const reportData = { totalUsers: 100, totalRevenue: 50000 };

      const duration = Date.now() - startTime;

      logger.info("Daily report generated successfully", {
        ...reportData,
        duration: `${duration}ms`,
      });
    } catch (error) {
      logger.logError(error, null, {
        job: "dailyReport",
        timestamp: new Date(),
      });
    }
  }

  async sendReminderEmails() {
    logger.info("Starting reminder email job");

    const users = []; // Fetch users
    let successCount = 0;
    let failCount = 0;

    for (const user of users) {
      try {
        // Send email
        successCount++;
        logger.debug("Reminder email sent", { userId: user.id });
      } catch (error) {
        failCount++;
        logger.error("Failed to send reminder email", {
          userId: user.id,
          error: error.message,
        });
      }
    }

    logger.info("Reminder email job completed", {
      total: users.length,
      successful: successCount,
      failed: failCount,
    });
  }
}

// ============================================
// 7. API INTEGRATION EXAMPLES
// ============================================

class APIExamples {
  async callExternalAPI(endpoint, data) {
    logger.info("Calling external API", {
      endpoint,
      method: "POST",
    });

    const startTime = Date.now();

    try {
      // API call
      const response = { status: 200, data: {} };
      const duration = Date.now() - startTime;

      logger.logPerformance("externalAPI", duration, {
        endpoint,
        statusCode: response.status,
      });

      logger.info("External API call successful", {
        endpoint,
        statusCode: response.status,
        duration: `${duration}ms`,
      });

      return response;
    } catch (error) {
      logger.error("External API call failed", {
        endpoint,
        error: error.message,
        statusCode: error.response?.status,
      });

      throw error;
    }
  }
}

// ============================================
// 8. FILE UPLOAD EXAMPLES
// ============================================

class FileUploadExamples {
  async uploadFile(file, userId) {
    logger.info("File upload started", {
      fileName: file.originalname,
      fileSize: file.size,
      mimeType: file.mimetype,
      userId,
    });

    try {
      // Upload logic
      const result = { url: "https://example.com/file.pdf" };

      logger.info("File uploaded successfully", {
        fileName: file.originalname,
        fileSize: file.size,
        url: result.url,
        userId,
      });

      return result;
    } catch (error) {
      logger.logError(error, null, {
        operation: "fileUpload",
        fileName: file.originalname,
        userId,
      });

      throw error;
    }
  }
}

// ============================================
// 9. ERROR HANDLING EXAMPLES
// ============================================

class ErrorHandlingExamples {
  // Custom error with logging
  async operationWithError() {
    try {
      throw new Error("Something went wrong");
    } catch (error) {
      // Log with full context
      logger.logError(error, null, {
        operation: "operationWithError",
        additionalContext: "Custom metadata",
      });

      throw error;
    }
  }

  // Validation error
  async validateData(data) {
    if (!data.email) {
      logger.warn("Validation failed", {
        field: "email",
        reason: "required",
        data: { ...data, password: "***REDACTED***" },
      });

      throw new Error("Email is required");
    }
  }

  // Business logic error
  async insufficientBalance(userId, requiredAmount, currentBalance) {
    logger.warn("Insufficient balance", {
      userId,
      requiredAmount,
      currentBalance,
      deficit: requiredAmount - currentBalance,
    });

    throw new Error("Insufficient balance");
  }
}

// ============================================
// 10. PERFORMANCE MONITORING EXAMPLES
// ============================================

class PerformanceExamples {
  async monitoredOperation() {
    const startTime = Date.now();

    try {
      // Perform operation
      await this.doSomething();

      const duration = Date.now() - startTime;

      logger.logPerformance("monitoredOperation", duration, {
        success: true,
      });
    } catch (error) {
      const duration = Date.now() - startTime;

      logger.logPerformance("monitoredOperation", duration, {
        success: false,
        error: error.message,
      });

      throw error;
    }
  }

  async doSomething() {
    // Implementation
  }
}

// ============================================
// EXPORT EXAMPLES
// ============================================

module.exports = {
  ExampleController,
  ExampleService,
  AuthExamples,
  DatabaseExamples,
  JobExamples,
  APIExamples,
  FileUploadExamples,
  ErrorHandlingExamples,
  PerformanceExamples,
};
