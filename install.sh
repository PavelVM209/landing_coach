#!/bin/bash

# FastPassNews Coaching Landing Page - Скрипт установки
# Этот скрипт автоматизирует процесс установки и настройки лэндинг-страницы обучения на сервере
# Использование: sudo bash install.sh

# Проверка на запуск от имени root
if [ "$(id -u)" != "0" ]; then
   echo "Этот скрипт должен быть запущен с правами root (sudo bash install.sh)" 
   exit 1
fi

echo "=== FastPassNews Coaching Page - Скрипт установки ==="
echo "Этот скрипт установит и настроит страницу обучения FastPassNews."

# Проверяем, установлены ли необходимые пакеты
echo -e "\n=== Проверка необходимых компонентов ==="

# Проверка Node.js
if ! command -v node &> /dev/null; then
    echo "Node.js не установлен. Установка Node.js..."
    # Устанавливаем Node.js
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    apt-get install -y nodejs
else
    echo "Node.js уже установлен: $(node -v)"
fi

# Проверка npm
if ! command -v npm &> /dev/null; then
    echo "npm не установлен. Установка npm..."
    apt-get install -y npm
else
    echo "npm уже установлен: $(npm -v)"
fi

# Проверка PM2
if ! command -v pm2 &> /dev/null; then
    echo "PM2 не установлен. Установка PM2..."
    npm install -g pm2
else
    echo "PM2 уже установлен: $(pm2 -v)"
fi

# Проверка Nginx
if ! command -v nginx &> /dev/null; then
    echo "Nginx не установлен. Установка Nginx..."
    apt-get install -y nginx
else
    echo "Nginx уже установлен: $(nginx -v 2>&1)"
fi

# Проверка PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "PostgreSQL не установлен. Установка PostgreSQL..."
    apt-get install -y postgresql postgresql-contrib
else
    echo "PostgreSQL уже установлен: $(psql --version)"
fi

# Копирование файлов проекта в /opt
echo -e "\n=== Копирование файлов проекта ==="
if [ ! -d "/opt/landing_coach" ]; then
    mkdir -p /opt/landing_coach
    echo "Каталог /opt/landing_coach создан"
fi

