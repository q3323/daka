const path = require('path');

require('dotenv').config({
  path: path.join(__dirname, '..', '.env')
});

function required(name) {
  const value = process.env[name];
  if (!value || !String(value).trim()) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return String(value).trim();
}

const port = Number(required('PORT'));
const dbPort = Number(required('DB_PORT'));

if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('PORT must be an integer between 1 and 65535');
}

if (!Number.isInteger(dbPort) || dbPort < 1 || dbPort > 65535) {
  throw new Error('DB_PORT must be an integer between 1 and 65535');
}

module.exports = {
  port,
  bindHost: process.env.BIND_HOST || '0.0.0.0',
  db: {
    host: required('DB_HOST'),
    port: dbPort,
    database: required('DB_NAME'),
    user: required('DB_USER'),
    password: required('DB_PASSWORD')
  },
  jwtSecret: required('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d'
};
