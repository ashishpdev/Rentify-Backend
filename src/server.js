const app = require("./app");
const config = require("./config/env.config");
const dbConnection = require("./database/connection");
const logger = require("./config/logger.config");


// Handle uncaught exceptions
process.on("uncaughtException", (error) => {
  logger.error("UNCAUGHT EXCEPTION! 💥 Shutting down...", {
    error: {
      name: error.name,
      message: error.message,
      stack: error.stack,
    },
  });
  process.exit(1);
});

// Start server
const startServer = async () => {
  try {
    // Initialize database connections
    await dbConnection.initializeMasterConnection();

    // Start Express server
    const server = app.listen(config.port, () => {
      const serverInfo = `
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║  🚀 Rentify Backend Server                                 ║
║                                                            ║
║  Environment: ${config.nodeEnv.toUpperCase().padEnd(44)} ║
║  Port: ${config.port.toString().padEnd(51)} ║
║  Database: Connected ✅                                    ║
║                                                            ║
║  API: http://localhost:${config.port}/api                            ║
║  Docs: http://localhost:${config.port}/docs                          ║
║  Health: http://localhost:${config.port}/api/health                  ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
      `;

      console.log(serverInfo); // Console for visual startup
      logger.info("Server started successfully", {
        environment: config.nodeEnv,
        port: config.port,
        database: "Connected",
        endpoints: {
          api: `http://localhost:${config.port}/api`,
          docs: `http://localhost:${config.port}/docs`,
          health: `http://localhost:${config.port}/api/health`,
        },
      });
    });

    // Handle unhandled promise rejections
    process.on("unhandledRejection", (error) => {
      logger.error("UNHANDLED REJECTION! 💥 Shutting down...", {
        error: {
          name: error.name,
          message: error.message,
          stack: error.stack,
        },
      });
      server.close(() => {
        process.exit(1);
      });
    });

    // Graceful shutdown
    process.on("SIGTERM", async () => {
      logger.info("👋 SIGTERM RECEIVED. Shutting down gracefully");
      server.close(async () => {
        await dbConnection.closeConnections();
        logger.info("💥 Process terminated!");
      });
    });
  } catch (error) {
    logger.error("Failed to start server", {
      error: {
        name: error.name,
        message: error.message,
        stack: error.stack,
      },
    });
    process.exit(1);
  }
};

// Start the server
startServer();
