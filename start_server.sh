#!/usr/bin/env bash

# Загружаем переменные окружения из .env файла если есть
# (set -a делает переменные экспортируемыми, не полагаемся на парсинг grep/xargs)
if [ -f .env ]; then
    set -a
    . ./.env
    set +a
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
