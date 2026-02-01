const express = require('express');
const { body } = require('express-validator');
const contactController = require('../controllers/contactController');

const router = express.Router();

// Middleware for validating contact form submission
const validateContactForm = [
  body('name')
    .notEmpty().withMessage('Имя обязательно для заполнения')
    .trim()
    .isLength({ min: 2, max: 100 }).withMessage('Имя должно содержать от 2 до 100 символов'),
    
  body('email')
    .notEmpty().withMessage('Email обязателен для заполнения')
    .isEmail().withMessage('Пожалуйста, введите корректный email')
    .normalizeEmail({ gmail_remove_dots: false }),
  
  body('phone')
    .optional()
    .trim()
    .isLength({ min: 5, max: 20 }).withMessage('Номер телефона должен содержать от 5 до 20 символов'),
  
  body('specialization')
    .notEmpty().withMessage('Выберите специализацию')
    .isIn(['ml', 'data', 'devops']).withMessage('Выберите корректную специализацию'),
  
  body('experience_level')
    .notEmpty().withMessage('Укажите уровень опыта')
    .isIn(['beginner', 'intermediate', 'advanced']).withMessage('Выберите корректный уровень опыта'),
    
  body('message')
    .notEmpty().withMessage('Сообщение обязательно для заполнения')
    .trim()
    .isLength({ min: 10, max: 1000 }).withMessage('Сообщение должно содержать от 10 до 1000 символов')
];

// POST /api/contact - Submit coaching application form
router.post('/', validateContactForm, contactController.submitContactForm);

// GET /api/contact - Get application list (protected for admin)
// This could be protected with auth middleware in the future
router.get('/', contactController.getContacts);

module.exports = router;
