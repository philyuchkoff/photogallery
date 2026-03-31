#!/usr/bin/env bash

# Загружаем переменные окружения из .env файла если есть
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Если пароль не установлен, запрашиваем
if [ -z "$PHOTOGALLERY_ADMIN_PASSWORD" ]; then
    echo -n "🔐 Enter admin password: "
    read -s PHOTOGALLERY_ADMIN_PASSWORD
    echo ""
    export PHOTOGALLERY_ADMIN_PASSWORD
fi

# Запускаем сервер
python3 api_server.py
