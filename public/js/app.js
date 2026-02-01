/**
 * FastPassNews Coaching Landing Page JavaScript
 */
document.addEventListener('DOMContentLoaded', () => {
  
  // Contact form submission
  const contactForm = document.getElementById('contactForm');
  if (contactForm) {
    contactForm.addEventListener('submit', handleContactFormSubmit);
  }

  // Mobile navigation menu toggle
  const mobileMenuButton = document.getElementById('mobileMenuButton');
  const navMenu = document.getElementById('navMenu');
  if (mobileMenuButton && navMenu) {
    mobileMenuButton.addEventListener('click', () => {
      navMenu.classList.toggle('active');
    });
  }

  // Initialize animation on scroll
  initScrollAnimations();
});

/**
 * Handle contact form submission
 * @param {Event} event - The form submit event
 */
async function handleContactFormSubmit(event) {
  event.preventDefault();
  
  // Get form elements
  const form = event.target;
  const submitButton = form.querySelector('button[type="submit"]');
  const formStatus = document.getElementById('formStatus');
  const nameInput = document.getElementById('name');
  const emailInput = document.getElementById('email');
  const phoneInput = document.getElementById('phone');
  const specializationInput = document.getElementById('specialization');
  const experienceLevelInput = document.getElementById('experience_level');
  const messageInput = document.getElementById('message');
  
  // Reset previous form errors
  resetFormErrors(form);
  
  // Validate form
  const errors = validateForm(nameInput, emailInput, phoneInput, specializationInput, experienceLevelInput, messageInput);
  if (errors.length > 0) {
    displayFormErrors(errors);
    return;
  }
  
  // Show loading state
  setButtonLoading(submitButton, true);
  
  try {
    // Prepare form data
    const formData = {
      name: nameInput.value.trim(),
      email: emailInput.value.trim(),
      phone: phoneInput.value.trim(),
      specialization: specializationInput.value,
      experience_level: experienceLevelInput.value,
      message: messageInput.value.trim()
    };
    
    // Определяем, где мы находимся и формируем правильный URL
    // Используем абсолютный путь для надежности
    let apiUrl;
    
    // Вариант 1: Прямой абсолютный путь к API
    apiUrl = '/api/contact';
    
    // Вариант 2: Путь с учетом размещения в /coaching/
    if (window.location.pathname.includes('/coaching')) {
      apiUrl = '/coaching/api/contact';
    }
    
    console.log('Текущий путь:', window.location.pathname);
    console.log('Отправка формы на URL:', apiUrl);
    
    // Send form data to the server
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(formData),
    });
    
    const data = await response.json();
    
    // Reset loading state
    setButtonLoading(submitButton, false);
    
    if (response.ok && data.success) {
      // Show success message
      displayFormStatus('success', 'Спасибо! Ваша заявка успешно отправлена. Мы свяжемся с вами в течение 24 часов.');
      // Reset form
      form.reset();
    } else {
      // Show error message from server or default error
      const errorMessage = data.message || 'Произошла ошибка при отправке заявки. Пожалуйста, попробуйте позже.';
      displayFormStatus('error', errorMessage);
      
      // Display validation errors if any
      if (data.errors && Array.isArray(data.errors)) {
        displayFormErrors(data.errors.map(error => ({
          field: error.param,
          message: error.msg
        })));
      }
    }
  } catch (error) {
    console.error('Error submitting form:', error);
    displayFormStatus('error', 'Не удалось отправить заявку. Пожалуйста, проверьте подключение к интернету и попробуйте снова.');
    setButtonLoading(submitButton, false);
  }
}

/**
 * Validate form fields
 * @param {HTMLInputElement} nameInput - The name input element
 * @param {HTMLInputElement} emailInput - The email input element
 * @param {HTMLInputElement} phoneInput - The phone input element
 * @param {HTMLSelectElement} specializationInput - The specialization select element
 * @param {HTMLSelectElement} experienceLevelInput - The experience level select element
 * @param {HTMLTextAreaElement} messageInput - The message textarea element
 * @return {Array} Array of error objects { field, message }
 */
