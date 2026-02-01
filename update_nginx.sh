#!/bin/bash

# FastPassNews Coaching Landing Page - Скрипт обновления Nginx
# Этот скрипт обновляет конфигурацию Nginx для поддержки /coaching маршрута
# Использование: sudo bash update_nginx.sh

# Проверка на запуск от имени root
if [ "$(id -u)" != "0" ]; then
   echo "Этот скрипт должен быть запущен с правами root (sudo bash update_nginx.sh)" 
   exit 1
fi

echo "=== FastPassNews Coaching - Обновление Nginx ==="

# Ищем директории, где могут находиться конфигурации Nginx
CONFIG_DIRS=(
    "/etc/nginx/sites-available"
    "/etc/nginx/conf.d"
    "/etc/nginx/sites-enabled"
    "/usr/local/etc/nginx/conf.d"
)

# Возможные имена конфигурационных файлов
CONFIG_NAMES=(
    "fastpassnews.conf"
    "default.conf"
    "default"
    "nginx.conf"
)

NGINX_CONF_FILE=""
FOUND_CONF=false

# Поиск конфигурационного файла
echo "Поиск конфигурационного файла Nginx..."
for DIR in "${CONFIG_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        echo "Проверка директории: $DIR"
        
        for NAME in "${CONFIG_NAMES[@]}"; do
            if [ -f "$DIR/$NAME" ]; then
                # Проверим, есть ли в файле настройки для fastpassnews.ru или порта 3000
                if grep -q "fastpassnews.ru\|localhost:3000" "$DIR/$NAME"; then
                    NGINX_CONF_FILE="$DIR/$NAME"
                    FOUND_CONF=true
                    echo "Найден файл конфигурации: $NGINX_CONF_FILE"
                    break 2
                fi
            fi
        done
    fi
done

