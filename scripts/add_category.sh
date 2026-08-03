#!/usr/bin/env bash

set -euo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции вывода
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Функция для преобразования первой буквы в заглавную
capitalize() {
    local str="$1"
    if [ -n "$str" ]; then
        first_char=$(echo "$str" | cut -c1 | tr '[:lower:]' '[:upper:]')
        rest=$(echo "$str" | cut -c2-)
        echo "${first_char}${rest}"
    else
        echo ""
    fi
}

# Показать справку
show_help() {
    cat << EOF
📁 add_category.sh - Автоматическое добавление новой категории в фотогалерею

Использование:
    $0 <название_категории> [опции]

Опции:
    --icon <иконка>     Иконка для категории (эмодзи, например: 🦊, 🌄, 👤)
    --name <название>   Отображаемое имя на русском (по умолчанию: название категории)
    --pattern <паттерн> Паттерн для поиска в путях (по умолчанию: название категории и lowercase)
    --help, -h          Показать эту справку

Примеры:
    # Простое добавление
    $0 Macro
    
    # С иконкой и русским названием
    $0 Macro --icon "🔬" --name "Макро"
    
    # С несколькими паттернами поиска
    $0 Architecture --icon "🏛️" --name "Архитектура" --pattern "Architecture,architecture,buildings"

Что делает скрипт:
    1. Создает папку для категории в ./Source
    2. Добавляет категорию в categories.json (единый источник категорий)
    3. Перегенерирует галерею (categories.js для фронтенда обновляется автоматически)

EOF
}

# Парсинг аргументов
CATEGORY_KEY=""
ICON="📁"
DISPLAY_NAME=""
PATTERN=""
BUILD_SCRIPT="./build_gallery.sh"

# Определяем путь к скрипту (если запускаем из папки scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../build_gallery.sh" ]; then
    BUILD_SCRIPT="$SCRIPT_DIR/../build_gallery.sh"
fi

# Парсим позиционные аргументы и опции
while [[ $# -gt 0 ]]; do
    case $1 in
        --icon)
            ICON="$2"
            shift 2
            ;;
        --name)
            DISPLAY_NAME="$2"
            shift 2
            ;;
        --pattern)
            PATTERN="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            if [ -z "$CATEGORY_KEY" ]; then
                CATEGORY_KEY="$1"
                shift
            else
                log_error "Неизвестный параметр: $1"
                show_help
                exit 1
            fi
            ;;
    esac
done

# Проверка обязательных параметров
if [ -z "$CATEGORY_KEY" ]; then
    log_error "Не указано название категории"
    show_help
    exit 1
fi

# Преобразуем ключ в нижний регистр для единообразия
CATEGORY_KEY=$(echo "$CATEGORY_KEY" | tr '[:upper:]' '[:lower:]')
CATEGORY_KEY_CAP=$(capitalize "$CATEGORY_KEY")

# Устанавливаем значения по умолчанию
if [ -z "$DISPLAY_NAME" ]; then
    DISPLAY_NAME="$CATEGORY_KEY_CAP"
fi

if [ -z "$PATTERN" ]; then
    PATTERN="${CATEGORY_KEY_CAP},${CATEGORY_KEY}"
fi

log_info "Добавление новой категории: $CATEGORY_KEY"
log_info "  Отображаемое имя: $DISPLAY_NAME"
log_info "  Иконка: $ICON"
log_info "  Паттерны поиска: $PATTERN"

# 1. Создание папки для категории
log_info "Создание папки для категории..."
SOURCE_DIR="./Source"
if [ -d "$SCRIPT_DIR/../Source" ]; then
    SOURCE_DIR="$SCRIPT_DIR/../Source"
fi

mkdir -p "$SOURCE_DIR/${CATEGORY_KEY_CAP}"
log_success "Создана папка: $SOURCE_DIR/${CATEGORY_KEY_CAP}"

# 2. Обновление categories.json (единый источник категорий)
log_info "Обновление categories.json..."