function validateForm(nameInput, emailInput, phoneInput, specializationInput, experienceLevelInput, messageInput) {
  const errors = [];
  
  // Validate name
  if (!nameInput.value.trim()) {
    errors.push({ field: 'name', message: 'Пожалуйста, введите ваше имя' });
  } else if (nameInput.value.trim().length < 2) {
    errors.push({ field: 'name', message: 'Имя должно содержать не менее 2 символов' });
  }
  
  // Validate email
  if (!emailInput.value.trim()) {
    errors.push({ field: 'email', message: 'Пожалуйста, введите ваш email' });
  } else if (!isValidEmail(emailInput.value.trim())) {
    errors.push({ field: 'email', message: 'Пожалуйста, введите корректный email' });
  }
  
  // Validate phone (optional)
  if (phoneInput.value.trim() && phoneInput.value.trim().length < 5) {
    errors.push({ field: 'phone', message: 'Номер телефона должен содержать не менее 5 символов' });
  }
  
  // Validate specialization
  if (!specializationInput.value) {
    errors.push({ field: 'specialization', message: 'Пожалуйста, выберите направление обучения' });
  }
  
  // Validate experience level
  if (!experienceLevelInput.value) {
    errors.push({ field: 'experience_level', message: 'Пожалуйста, выберите уровень подготовки' });
  }
  
  // Validate message
  if (!messageInput.value.trim()) {
    errors.push({ field: 'message', message: 'Пожалуйста, введите сообщение' });
  } else if (messageInput.value.trim().length < 10) {
    errors.push({ field: 'message', message: 'Сообщение должно содержать не менее 10 символов' });
  }
  
  return errors;
}

/**
 * Check if email is valid
 * @param {string} email - The email to validate
 * @return {boolean} True if email is valid
 */
function isValidEmail(email) {
  const re = /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
  return re.test(String(email).toLowerCase());
}

/**
 * Reset all form errors
 * @param {HTMLFormElement} form - The form element
 */
function resetFormErrors(form) {
  // Remove all error messages
  const errorMessages = form.querySelectorAll('.form-error');
  errorMessages.forEach(el => el.remove());
  
  // Remove error class from inputs
  const inputs = form.querySelectorAll('.form-control');
  inputs.forEach(input => {
    input.classList.remove('is-invalid');
  });
  
  // Reset form status
  const formStatus = document.getElementById('formStatus');
  if (formStatus) {
    formStatus.className = 'form-status';
    formStatus.textContent = '';
    formStatus.style.display = 'none';
  }
}

/**
 * Display form errors under each field
 * @param {Array} errors - Array of error objects { field, message }
 */
function displayFormErrors(errors) {
  errors.forEach(error => {
    const field = document.getElementById(error.field);
    if (field) {
      // Add error class to input
      field.classList.add('is-invalid');
      
      // Create error message element
      const errorElement = document.createElement('div');
      errorElement.className = 'form-error';
      errorElement.textContent = error.message;
      
      // Insert error message after the field
      field.parentNode.insertBefore(errorElement, field.nextSibling);
    }
  });
}

/**
 * Display form status message (success/error)
 * @param {string} type - The status type ('success' or 'error')
 * @param {string} message - The message to display
 */
function displayFormStatus(type, message) {
  const formStatus = document.getElementById('formStatus');
  if (formStatus) {
    formStatus.className = `form-status ${type}`;
    formStatus.textContent = message;
    formStatus.style.display = 'block';
    
    // Scroll to status message
    formStatus.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
}

/**
 * Set button loading state
 * @param {HTMLButtonElement} button - The button element
 * @param {boolean} isLoading - Whether the button is loading
 */
function setButtonLoading(button, isLoading) {
  if (isLoading) {
    // Store original button text
    button.dataset.originalText = button.innerHTML;
    
    // Create loader element
    const loader = document.createElement('span');
    loader.className = 'loader';
    
    // Update button
    button.innerHTML = '';
    button.appendChild(loader);
    button.appendChild(document.createTextNode('Отправка...'));
    button.classList.add('btn-loading');
    button.disabled = true;
  } else {
    // Restore original button text
    button.innerHTML = button.dataset.originalText || 'Отправить';
    button.classList.remove('btn-loading');
    button.disabled = false;
  }
}

/**
 * Initialize animations on scroll
 */
function initScrollAnimations() {
  const animatedElements = document.querySelectorAll('.animate-on-scroll');
  
  if (animatedElements.length === 0) return;
  
  // Check if element is in viewport
  function isInViewport(element) {
    const rect = element.getBoundingClientRect();
    return (
      rect.top <= (window.innerHeight || document.documentElement.clientHeight) * 0.8
    );
  }
  
  // Handle scroll animation
  function handleScrollAnimation() {
    animatedElements.forEach(element => {
      if (isInViewport(element)) {
        element.classList.add('animate-fade-in');
      }
    });
  }
  
  // Add scroll event listener
  window.addEventListener('scroll', handleScrollAnimation);
  
  // Initial check
  handleScrollAnimation();
}
