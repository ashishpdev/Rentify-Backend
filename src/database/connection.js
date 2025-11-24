// src/database/connection.js
const mysql = require("mysql2/promise");
const databaseConfig = require("../config/database.config");

class DatabaseConnection {
  constructor() {
    this.masterPool = null;
    this._initializing = false;
  }

  /**
   * Initialize master connection pool (idempotent)
   */
  async initializeMasterConnection() {
    if (this.masterPool) {
      return this.masterPool;
    }
    if (this._initializing) {
      // Wait until previous init finishes
      while (this._initializing && !this.masterPool) {
        /* simple busy wait; in production a better event or promise should be used */
        // eslint-disable-next-line no-await-in-loop
        await new Promise((r) => setTimeout(r, 50));
      }
      return this.masterPool;
    }

    try {
      this._initializing = true;
      this.masterPool = mysql.createPool(databaseConfig.master);

      // quick connectivity test
      const conn = await this.masterPool.getConnection();
      await conn.ping();
      conn.release();

      console.log("✅ Master DB pool created and connection tested");
      return this.masterPool;
    } catch (err) {
      console.error(
        "❌ Failed to initialize master DB pool:",
        err.message || err
      );
      // cleanup if partially created
      if (this.masterPool) {
        try {
          await this.masterPool.end();
        } catch (_) {}
        this.masterPool = null;
      }
      throw err;
    } finally {
      this._initializing = false;
    }
  }

  getMasterPool() {
    if (!this.masterPool) {
      throw new Error(
        "Master DB pool is not initialized. Call initializeMasterConnection()"
      );
    }
    return this.masterPool;
  }

  async closeConnections() {
    if (!this.masterPool) return;
    try {
      await this.masterPool.end();
      console.log("Master database pool closed");
      this.masterPool = null;
    } catch (err) {
      console.error("Error closing master DB pool:", err.message || err);
      throw err;
    }
  }
}

module.exports = new DatabaseConnection();
