#!/bin/bash

# Скрипт для создания пользователя базы данных и настройки прав доступа
# Использование: sudo bash setup-db.sh

# Проверка на запуск от имени root
if [ "$(id -u)" != "0" ]; then
   echo "Этот скрипт должен быть запущен с правами root (sudo bash setup-db.sh)" 
   exit 1
fi

echo "=== FastPassNews Coaching - Настройка пользователя базы данных ==="

# Загружаем переменные окружения из .env файла
ENV_FILE="/opt/landing_coach/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Файл .env не найден! Пожалуйста, создайте его сначала."
    exit 1
fi

# Функция для чтения переменных из .env файла
function get_env_var() {
    local var_name="$1"
    local default_value="$2"
    
    # Извлечь значение переменной из .env файла, удалив кавычки если есть
    local value=$(grep "^$var_name=" "$ENV_FILE" | cut -d '=' -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    # Если значение не найдено, использовать значение по умолчанию
    if [ -z "$value" ]; then
        value="$default_value"
    fi
    
    echo "$value"
}

# Получаем параметры базы данных из .env
DB_USER=$(get_env_var "DB_USER" "n8n_user")
DB_PASSWORD=$(get_env_var "DB_PASSWORD" "")
DB_NAME=$(get_env_var "DB_NAME" "n8n_landing")

# Убираем кавычки из пароля, если они есть
DB_PASSWORD=${DB_PASSWORD//\"/}
DB_PASSWORD=${DB_PASSWORD//\'/}

echo "Использую следующие параметры:"
echo "- Пользователь: $DB_USER"
echo "- База данных: $DB_NAME"
echo "- Пароль: [скрыт]"

# Проверяем, существует ли пользователь
USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'")
if [ -z "$USER_EXISTS" ]; then
    echo "Создание пользователя $DB_USER..."
    # Создаем пользователя с указанным паролем
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    echo "Пользователь $DB_USER создан."
else
    echo "Пользователь $DB_USER уже существует. Обновление пароля..."
    sudo -u postgres psql -c "ALTER USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    echo "Пароль для пользователя $DB_USER обновлен."
fi

# Проверяем, существует ли база данных
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")
if [ -z "$DB_EXISTS" ]; then
    echo "Создание базы данных $DB_NAME..."
    # Создаем базу данных
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    echo "База данных $DB_NAME создана."
else
    echo "База данных $DB_NAME уже существует."
fi

# Предоставляем права на базу данных пользователю
echo "Предоставление прав пользователю $DB_USER на базу данных $DB_NAME..."
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# Предоставляем права на все таблицы
echo "Предоставление прав на все таблицы..."
sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;"
sudo -u postgres psql -d "$DB_NAME" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;"

echo "Перезагрузка приложения для применения новых настроек базы данных..."
pm2 restart coaching-app

echo "=== Настройка базы данных завершена ==="
echo "Теперь приложение должно успешно подключаться к базе данных."
echo "Проверьте логи: pm2 logs coaching-app"

exit 0
