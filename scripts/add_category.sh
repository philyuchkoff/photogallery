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
    2. Обновляет build_gallery.sh с правилом определения категории
    3. Обновляет index.html и stats.html с отображением категории
    4. Добавляет категорию в конфигурационный файл (если используется)
    5. Перегенерирует галерею

EOF
}

# Парсинг аргументов
CATEGORY_KEY=""
ICON="📁"
DISPLAY_NAME=""
PATTERN=""
CONFIG_FILE="./categories.conf"
BUILD_SCRIPT="./build_gallery.sh"
INDEX_HTML="./Web/index.html"
STATS_HTML="./Web/stats.html"

# Определяем путь к скрипту (если запускаем из папки scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../build_gallery.sh" ]; then
    BUILD_SCRIPT="$SCRIPT_DIR/../build_gallery.sh"
    INDEX_HTML="$SCRIPT_DIR/../Web/index.html"
    STATS_HTML="$SCRIPT_DIR/../Web/stats.html"
    CONFIG_FILE="$SCRIPT_DIR/../categories.conf"
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

# 2. Обновление build_gallery.sh
log_info "Обновление build_gallery.sh..."

if [ -f "$BUILD_SCRIPT" ]; then
    # Создаем резервную копию
    cp "$BUILD_SCRIPT" "${BUILD_SCRIPT}.backup"
    
    # Проверяем, существует ли уже такая категория
    if grep -q "category=\"$CATEGORY_KEY\"" "$BUILD_SCRIPT"; then
        log_warning "Категория $CATEGORY_KEY уже существует в build_gallery.sh"
    else
        # Формируем условие для новой категории
        NEW_CONDITION="elif [[ \"\$rel_path\" == *\"${CATEGORY_KEY_CAP}\"* ]] || [[ \"\$rel_path\" == *\"${CATEGORY_KEY}\"* ]]; then
    category=\"$CATEGORY_KEY\""
        
        # Вставляем новую категорию перед блоком "other"
        # Используем perl для совместимости с macOS (sed на macOS работает иначе)
        perl -i.bak2 -pe "if (/category=\"other\"/) { print \"$NEW_CONDITION\\n\"; }" "$BUILD_SCRIPT"
        
        log_success "Обновлен $BUILD_SCRIPT"
    fi
else
    log_warning "Файл $BUILD_SCRIPT не найден"
fi

# 3. Обновление index.html
log_info "Обновление index.html..."

if [ -f "$INDEX_HTML" ]; then
    cp "$INDEX_HTML" "${INDEX_HTML}.backup"
    
    # Проверяем, существует ли уже такая категория
    if grep -q "'$CATEGORY_KEY':" "$INDEX_HTML"; then
        log_warning "Категория $CATEGORY_KEY уже существует в index.html"
    else
        # Добавляем новую категорию в функцию getCategoryName()
        # Используем perl для вставки перед строкой с 'other'
        perl -i.bak2 -pe "if (/'other': '📁 Другое'/) { print \"        '$CATEGORY_KEY': '$ICON $DISPLAY_NAME',\\n\"; }" "$INDEX_HTML"
        
        log_success "Обновлен $INDEX_HTML"
    fi
else
    log_warning "Файл $INDEX_HTML не найден"
fi

# 4. Обновление stats.html
log_info "Обновление stats.html..."

if [ -f "$STATS_HTML" ]; then
    cp "$STATS_HTML" "${STATS_HTML}.backup"
    
    # Проверяем, существует ли уже такая категория
    if grep -q "'$CATEGORY_KEY':" "$STATS_HTML"; then
        log_warning "Категория $CATEGORY_KEY уже существует в stats.html"
    else
        # Добавляем новую категорию в stats.html
        perl -i.bak2 -pe "if (/'other': 'Другое'/) { print \"                '$CATEGORY_KEY': '$DISPLAY_NAME',\\n\"; }" "$STATS_HTML"
        
        log_success "Обновлен $STATS_HTML"
    fi
else
    log_warning "Файл $STATS_HTML не найден"
fi

# 5. Обновление конфигурационного файла (опционально)
log_info "Обновление конфигурации..."

if [ -f "$CONFIG_FILE" ]; then
    # Проверяем, нет ли уже такой категории
    if ! grep -q "^$CATEGORY_KEY:" "$CONFIG_FILE"; then
        echo "$CATEGORY_KEY:$DISPLAY_NAME:$ICON:$PATTERN" >> "$CONFIG_FILE"
        log_success "Добавлена запись в $CONFIG_FILE"
    else
        log_warning "Категория $CATEGORY_KEY уже существует в $CONFIG_FILE"
    fi
else
    # Создаем новый конфигурационный файл
    cat > "$CONFIG_FILE" << EOF
# Конфигурация категорий фотогалереи
# Формат: ключ:название:иконка:паттерны_поиска
portfolio:Портфолио:⭐:Portfolio
wildlife:Дикая природа:🦊:Wildlife,wildlife
landscape:Пейзажи:🌄:Landscape,landscape
$CATEGORY_KEY:$DISPLAY_NAME:$ICON:$PATTERN
EOF
    log_success "Создан конфигурационный файл $CONFIG_FILE"
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
echo "   2. Обновлен build_gallery.sh (добавлено правило определения категории)"
echo "   3. Обновлен index.html (добавлена категория в фильтры)"
echo "   4. Обновлен stats.html (добавлена категория в статистику)"
echo "   5. Создан README: $README_FILE"
echo "   6. Галерея перегенерирована"
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

# 9. Восстановление резервных копий (опционально)
log_info "Резервные копии сохранены:"
[ -f "${BUILD_SCRIPT}.backup" ] && echo "   - ${BUILD_SCRIPT}.backup"
[ -f "${INDEX_HTML}.backup" ] && echo "   - ${INDEX_HTML}.backup"
[ -f "${STATS_HTML}.backup" ] && echo "   - ${STATS_HTML}.backup"

echo ""
log_warning "Чтобы отменить изменения, выполните:"
echo "   mv ${BUILD_SCRIPT}.backup $BUILD_SCRIPT"
echo "   mv ${INDEX_HTML}.backup $INDEX_HTML"
echo "   mv ${STATS_HTML}.backup $STATS_HTML"