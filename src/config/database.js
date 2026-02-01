// Правильно загружаем .env с абсолютным путем
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const { Pool } = require('pg');
const fs = require('fs');

// Выведем содержимое переменных окружения (без секретов) для диагностики
console.log('Переменные окружения (database.js):');
console.log('DB_HOST:', process.env.DB_HOST || 'не определено');
console.log('DB_PORT:', process.env.DB_PORT || 'не определено');
console.log('DB_USER:', process.env.DB_USER || 'не определено');
console.log('DB_NAME:', process.env.DB_NAME || 'не определено');
console.log('DB_TABLE:', process.env.DB_TABLE || 'не определено');
console.log('DB_PASSWORD есть?', process.env.DB_PASSWORD ? 'да' : 'нет');

// Более надежная обработка пароля
let dbPassword = process.env.DB_PASSWORD;
if (dbPassword && (dbPassword.startsWith('"') && dbPassword.endsWith('"') || 
                   dbPassword.startsWith("'") && dbPassword.endsWith("'"))) {
  dbPassword = dbPassword.substring(1, dbPassword.length - 1);
  console.log('Кавычки из пароля БД удалены');
}

// Create PostgreSQL connection pool
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  user: process.env.DB_USER || 'postgres',
  password: dbPassword,
  database: process.env.DB_NAME || 'n8n_landing', 
  max: 20, // max number of clients in the pool
  idleTimeoutMillis: 30000 // how long a client is allowed to remain idle before being closed
});

// Test database connection
pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('Database connection error:', err.message);
    console.log('Database connection details (without password):', {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432', 10),
      user: process.env.DB_USER || 'postgres',
      database: process.env.DB_NAME || 'n8n_landing'
    });
  } else {
    console.log('Database connected successfully, server time:', res.rows[0].now);
    
    // Initialize the database - run the init.sql script if needed
    initializeDatabase();
  }
});

// Initialize the database with required tables
async function initializeDatabase() {
  try {
    // Read the SQL initialization file
    const initSqlPath = path.join(__dirname, '..', 'database', 'init.sql');
    const initSql = fs.readFileSync(initSqlPath, 'utf8');
    
    // Execute the SQL script
    await pool.query(initSql);
    console.log('Database tables initialized successfully');
  } catch (error) {
    console.error('Failed to initialize database tables:', error.message);
  }
}

// Export the query function to be used by other modules
module.exports = {
  query: (text, params) => pool.query(text, params),
  pool
};
