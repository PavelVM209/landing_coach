// Правильно загружаем .env с абсолютным путем
const path = require('path');
const dotenv = require('dotenv');
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const nodemailer = require('nodemailer');
const db = require('../config/database');
const { validationResult } = require('express-validator');

// Выведем содержимое переменных окружения (без секретов) для диагностики
console.log('Переменные окружения (contactController.js):');
console.log('SMTP_HOST:', process.env.SMTP_HOST || 'не определено');
console.log('SMTP_PORT:', process.env.SMTP_PORT || 'не определено');
console.log('SMTP_SECURE:', process.env.SMTP_SECURE || 'не определено');
console.log('SMTP_USER:', process.env.SMTP_USER || 'не определено');
console.log('SMTP_PASS есть?', process.env.SMTP_PASS ? 'да' : 'нет');
console.log('EMAIL_FROM:', process.env.EMAIL_FROM || 'не определено');
console.log('EMAIL_TO:', process.env.EMAIL_TO || 'не определено');

// Create reusable transporter for sending mail
const createTransporter = () => {
  // Обработка паролей с кавычками
  let smtpPass = process.env.SMTP_PASS;
  if (smtpPass && (smtpPass.startsWith('"') && smtpPass.endsWith('"') || 
                   smtpPass.startsWith("'") && smtpPass.endsWith("'"))) {
    smtpPass = smtpPass.substring(1, smtpPass.length - 1);
    console.log('Кавычки из пароля SMTP удалены');
  }
  
  // Выводим более полную информацию о параметрах SMTP для диагностики
  console.log('SMTP Config:', {
    host: process.env.SMTP_HOST || 'smtp.yandex.ru',
    port: process.env.SMTP_PORT || 465,
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER || 'не задан',
      pass: smtpPass ? '***' : 'не задан'
    },
    from: process.env.EMAIL_FROM || 'не задан',
    to: process.env.EMAIL_TO || 'не задан'
  });
  
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.yandex.ru',
    port: process.env.SMTP_PORT || 465,
    secure: process.env.SMTP_SECURE === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: smtpPass
    }
  });
};

// Format date for email
const formatDate = (date) => {
  const options = {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    timeZone: 'Europe/Moscow'
  };
  return new Date(date).toLocaleString('ru-RU', options);
};

/**
 * Submit contact form for coaching application
 * 1. Validate request data
 * 2. Send email notification (primary goal)
 * 3. Try to save contact to database (secondary goal)
 */
exports.submitContactForm = async (req, res) => {
  try {
    console.log('Получена заявка на обучение:', req.body);
    
    // Check for validation errors
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.log('Ошибки валидации:', errors.array());
      return res.status(400).json({ 
        success: false, 
        errors: errors.array() 
      });
    }

    // Get form data from request
    const { name, email, phone, specialization, experience_level, message } = req.body;
    
    // Get IP address
    const ipAddress = req.headers['x-forwarded-for'] || 
                     req.socket.remoteAddress || 
                     req.ip || 
                     'Unknown';

    // Current timestamp
    const timestamp = new Date();
    
    // Сначала сохраняем в базу данных, т.к. это более надежная операция
    console.log('Попытка сохранения в базу данных...');
    let contactId = null;
    try {
      const result = await db.query(
        'INSERT INTO landing_coach (name, email, phone, specialization, experience_level, message, ip_address, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id',
        [name, email, phone, specialization, experience_level, message, ipAddress, timestamp]
      );
      contactId = result.rows[0].id;
      console.log('Успешно сохранено в базу данных, ID:', contactId);
    } catch (dbError) {
      console.error('Ошибка сохранения в базу данных:', dbError);
      // Если не удалось сохранить в базу - сообщаем об ошибке
      return res.status(500).json({ 
        success: false, 
        message: 'Произошла ошибка при сохранении заявки в базу данных' 
      });
    }

    // Затем пытаемся отправить email, но не прерываем обработку если отправка не удалась
    let emailSent = false;
    try {
      console.log('Попытка отправки email...');
      const transporter = createTransporter();
      console.log('Настройки SMTP:', {
        host: process.env.SMTP_HOST,
        port: process.env.SMTP_PORT,
        secure: process.env.SMTP_SECURE === 'true',
        user: process.env.SMTP_USER ? '***' : 'не указан',
        from: process.env.EMAIL_FROM,
        to: process.env.EMAIL_TO
      });

      // Получить название специализации
      let specializationName = "";
      switch(specialization) {
        case "ml":
          specializationName = "Machine Learning";
          break;
        case "data":
          specializationName = "Data Engineering";
          break;
        case "devops":
          specializationName = "DevOps";
          break;
        default:
          specializationName = specialization || "Не указана";
      }

      // Получить уровень опыта
      let experienceText = "";
      switch(experience_level) {
        case "beginner":
          experienceText = "Начинающий";
          break;
        case "intermediate":
          experienceText = "Средний";
          break;
        case "advanced":
          experienceText = "Продвинутый";
          break;
        default:
          experienceText = experience_level || "Не указан";
      }

      // Prepare email content
      const mailOptions = {
        from: process.env.EMAIL_FROM || 'noreply@fastpassnews.ru',
        to: process.env.EMAIL_TO || 'admin@fastpassnews.ru',
        subject: `Новая заявка на обучение: ${specializationName}`,
        html: `
          <h2>Новая заявка на обучение</h2>
          <p><strong>Имя:</strong> ${name}</p>
          <p><strong>Email:</strong> ${email}</p>
          <p><strong>Телефон:</strong> ${phone || 'Не указан'}</p>
          <p><strong>Специализация:</strong> ${specializationName}</p>
          <p><strong>Уровень опыта:</strong> ${experienceText}</p>
          <p><strong>Сообщение:</strong></p>
          <div style="background-color: #f4f4f4; padding: 15px; border-left: 4px solid #007bff; margin: 10px 0;">
            ${message.replace(/\n/g, '<br>')}
          </div>
          <p><strong>IP адрес:</strong> ${ipAddress}</p>
          <p><strong>Время отправки:</strong> ${formatDate(timestamp)}</p>
          <hr>
          <p>Это автоматическое сообщение, не отвечайте на него.</p>
        `
      };

      // Отправка email (с таймаутом 5 секунд, чтобы не блокировать ответ)
      await Promise.race([
        transporter.sendMail(mailOptions),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Email timeout')), 5000)
        )
      ]);
      
      emailSent = true;
      console.log('Email успешно отправлен');
    } catch (emailError) {
      console.error('Ошибка отправки email (не критичная):', emailError);
      // Не прерываем обработку запроса из-за ошибки отправки email
    }
    // Send success response
    res.status(201).json({ 
      success: true, 
      message: emailSent 
        ? 'Заявка успешно отправлена и сохранена' 
        : 'Заявка успешно сохранена, но возникли проблемы с отправкой уведомления',
      contactId,
      emailSent
    });

  } catch (error) {
    console.error('Error submitting application form:', error);
    
    res.status(500).json({ 
      success: false,
      message: 'Произошла ошибка при отправке заявки: ' + (error.message || 'Неизвестная ошибка')
    });
  }
};

/**
 * Get list of coaching applications (for admin panel in the future)
 */
exports.getContacts = async (req, res) => {
  try {
    const result = await db.query(
      'SELECT * FROM landing_coach ORDER BY created_at DESC LIMIT 100'
    );
    
    res.status(200).json({ 
      success: true,
      applications: result.rows 
    });
  } catch (error) {
    console.error('Error getting applications:', error);
    
    res.status(500).json({ 
      success: false, 
      message: 'Произошла ошибка при получении списка заявок' 
    });
  }
};
