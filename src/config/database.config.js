// Database connections configuration for master_db
const config = require("./env.config");

const databaseConfig = {
  master: {
    host: config.database.host,
    port: config.database.port,
    user: config.database.user,
    password: config.database.password,
    database: config.database.database,
    connectionLimit: config.database.connectionLimit,
    waitForConnections: config.database.waitForConnections,
    queueLimit: config.database.queueLimit,
    enableKeepAlive: true,
    keepAliveInitialDelay: 0,
  },
};

module.exports = databaseConfig;
