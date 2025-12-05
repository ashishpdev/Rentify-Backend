// src/database/connection.js
const mysql = require("mysql2/promise");
const databaseConfig = require("../config/database.config");
const logger = require("../config/logger.config");

class DatabaseConnection {
  constructor() {
    this.masterPool = null;
    this._initializing = false;
  }

  async initializeMasterConnection() {
    if (this.masterPool) return this.masterPool;

    if (this._initializing) {
      while (this._initializing && !this.masterPool) {
        await new Promise((r) => setTimeout(r, 50));
      }
      return this.masterPool;
    }

    try {
      this._initializing = true;

      logger.info("Initializing Master DB Pool", {
        host: databaseConfig.master.host,
        database: databaseConfig.master.database,
      });

      this.masterPool = mysql.createPool(databaseConfig.master);

      const conn = await this.masterPool.getConnection();
      await conn.ping();
      conn.release();

      logger.info("✅ Master DB Connected Successfully");
      return this.masterPool;
    } catch (err) {
      logger.error("❌ Failed to initialize Master DB", {
        error: err.message,
      });
      if (this.masterPool) {
        try { await this.masterPool.end(); } catch (_) {}
        this.masterPool = null;
      }
      throw err;
    } finally {
      this._initializing = false;
    }
  }

  getMasterPool() {
    if (!this.masterPool) throw new Error("DB Not Initialized - Call initializeMasterConnection()");
    return this.masterPool;
  }

  /** Execute Stored Procedure Automatically */
  async executeSP(query, params = []) {
    const pool = this.getMasterPool();
    return pool.query(query, params);
  }

  /** Select First Row Output */
  async executeSelect(query) {
    const pool = this.getMasterPool();
    const [rows] = await pool.query(query);
    return rows?.[0] ?? {};
  }

  async closeConnections() {
    if (!this.masterPool) return;
    await this.masterPool.end();
    logger.info("🔌 Master DB Connection Closed");
    this.masterPool = null;
  }
}

module.exports = new DatabaseConnection();
