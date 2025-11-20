const mysql = require("mysql2/promise");
const databaseConfig = require("../config/database.config");

class DatabaseConnection {
  constructor() {
    this.masterPool = null;
  }

  async initializeMasterConnection() {
    try {
      this.masterPool = mysql.createPool(databaseConfig.master);

      // Test connection
      const connection = await this.masterPool.getConnection();
      console.log("✅ Master database connected successfully");
      connection.release();

      return this.masterPool;
    } catch (error) {
      console.error("❌ Master database connection failed:", error.message);
      throw error;
    }
  }

  getMasterPool() {
    if (!this.masterPool) {
      throw new Error("Master database pool is not initialized");
    }
    return this.masterPool;
  }

  async closeConnections() {
    try {
      if (this.masterPool) {
        await this.masterPool.end();
        console.log("Master database connection closed");
      }
    } catch (error) {
      console.error("Error closing database connections:", error.message);
      throw error;
    }
  }
}

// Export singleton instance
const dbConnection = new DatabaseConnection();
module.exports = dbConnection; // Database connection pool