# Копируем файлы проекта в /opt/landing_coach
cp -R ./* /opt/landing_coach/
echo "Файлы проекта скопированы в /opt/landing_coach"

# Установка зависимостей
echo -e "\n=== Установка зависимостей проекта ==="
cd /opt/landing_coach
npm install

# Создание .env файла
echo -e "\n=== Создание конфигурационного файла ==="
if [ ! -f /opt/landing_coach/.env ]; then
    cp /opt/landing_coach/.env.example /opt/landing_coach/.env
    echo "Файл .env создан на основе .env.example"
    echo "ВАЖНО: Отредактируйте /opt/landing_coach/.env, чтобы настроить подключение к базе данных и SMTP!"
else
    echo "Файл .env уже существует"
fi

# Создание таблицы в PostgreSQL
echo -e "\n=== Настройка базы данных ==="
echo "Проверка существования базы данных fastpassnews..."

# Проверяем, существует ли база данных fastpassnews
DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='fastpassnews'")
if [ -z "$DB_EXISTS" ]; then
    echo "База данных fastpassnews не существует. Создание..."
    sudo -u postgres psql -c "CREATE DATABASE fastpassnews;"
    echo "База данных fastpassnews создана"
else
    echo "База данных fastpassnews уже существует"
fi

echo "Проверка существования таблицы landing_coach..."
TABLE_EXISTS=$(sudo -u postgres psql -d fastpassnews -tAc "SELECT 1 FROM pg_tables WHERE tablename='landing_coach'")
if [ -z "$TABLE_EXISTS" ]; then
    echo "Таблица landing_coach не существует. Применение SQL миграции..."
    sudo -u postgres psql -d fastpassnews -f /opt/landing_coach/src/database/init.sql
    echo "Миграция SQL применена"
else
    echo "Таблица landing_coach уже существует"
fi

# Настройка пользователя базы данных согласно .env
echo -e "\n=== Настройка пользователя базы данных ==="
echo "Запуск скрипта setup-db.sh для создания пользователя базы данных..."
chmod +x /opt/landing_coach/setup-db.sh
/opt/landing_coach/setup-db.sh
echo "Настройка пользователя базы данных завершена"

# Настройка Nginx
echo -e "\n=== Настройка Nginx ==="

# Спрашиваем пользователя, какой вариант размещения использовать
echo -e "\nВыберите вариант размещения страницы обучения:"
echo "1) На отдельном поддомене coaching.fastpassnews.ru"
echo "2) На поддиректории основного домена fastpassnews.ru/coaching"
read -p "Введите номер варианта (1 или 2): " hosting_option

if [ "$hosting_option" = "1" ]; then
    # Вариант 1: Отдельный поддомен
    echo "Вы выбрали размещение на отдельном поддомене."
    echo "Копирование конфигурационного файла для поддомена..."
    cp /opt/landing_coach/nginx/coaching-simple.conf /etc/nginx/sites-available/
    
    # Проверяем, существует ли символическая ссылка
    if [ ! -f /etc/nginx/sites-enabled/coaching-simple.conf ]; then
        ln -s /etc/nginx/sites-available/coaching-simple.conf /etc/nginx/sites-enabled/
        echo "Символическая ссылка создана."
    else
        echo "Символическая ссылка уже существует."
    fi
    
    echo -e "\nВАЖНО: Не забудьте создать DNS-запись типа A для поддомена coaching.fastpassnews.ru, указывающую на IP-адрес вашего сервера."
else
    # Вариант 2: Поддиректория основного домена
    echo "Вы выбрали размещение на поддиректории основного домена."
    
    # Проверяем, существует ли nginx.conf в /etc/nginx
    if [ -f "/etc/nginx/nginx.conf" ]; then
        echo "Найден основной файл конфигурации Nginx."
        
        # Ищем директорию, где хранятся конфигурации сайтов
        CONFIG_DIRS=("/etc/nginx/sites-available" "/etc/nginx/conf.d" "/etc/nginx/sites-enabled" "/usr/local/etc/nginx/conf.d")
        FOUND_CONF=false
        
        for DIR in "${CONFIG_DIRS[@]}"; do
            if [ -d "$DIR" ]; then
                echo "Найдена директория конфигураций: $DIR"
                
                # Ищем конфигурационный файл fastpassnews
                for CONF in "$DIR/fastpassnews.conf" "$DIR/default.conf" "$DIR/default"; do
                    if [ -f "$CONF" ]; then
                        NGINX_CONF_FILE="$CONF"
                        echo "Найден файл конфигурации: $NGINX_CONF_FILE"
                        FOUND_CONF=true
                        break 2
                    fi
                done
            fi
        done
        
        if [ "$FOUND_CONF" = false ]; then
            echo "ПРЕДУПРЕЖДЕНИЕ: Не найден конфигурационный файл Nginx для fastpassnews.ru"
            echo "Копируем файл fastpassnews_coaching.conf в /etc/nginx/conf.d/ (стандартная директория)"
            
            # Создаем директорию, если ее нет
            if [ ! -d "/etc/nginx/conf.d" ]; then
                mkdir -p /etc/nginx/conf.d
            fi
            
            # Копируем конфигурационный файл для включения
            cp /opt/landing_coach/nginx/fastpassnews_coaching.conf /etc/nginx/conf.d/
            
            echo "ВАЖНО: Вам нужно вручную добавить следующие строки в основной конфигурационный файл Nginx:"
            echo "include /etc/nginx/conf.d/fastpassnews_coaching.conf;"
            echo "Пожалуйста, добавьте эту строку ПЕРЕД location / в блоке server для fastpassnews.ru"
        else
            # Проверяем, существует ли уже блок location /coaching/
            LOCATION_EXISTS=$(grep -c "location /coaching/" "$NGINX_CONF_FILE")
            
            if [ "$LOCATION_EXISTS" -eq "0" ]; then
                echo "Добавление конфигурации coaching в $NGINX_CONF_FILE..."
                
                # Копируем конфигурационный файл в ту же директорию
                NGINX_DIR=$(dirname "$NGINX_CONF_FILE")
                cp /opt/landing_coach/nginx/fastpassnews_coaching.conf "$NGINX_DIR/"
                
                # Добавляем включение конфигурации перед блоком location /
                sed -i '/server {.*listen 443 ssl/,/location \/ {/ s|location / {|include '"$NGINX_DIR"'/fastpassnews_coaching.conf;\n    location / {|' "$NGINX_CONF_FILE"
                
                echo "Конфигурация coaching успешно добавлена в $NGINX_CONF_FILE"
            else
                echo "Конфигурация для /coaching/ уже существует в $NGINX_CONF_FILE"
                echo "Обновляем конфигурацию..."
                
                # Копируем конфигурационный файл в ту же директорию
                NGINX_DIR=$(dirname "$NGINX_CONF_FILE")
                cp /opt/landing_coach/nginx/fastpassnews_coaching.conf "$NGINX_DIR/"
                
                # Ищем, есть ли уже include для нашего файла
                INCLUDE_EXISTS=$(grep -c "include .*fastpassnews_coaching.conf" "$NGINX_CONF_FILE")
                
                if [ "$INCLUDE_EXISTS" -eq "0" ]; then
                    echo "Добавляем директиву include для fastpassnews_coaching.conf..."
                    sed -i '/server {.*listen 443 ssl/,/location \/ {/ s|location / {|include '"$NGINX_DIR"'/fastpassnews_coaching.conf;\n    location / {|' "$NGINX_CONF_FILE"
                else
                    echo "Директива include для fastpassnews_coaching.conf уже существует"
                fi
            fi
        fi
    else
        echo "ПРЕДУПРЕЖДЕНИЕ: Не найден основной файл конфигурации Nginx (/etc/nginx/nginx.conf)"
        echo "Создаем конфигурационный файл в /opt/landing_coach/nginx/"
        
        # Просто создаем файл в нашей директории, который можно будет применить вручную
        echo "Пожалуйста, добавьте содержимое файла /opt/landing_coach/nginx/fastpassnews_coaching.conf в вашу конфигурацию Nginx вручную"
    fi
fi

# Обновляем порты в коде, если они настроены на порт 3001
echo -e "\n=== Настройка порта приложения ==="
sed -i 's/const PORT = 3001/const PORT = 3002/g' /opt/landing_coach/src/server.js

# Проверка конфигурации
echo -e "\nПроверка конфигурации Nginx..."
nginx -t
if [ $? -eq 0 ]; then
    echo "Конфигурация Nginx корректна."
    echo "Перезагрузка Nginx..."
    systemctl reload nginx
    echo "Nginx перезагружен."
else
    echo "ОШИБКА: Конфигурация Nginx содержит ошибки. Пожалуйста, исправьте их перед продолжением."
    echo "Команда для проверки: sudo nginx -t"
    echo "Команда для перезагрузки после исправления: sudo systemctl reload nginx"
fi

# Запуск приложения через PM2
echo -e "\n=== Запуск приложения ==="
cd /opt/landing_coach
pm2 start src/server.js --name "coaching-app"
pm2 save

# Настройка автозапуска PM2
echo "Настройка автозапуска PM2..."
pm2_startup=$(pm2 startup systemd | grep -v '[sudo] password for' | grep sudo)
if [ ! -z "$pm2_startup" ]; then
    echo "Выполнение команды: $pm2_startup"
    eval $pm2_startup
    pm2 save
    echo "PM2 настроен на автозапуск"
else
    echo "Не удалось получить команду автозапуска PM2"
fi

echo -e "\n=== Установка завершена ==="

if [ "$hosting_option" = "1" ]; then
    echo "Страница обучения должна быть доступна по адресу: https://coaching.fastpassnews.ru"
    echo "Не забудьте создать DNS-запись для поддомена coaching.fastpassnews.ru"
else
    echo "Страница обучения должна быть доступна по адресу: https://fastpassnews.ru/coaching"
fi

echo -e "\nПроверьте следующее:"
echo "1. Правильно ли настроена конфигурация Nginx"
echo "2. Настроен ли файл .env с корректными параметрами подключения к базе и SMTP"
echo "3. Запущено ли приложение: pm2 status"
echo "4. Работает ли приложение: curl http://localhost:3002"
echo "5. Открыт ли порт 3002 в брандмауэре для Nginx"
echo ""
echo "Для просмотра логов приложения: pm2 logs coaching-app"

exit 0
