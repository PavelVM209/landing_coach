# FastPassNews Coaching Landing Page

Лэндинг-страница для привлечения клиентов на обучение и практику в сферах ML, Data Engineering и DevOps.

## Содержание

1. [Описание проекта](#описание-проекта)
2. [Требования](#требования)
3. [Установка](#установка)
4. [Структура проекта](#структура-проекта)
5. [Настройка](#настройка)
6. [Запуск](#запуск)
7. [Обслуживание](#обслуживание)

## Описание проекта

Проект представляет собой лэндинг-страницу для продвижения услуг по обучению и практике в областях Machine Learning, Data Engineering и DevOps. Сайт включает:

- Презентацию направлений обучения и их преимуществ
- Описание процесса обучения
- Форму для отправки заявок потенциальными студентами
- Адаптивную верстку для мобильных устройств
- Серверную часть для обработки заявок и отправки уведомлений

## Требования

Для корректной работы проекта требуются:

- Node.js (рекомендуется v14 или выше)
- npm (v6 или выше)
- PostgreSQL (v10 или выше)
- Nginx (для продакшн-окружения)

## Установка

### Автоматическая установка

Для быстрой установки используйте скрипт `install.sh`:

```bash
# Клонировать репозиторий
git clone https://github.com/yourusername/landing_coach.git
cd landing_coach

# Сделать скрипт установки исполняемым
chmod +x install.sh

# Запустить скрипт установки от имени суперпользователя
sudo ./install.sh
```

Скрипт установки выполнит:
1. Проверку и установку необходимых зависимостей (Node.js, npm, PM2, Nginx, PostgreSQL)
2. Копирование файлов проекта в `/opt/landing_coach/`
3. Установку зависимостей npm
4. Создание базы данных и таблиц
5. Настройку Nginx
6. Запуск приложения через PM2

### Ручная установка

Если вы предпочитаете ручную установку, выполните следующие шаги:

1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/yourusername/landing_coach.git
   cd landing_coach
   ```

2. Установите зависимости:
   ```bash
   npm install
   ```

3. Создайте файл .env на основе .env.example:
   ```bash
   cp .env.example .env
   # Отредактируйте .env файл, добавив корректные настройки
   ```

4. Инициализируйте базу данных:
   ```bash
   # Сначала создайте пользователя и настройте базу данных с помощью специального скрипта
   sudo ./setup-db.sh
   
   # Затем примените миграцию SQL, если это необходимо
   sudo -u postgres psql -d fastpassnews -f src/database/init.sql
   ```
   
   Скрипт `setup-db.sh` автоматически:
   - Создает пользователя базы данных из .env файла (или обновляет пароль, если пользователь существует)
   - Создает базу данных, если она не существует
   - Предоставляет необходимые права доступа пользователю
   - Перезапускает приложение для применения изменений

5. Настройте Nginx:
   ```bash
   # Скопируйте конфигурационный файл
   sudo cp nginx/coaching-simple.conf /etc/nginx/sites-available/
   
   # Создайте символическую ссылку
   sudo ln -s /etc/nginx/sites-available/coaching-simple.conf /etc/nginx/sites-enabled/
   
   # Перезагрузите Nginx
   sudo systemctl reload nginx
   ```

6. Запустите приложение:
   ```bash
   # Установите PM2, если он не установлен
   npm install -g pm2
   
   # Запустите приложение
   pm2 start src/server.js --name "coaching-app"
   pm2 save
   ```

## Структура проекта

```
landing_coach/
├── .env.example          # Пример файла конфигурации
├── install.sh            # Скрипт автоматической установки
├── package.json          # Описание проекта и зависимости
├── README.md             # Документация проекта
├── nginx/                # Конфигурационные файлы Nginx
├── public/               # Статические файлы (CSS, JS, изображения)
├── src/                  # Исходный код
│   ├── config/           # Конфигурационные файлы
│   ├── controllers/      # Контроллеры для обработки запросов
│   ├── database/         # Скрипты инициализации БД
│   ├── routes/           # Маршруты API
│   └── server.js         # Основной файл приложения
```

## Настройка

### Конфигурация .env

Файл `.env` содержит конфигурационные параметры. Создайте его на основе `.env.example` и отредактируйте:

```bash
# Конфигурация сервера
PORT=3002
NODE_ENV=production

# База данных PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password_here
DB_NAME=fastpassnews
DB_SSL=false

# Настройки SMTP для отправки писем
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=your_email@example.com
SMTP_PASS=your_smtp_password
EMAIL_FROM=noreply@fastpassnews.ru
EMAIL_TO=admin@fastpassnews.ru
```

### Настройка Nginx

Проект поддерживает два варианта размещения:

1. **На отдельном поддомене** (например, coaching.fastpassnews.ru)
   - Используйте конфигурацию `coaching-simple.conf`
   - Создайте DNS-запись типа A для поддомена

2. **В поддиректории основного домена** (например, fastpassnews.ru/coaching)
   - Измените конфигурацию основного домена, добавив блоки location
   - Используйте комментированную часть в `coaching-simple.conf` как образец

## Запуск

### Локальная разработка

```bash
# Запустить в режиме разработки с автоматической перезагрузкой
npm run dev
```

### Продакшн

```bash
# Запуск с PM2
pm2 start src/server.js --name coaching-app

# Настройка автозапуска
pm2 startup
pm2 save
```

## Обслуживание

### Просмотр логов

```bash
# Просмотр логов приложения
pm2 logs coaching-app

# Просмотр логов Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Обновление приложения

```bash
# Остановить приложение
pm2 stop coaching-app

# Обновить файлы
cd /opt/landing_coach
git pull

# Обновить зависимости
npm install

# Обновить пользователя базы данных, если были изменения в параметрах подключения
sudo ./setup-db.sh

# Перезапустить приложение
pm2 start coaching-app
```

### Перезапуск сервисов

```bash
# Перезапуск приложения
pm2 restart coaching-app

# Перезапуск Nginx
sudo systemctl restart nginx
```
