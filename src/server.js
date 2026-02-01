// Правильно загружаем .env с абсолютным путем
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../.env') });

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const helmet = require('helmet');
const contactRoutes = require('./routes/contact');

// Выведем содержимое переменных окружения для диагностики
console.log('Переменные окружения (server.js):');
console.log('NODE_ENV:', process.env.NODE_ENV || 'не определено');
console.log('PORT:', process.env.PORT || 'не определено');
console.log('DB_NAME:', process.env.DB_NAME || 'не определено');
console.log('SMTP_HOST:', process.env.SMTP_HOST || 'не определено');

// Initialize Express app
const app = express();
const PORT = process.env.PORT || 3002;

// Middleware
app.use(cors()); // Allow cross-origin requests
app.use(express.json()); // Parse JSON request body
app.use(express.urlencoded({ extended: true })); // Parse URL-encoded request body
app.use(helmet({ 
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"], // Allow inline scripts for simplicity
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"], // Allow inline styles and Google Fonts
      imgSrc: ["'self'", "data:", "https:"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
    }
  }
})); // Add security headers
app.use(morgan('dev')); // HTTP request logger

// Static files
app.use(express.static(path.join(__dirname, '..', 'public')));

// Routes
app.use('/coaching/api/contact', contactRoutes);
// Дополнительный маршрут для обработки запросов по обычному пути
app.use('/api/contact', contactRoutes);
// Обработка путей с двойным слешем (случаи, когда браузер формирует URL с //api/contact)
app.use('//api/contact', contactRoutes);
app.use('//coaching/api/contact', contactRoutes);

// Serve the landing page
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

// Handle 404
app.use((req, res) => {
  res.status(404).sendFile(path.join(__dirname, '..', 'public', 'index.html'));
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server Error:', err);
  console.error('Error Stack:', err.stack);
  console.error('Request URL:', req.originalUrl);
  console.error('Request Method:', req.method);
  console.error('Request Body:', req.body);
  console.error('Request Headers:', req.headers);
  
  res.status(500).json({ 
    success: false,
    message: 'Внутренняя ошибка сервера',
    error: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Log environment information
console.log('====== LANDING COACH SERVER INFO ======');
console.log('Environment:', process.env.NODE_ENV || 'не указано');
console.log('Port:', PORT);
console.log('Database Name:', process.env.DB_NAME || 'не указано');
console.log('SMTP Host:', process.env.SMTP_HOST || 'не указано');
console.log('====================================');

// Start server
app.listen(PORT, () => {
  console.log(`Landing coach server running on port ${PORT}`);
});

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  console.error(err.stack);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise);
  console.error('Reason:', reason);
});
