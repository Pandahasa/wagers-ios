const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASS,
    database: process.env.DB_NAME,
    // Ensure the MySQL driver treats and returns timestamps as UTC (no system conversion)
    timezone: 'Z',
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,  // For Aiven SSL
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

module.exports = pool;