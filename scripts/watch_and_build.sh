#!/usr/bin/env bash
# watch_and_build.sh - Автоматически перегенерирует галерею при изменениях

set -euo pipefail

SOURCE_DIR="${1:-./Source}"
WEB_DIR="${2:-./Web}"

echo "👀 Watching $SOURCE_DIR for changes..."
echo "Press Ctrl+C to stop"

# Проверка наличия fswatch (brew install fswatch)
if ! command -v fswatch &> /dev/null; then
    echo "Installing fswatch..."
    brew install fswatch
fi

# Функция перегенерации
rebuild() {
    echo ""
    echo "🔄 Changes detected! Rebuilding gallery..."
    ./build_gallery.sh "$SOURCE_DIR" "$WEB_DIR"
    echo "✅ Gallery updated at $(date +'%H:%M:%S')"
}

# Начальная генерация
rebuild

# Отслеживание изменений
fswatch -0 "$SOURCE_DIR" | while read -d "" event; do
    # Игнорируем временные файлы и .rating
    if [[ "$event" != *".rating"* ]] && [[ "$event" != *".DS_Store"* ]]; then
        rebuild
    fi
done