CATEGORIES_JSON="$SCRIPT_DIR/../categories.json"
if [ ! -f "$CATEGORIES_JSON" ]; then
    log_error "Файл categories.json не найден: $CATEGORIES_JSON"
    exit 1
fi

if ! python3 - "$CATEGORIES_JSON" "$CATEGORY_KEY" "$DISPLAY_NAME" "$ICON" "$PATTERN" <<'PY'
import json
import sys

file_path, key, name, icon, pattern = sys.argv[1:5]

with open(file_path, encoding='utf-8') as f:
    cats = json.load(f)

if any(c.get('key') == key for c in cats):
    print("EXISTS")
    sys.exit(0)

cats.append({'key': key, 'name': name, 'icon': icon, 'patterns': pattern})

with open(file_path, 'w', encoding='utf-8') as f:
    json.dump(cats, f, ensure_ascii=False, indent=2)

print("OK")
PY
then
    log_warning "Ошибка при обновлении categories.json"
else
    log_success "Обновлен $CATEGORIES_JSON"
fi

# 6. Создание примера README для категории
log_info "Создание документации..."

README_FILE="$SOURCE_DIR/${CATEGORY_KEY_CAP}/README.md"
if [ ! -f "$README_FILE" ]; then
    cat > "$README_FILE" << EOF
# ${DISPLAY_NAME} ${ICON}

## Описание
Фотографии в категории ${DISPLAY_NAME}.

## Структура
- Добавляйте фото в эту папку или создавайте подпапки для организации
- Для добавления рейтинга создайте файл с расширением .rating (например, photo_name.rating) и укажите в нем число от 1 до 5

## Правила
- Поддерживаемые форматы: PNG, JPG, JPEG
- Фото автоматически конвертируются в JPG для веба
- Категория определяется автоматически по имени папки
EOF
    log_success "Создан README: $README_FILE"
fi

# 7. Перегенерация галереи
log_info "Перегенерация галереи..."

if [ -f "$BUILD_SCRIPT" ]; then
    cd "$SCRIPT_DIR/.."
    if ./build_gallery.sh ./Source ./Web; then
        log_success "Галерея успешно перегенерирована"
    else
        log_error "Ошибка при перегенерации галереи"
        exit 1
    fi
else
    log_warning "Скрипт $BUILD_SCRIPT не найден, пропускаем перегенерацию"
fi

# 8. Итоговая информация
echo ""
echo "═══════════════════════════════════════════════════════════"
log_success "Категория '$DISPLAY_NAME' успешно добавлена! 🎉"
echo ""
echo "📋 Что было сделано:"
echo "   1. Создана папка: $SOURCE_DIR/${CATEGORY_KEY_CAP}/"
echo "   2. Добавлена запись в categories.json (единый источник категорий)"
echo "   3. Создан README: $README_FILE"
echo "   4. Галерея перегенерирована (categories.js обновлён автоматически)"
echo ""
echo "📁 Структура:"
echo "   $SOURCE_DIR/${CATEGORY_KEY_CAP}/     # Добавляйте сюда фото"
echo "   $SOURCE_DIR/${CATEGORY_KEY_CAP}/photo_name.rating  # Рейтинг (опционально)"
echo ""
echo "🚀 Следующие шаги:"
echo "   1. Добавьте фото в папку: cp /path/to/photos/* $SOURCE_DIR/${CATEGORY_KEY_CAP}/"
echo "   2. Запустите сервер: cd ./Web && python3 -m http.server 8000"
echo "   3. Откройте: http://localhost:8000"
echo ""
echo "📝 Примеры команд:"
echo "   # Добавить рейтинг фото"
echo "   echo \"5\" > \"$SOURCE_DIR/${CATEGORY_KEY_CAP}/new_photo.rating\""
echo ""
echo "   # Перегенерировать галерею после добавления фото"
echo "   ./build_gallery.sh ./Source ./Web"
echo "═══════════════════════════════════════════════════════════"