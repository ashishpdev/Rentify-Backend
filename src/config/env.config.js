// src/config/env.config.js
const dotenv = require('dotenv');
const path = require('path');

// Load environment variables
dotenv.config({ path: path.join(__dirname, '../../.env') });

const NODE_ENV = process.env.NODE_ENV || 'development';

const parseIntOr = (value, fallback) => {
  const n = parseInt(value, 10);
  return Number.isNaN(n) ? fallback : n;
};

const config = {
  nodeEnv: NODE_ENV,
  isProd: NODE_ENV === 'production',

  port: parseIntOr(process.env.PORT, 3000),

  database: {
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT, 10) || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectionLimit: 10,
    waitForConnections: true,
    queueLimit: parseIntOr(process.env.DB_QUEUE_LIMIT, 0),
  },

  jwt: {
    secret: process.env.JWT_SECRET || 'please-change-me-in-prod',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  },

  email: {
    host: process.env.EMAIL_HOST,
    port: parseIntOr(process.env.EMAIL_PORT, 587),
    user: process.env.EMAIL_USER,
    password: process.env.EMAIL_PASSWORD,
    provider: process.env.EMAIL_PROVIDER || 'smtp',
  },

  cookie: {
    // HttpOnly: true in production (secure), false in development (allows JS access for testing)
    httpOnly:
      process.env.COOKIE_HTTP_ONLY === 'true' || NODE_ENV === 'production',
    // Secure: true in production (HTTPS only), false in development (allows HTTP)
    secure: process.env.COOKIE_SECURE === 'true' || NODE_ENV === 'production',
    // SameSite: 'None' in production (cross-site), 'Lax' in development
    sameSite:
      process.env.COOKIE_SAMESITE ||
      (NODE_ENV === 'production' ? 'None' : 'Lax'),
  },

  logLevel:
    process.env.LOG_LEVEL || (NODE_ENV === 'development' ? 'debug' : 'info'),
};

// In production, fail fast if critical env vars are missing
if (config.isProd) {
  const required = [
    'DB_HOST',
    'DB_USER',
    'DB_PASSWORD',
    'DB_NAME',
    'JWT_SECRET',
    'EMAIL_USER',
    'EMAIL_PASSWORD',
  ];
  const missing = required.filter((k) => !process.env[k]);
  if (missing.length) {
    throw new Error(
      `Missing required env vars in production: ${missing.join(', ')}`,
    );
  }
}

module.exports = config;
