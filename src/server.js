const app = require("./app");
const config = require("./config/env.config");
const dbConnection = require("./database/connection");

// Handle uncaught exceptions
process.on("uncaughtException", (error) => {
  console.error("UNCAUGHT EXCEPTION! 💥 Shutting down...");
  console.error(error.name, error.message);
  process.exit(1);
});

// Start server
const startServer = async () => {
  try {
    // Initialize database connections
    await dbConnection.initializeMasterConnection();

    // Start Express server
    const server = app.listen(config.port, () => {
      console.log(`
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
      `);
    });

    // Handle unhandled promise rejections
    process.on("unhandledRejection", (error) => {
      console.error("UNHANDLED REJECTION! 💥 Shutting down...");
      console.error(error);
      server.close(() => {
        process.exit(1);
      });
    });

    // Graceful shutdown
    process.on("SIGTERM", async () => {
      console.log("👋 SIGTERM RECEIVED. Shutting down gracefully");
      server.close(async () => {
        await dbConnection.closeConnections();
        console.log("💥 Process terminated!");
      });
    });
  } catch (error) {
    console.error("Failed to start server:", error);
    process.exit(1);
  }
};

// Start the server
startServer();