if [ "$FOUND_CONF" = false ]; then
    echo "Не найден конфигурационный файл Nginx для fastpassnews.ru"
    echo "Пожалуйста, выберите один из доступных файлов конфигурации Nginx:"
    
    # Предложим пользователю выбрать из доступных файлов
    ALL_CONFS=()
    for DIR in "${CONFIG_DIRS[@]}"; do
        if [ -d "$DIR" ]; then
            for NAME in "${CONFIG_NAMES[@]}"; do
                if [ -f "$DIR/$NAME" ]; then
                    ALL_CONFS+=("$DIR/$NAME")
                fi
            done
        fi
    done
    
    if [ ${#ALL_CONFS[@]} -eq 0 ]; then
        echo "Не найдено ни одной конфигурации Nginx. Проверьте установку Nginx."
        exit 1
    fi
    
    echo "Доступные файлы конфигурации:"
    for ((i=0; i<${#ALL_CONFS[@]}; i++)); do
        echo "$i: ${ALL_CONFS[$i]}"
    done
    
    read -p "Введите номер файла: " conf_number
    
    if [[ "$conf_number" -ge 0 && "$conf_number" -lt ${#ALL_CONFS[@]} ]]; then
        NGINX_CONF_FILE="${ALL_CONFS[$conf_number]}"
        echo "Выбран файл: $NGINX_CONF_FILE"
        FOUND_CONF=true
    else
        echo "Неверный номер. Выход."
        exit 1
    fi
fi

# Работа с найденным файлом конфигурации
if [ "$FOUND_CONF" = true ]; then
    echo "Работа с конфигурацией в $NGINX_CONF_FILE"
    
    # Проверяем, существует ли уже блок location /coaching/
    LOCATION_EXISTS=$(grep -c "location /coaching/" "$NGINX_CONF_FILE")
    
    if [ "$LOCATION_EXISTS" -eq "0" ]; then
        echo "Добавление конфигурации coaching в $NGINX_CONF_FILE..."
        
        # Копируем конфигурационный файл в директорию с найденным файлом
        NGINX_DIR=$(dirname "$NGINX_CONF_FILE")
        cp /opt/landing_coach/nginx/fastpassnews_coaching.conf "$NGINX_DIR/"
        
        # Определим, нужно ли добавлять include или полностью блоки location
        if grep -q "include " "$NGINX_CONF_FILE"; then
            echo "Найдены директивы include, добавляем include для нашего файла..."
            
            # Проверим, есть ли server блок с SSL
            if grep -q "server {.*listen 443 ssl" "$NGINX_CONF_FILE"; then
                # Находим location / в блоке SSL и добавляем include перед ним
                sed -i '/server {.*listen 443 ssl/,/location \/ {/ s|location / {|include '"$NGINX_DIR"'/fastpassnews_coaching.conf;\n    location / {|' "$NGINX_CONF_FILE"
                echo "Добавлена директива include перед location / в блоке SSL"
            else
                # Добавляем в конец первого server блока
                sed -i '/server {/,/}/ s|.*}|    include '"$NGINX_DIR"'/fastpassnews_coaching.conf;\n}&|' "$NGINX_CONF_FILE"
                echo "Добавлена директива include в конец первого блока server"
            fi
        else
            echo "Не найдены директивы include, добавляем конфигурацию напрямую..."
            
            # Создаем временный файл
            TMP_FILE=$(mktemp)
            
            # Читаем содержимое fastpassnews_coaching.conf
            cat /opt/landing_coach/nginx/fastpassnews_coaching.conf > "$TMP_FILE"
            
            # Находим подходящее место для вставки
            if grep -q "server {.*listen 443 ssl" "$NGINX_CONF_FILE"; then
                # Добавляем перед location / в блоке SSL
                sed -i '/server {.*listen 443 ssl/,/location \/ {/ s|location / {|'"$(cat $TMP_FILE)"'\n    location / {|' "$NGINX_CONF_FILE"
                echo "Добавлена конфигурация перед location / в блоке SSL"
            else
                # Добавляем в конец первого server блока
                sed -i '/server {/,/}/ s|.*}|'"$(cat $TMP_FILE)"'\n}&|' "$NGINX_CONF_FILE"
                echo "Добавлена конфигурация в конец первого блока server"
            fi
            
            # Удаляем временный файл
            rm -f "$TMP_FILE"
        fi
    else
        echo "Конфигурация для /coaching/ уже существует в $NGINX_CONF_FILE"
        echo "Заменяем существующую конфигурацию..."
        
        # Сохраним временную копию файла
        BACKUP_FILE="$NGINX_CONF_FILE.bak-$(date +%Y%m%d%H%M%S)"
        cp "$NGINX_CONF_FILE" "$BACKUP_FILE"
        echo "Создана резервная копия: $BACKUP_FILE"
        
        # Удаляем все блоки с location /coaching/
        sed -i '/location .*\/coaching\/.*/,/}/d' "$NGINX_CONF_FILE"
        
        # Копируем конфигурационный файл в директорию с найденным файлом
        NGINX_DIR=$(dirname "$NGINX_CONF_FILE")
        cp /opt/landing_coach/nginx/fastpassnews_coaching.conf "$NGINX_DIR/"
        
        # Добавляем include перед location /
        if ! grep -q "include .*fastpassnews_coaching.conf" "$NGINX_CONF_FILE"; then
            if grep -q "location / {" "$NGINX_CONF_FILE"; then
                sed -i 's|location / {|include '"$NGINX_DIR"'/fastpassnews_coaching.conf;\nlocation / {|' "$NGINX_CONF_FILE"
                echo "Добавлена директива include перед location /"
            else
                # Добавляем в конец первого server блока
                sed -i '/server {/,/}/ s|.*}|    include '"$NGINX_DIR"'/fastpassnews_coaching.conf;\n}&|' "$NGINX_CONF_FILE"
                echo "Добавлена директива include в конец первого блока server"
            fi
        fi
    fi
    
    # Проверка конфигурации
    echo "Проверка конфигурации Nginx..."
    if nginx -t; then
        echo "Конфигурация Nginx корректна. Перезагрузка Nginx..."
        systemctl reload nginx
        echo "Nginx перезагружен."
    else
        echo "ОШИБКА: Конфигурация Nginx содержит ошибки."
        echo "Восстанавливаем из резервной копии: $BACKUP_FILE"
        cp "$BACKUP_FILE" "$NGINX_CONF_FILE"
        nginx -t
        echo "Пожалуйста, проверьте конфигурацию вручную и исправьте ошибки."
    fi
else
    echo "Не удалось найти подходящий файл конфигурации Nginx."
    echo "Пожалуйста, добавьте конфигурацию вручную, скопировав содержимое файла:"
    echo "/opt/landing_coach/nginx/fastpassnews_coaching.conf"
fi

echo "=== Завершено ==="
echo "После успешной настройки, страница обучения должна быть доступна по адресу:"
echo "https://fastpassnews.ru/coaching"
echo ""
echo "Для проверки локальной работы приложения: curl http://localhost:3002"

exit 0
