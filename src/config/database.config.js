// src/config/database.config.js
const config = require("./env.config");

const defaultPoolOptions = {
  connectionLimit: config.database.connectionLimit || 10,
  waitForConnections: true,
  queueLimit: config.database.queueLimit || 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0,
  timezone: "+00:00", // Force UTC timezone for all connections
};

const databaseConfig = {
  master: {
    host: config.database.host,
    port: config.database.port,
    user: config.database.user,
    password: config.database.password,
    database: config.database.database,
    ...defaultPoolOptions,
  },
};

module.exports = databaseConfig;
