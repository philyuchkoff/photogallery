#!/usr/bin/env bash

set -euo pipefail

SOURCE_DIR="${1:-./Source}"
WEB_DIR="${2:-./Web}"
THUMB_SIZE="400"
FULL_SIZE="1920"
QUALITY="85"

# Убираем trailing slash если есть
SOURCE_DIR="${SOURCE_DIR%/}"

mkdir -p "$WEB_DIR/full" "$WEB_DIR/thumb"

# Проверка ImageMagick
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick not installed. Run: brew install imagemagick"
    exit 1
fi

# Временные файлы для сбора статистики
temp_dir=$(mktemp -d)
trap "rm -rf $temp_dir" EXIT

# Файлы для счетчиков
camera_file="$temp_dir/cameras.txt"
lens_file="$temp_dir/lenses.txt"
timeline_file="$temp_dir/timeline.txt"
category_file="$temp_dir/categories.txt"
rating_file="$temp_dir/ratings.txt"
temp_total="$temp_dir/total.txt"
temp_size="$temp_dir/size.txt"

# Инициализация счетчиков
echo "0" > "$temp_total"
echo "0" > "$temp_size"
echo "" > "$temp_dir/oldest.txt"
echo "" > "$temp_dir/newest.txt"

# Функция для добавления в счетчик
add_to_counter() {
    local file="$1"
    local key="$2"
    local temp_file="$temp_dir/temp_$$"
    
    if [ -f "$file" ]; then
        if grep -q "^$key:" "$file" 2>/dev/null; then
            awk -v k="$key" -F: '{if($1==k) print k":"$2+1; else print $0}' "$file" > "$temp_file"
            mv "$temp_file" "$file"
        else
            echo "$key:1" >> "$file"
        fi
    else
        echo "$key:1" > "$file"
    fi
}

# Функция для преобразования файла-счетчика в JSON объект
counter_to_json() {
    local file="$1"
    if [ -f "$file" ] && [ -s "$file" ]; then
        echo "{"
        local first_line=true
        while IFS=: read -r key value; do
            if [ "$first_line" = true ]; then
                first_line=false
            else
                echo ","
            fi
            key_escaped=$(echo "$key" | sed 's/"/\\"/g')
            echo -n "    \"$key_escaped\": $value"
        done < "$file"
        echo
        echo "}"
    else
        echo "{}"
    fi
}

# Функция для нормализации даты
normalize_date() {
    local date_str="$1"
    echo "$date_str" | sed 's/:/-/g'
}

# Начинаем JSON массив
echo "[" > "$WEB_DIR/gallery.json"
first=true

# Список известных категорий (чтобы не путать с подкатегориями)
KNOWN_CATEGORIES="Portfolio|Wildlife|Landscape|Portrait|Street"

# Поиск всех изображений
find "$SOURCE_DIR" -type f \( \
    -name "*.jpg" -o -name "*.JPG" -o \
    -name "*.jpeg" -o -name "*.JPEG" -o \
    -name "*.png" -o -name "*.PNG" \
\) -print0 | while IFS= read -r -d '' photo; do
    
    filename=$(basename "$photo")
    name_without_ext="${filename%.*}"
    
    # Получаем путь относительно SOURCE_DIR
    # Используем realpath или просто удаляем префикс
    abs_source=$(cd "$SOURCE_DIR" && pwd)
    abs_photo=$(cd "$(dirname "$photo")" && pwd)/"$filename"
    rel_path="${abs_photo#$abs_source/}"
    
    echo "Processing: $filename"
    
    # Получение размера файла (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        file_size=$(stat -f%z "$photo" 2>/dev/null || echo "0")
    else
        file_size=$(stat -c%s "$photo" 2>/dev/null || echo "0")
    fi
    
    # Обновляем общий размер
    current_size=$(cat "$temp_size")
    echo $((current_size + file_size)) > "$temp_size"
    
    # Извлечение EXIF данных
    date_taken=""
    camera=""
    lens=""
    focal_length=""
    aperture=""
    iso=""
    exposure=""
    
    if command -v exiftool &> /dev/null; then
        date_taken=$(exiftool -DateTimeOriginal -s3 "$photo" 2>/dev/null | cut -d' ' -f1 || echo "")
        if [ -n "$date_taken" ]; then
            date_taken=$(normalize_date "$date_taken")
        fi
        camera=$(exiftool -Model -s3 "$photo" 2>/dev/null || echo "")
        lens=$(exiftool -LensModel -s3 "$photo" 2>/dev/null || echo "")
        focal_length=$(exiftool -FocalLength -s3 "$photo" 2>/dev/null | sed 's/ mm//' || echo "")
        aperture=$(exiftool -FNumber -s3 "$photo" 2>/dev/null || echo "")
        iso=$(exiftool -ISO -s3 "$photo" 2>/dev/null || echo "")
        exposure=$(exiftool -ExposureTime -s3 "$photo" 2>/dev/null || echo "")
    fi
    
    # Если нет EXIF, используем дату файла
    if [ -z "$date_taken" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            date_taken=$(date -r "$photo" "+%Y-%m-%d" 2>/dev/null || echo "")
        else
            date_taken=$(stat -c %y "$photo" 2>/dev/null | cut -d' ' -f1 || echo "")
        fi
    fi
    
    # Если всё еще нет даты, используем текущую
    if [ -z "$date_taken" ]; then
        date_taken=$(date "+%Y-%m-%d")
    fi
    
    # Статистика по датам
    if [ -n "$date_taken" ] && [ "$date_taken" != "0000-00-00" ]; then
        year_month="${date_taken:0:7}"
        add_to_counter "$timeline_file" "$year_month"
        
        oldest=$(cat "$temp_dir/oldest.txt" 2>/dev/null || echo "")
        newest=$(cat "$temp_dir/newest.txt" 2>/dev/null || echo "")
        
        if [ -z "$oldest" ] || [ "$date_taken" \< "$oldest" ]; then
            echo "$date_taken" > "$temp_dir/oldest.txt"
        fi
        if [ -z "$newest" ] || [ "$date_taken" \> "$newest" ]; then
            echo "$date_taken" > "$temp_dir/newest.txt"
        fi
    fi
    
    # Статистика по камерам
    if [ -n "$camera" ]; then
        camera_clean=$(echo "$camera" | sed 's/^NIKON //' | sed 's/^Canon //' | sed 's/ Corporation//' | sed 's/^SONY //')
        if [ -n "$camera_clean" ]; then
            add_to_counter "$camera_file" "$camera_clean"
        fi
    fi
    
    # Статистика по объективам
    if [ -n "$lens" ]; then
        lens_clean=$(echo "$lens" | sed 's/^EF//' | sed 's/^AF-S //' | sed 's/ (35mm eq)//' | xargs)
        if [ -n "$lens_clean" ]; then
            add_to_counter "$lens_file" "$lens_clean"
        fi
    fi
    
    # Определение категории
    category="other"
    if [[ "$rel_path" == *"Portfolio"* ]] || [[ "$rel_path" == *"portfolio"* ]]; then
        category="portfolio"
    elif [[ "$rel_path" == *"Wildlife"* ]] || [[ "$rel_path" == *"wildlife"* ]]; then
        category="wildlife"
    elif [[ "$rel_path" == *"Landscape"* ]] || [[ "$rel_path" == *"landscape"* ]]; then
        category="landscape"
    elif [[ "$rel_path" == *"Portrait"* ]] || [[ "$rel_path" == *"portrait"* ]] || [[ "$rel_path" == *"PORTRAIT"* ]]; then
        category="portrait"
    elif [[ "$rel_path" == *"Street"* ]] || [[ "$rel_path" == *"street"* ]]; then
        category="street"
    fi
    add_to_counter "$category_file" "$category"
    
    # Чтение рейтинга
    rating=0
    rating_file_path="${photo%.*}.rating"
    if [ -f "$rating_file_path" ]; then
        rating=$(cat "$rating_file_path" | tr -d ' \n')
        if [[ "$rating" =~ ^[1-5]$ ]]; then
            add_to_counter "$rating_file" "$rating"
        else
            rating=0
        fi
    fi
    
    # ========== ОПРЕДЕЛЕНИЕ ПОДКАТЕГОРИИ (LOCATION) ==========
    location=""
    
    # Разбиваем путь на компоненты
    IFS='/' read -ra path_parts <<< "$rel_path"
    
    # Ищем подкатегорию - это часть после известной категории
    for i in "${!path_parts[@]}"; do
        part="${path_parts[$i]}"
        # Если нашли известную категорию
        if [[ "$part" =~ ^($KNOWN_CATEGORIES)$ ]]; then
            # Следующий компонент (если есть) - это подкатегория
            next_index=$((i + 1))
            if [ $next_index -lt ${#path_parts[@]} ]; then
                potential_location="${path_parts[$next_index]}"
                # Убеждаемся, что это не файл (не содержит точку)
                if [[ ! "$potential_location" =~ \. ]]; then
                    location="$potential_location"
                    break
                fi
            fi
        fi
    done
    
    # Если location все еще пустой, пробуем взять предпоследний компонент (если фото в корне категории)
    if [ -z "$location" ] && [ ${#path_parts[@]} -ge 2 ]; then
        last_index=$((${#path_parts[@]} - 1))
        prev_index=$((last_index - 1))
        potential_location="${path_parts[$prev_index]}"
        if [[ ! "$potential_location" =~ \. ]] && [[ ! "$potential_location" =~ ^($KNOWN_CATEGORIES)$ ]]; then
            location="$potential_location"
        fi
    fi
    
    # Для отладки (раскомментируйте если нужно)
    # echo "DEBUG: $filename -> rel_path=$rel_path, location=$location" >&2
    # ==========================================================
    
    # Создаем миниатюру
    convert "$photo" -resize "${THUMB_SIZE}x${THUMB_SIZE}^" -gravity center -extent "${THUMB_SIZE}x${THUMB_SIZE}" \
        "$WEB_DIR/thumb/${name_without_ext}.jpg" 2>/dev/null || true
    
    # Создаем full версию
    convert "$photo" -resize "${FULL_SIZE}x${FULL_SIZE}" -quality "$QUALITY" \
        "$WEB_DIR/full/${name_without_ext}.jpg" 2>/dev/null || true
    
    # Добавляем запись в JSON
    if [ "$first" = true ]; then
        first=false
    else
        echo "," >> "$WEB_DIR/gallery.json"
    fi
    
    # Экранируем спецсимволы
    title_escaped=$(echo "$name_without_ext" | sed 's/"/\\"/g' | sed 's/&/\\&/g')
    location_escaped=$(echo "$location" | sed 's/"/\\"/g')
    camera_escaped=$(echo "$camera" | sed 's/"/\\"/g')
    lens_escaped=$(echo "$lens" | sed 's/"/\\"/g')
    
    cat >> "$WEB_DIR/gallery.json" <<EOF
    {
        "id": "$name_without_ext",
        "title": "$title_escaped",
        "full": "full/${name_without_ext}.jpg",
        "thumbnail": "thumb/${name_without_ext}.jpg",
        "date": "$date_taken",
        "camera": "$camera_escaped",
        "lens": "$lens_escaped",
        "focal_length": "$focal_length",
        "aperture": "$aperture",
        "iso": "$iso",
        "exposure": "$exposure",
        "location": "$location_escaped",
        "category": "$category",
        "rating": $rating,
        "size_bytes": $file_size
    }
EOF
    
    current_total=$(cat "$temp_total")
    echo $((current_total + 1)) > "$temp_total"
    
done

# Закрываем JSON массив
echo "" >> "$WEB_DIR/gallery.json"
echo "]" >> "$WEB_DIR/gallery.json"

# Чтение итоговой статистики
total=$(cat "$temp_total" 2>/dev/null || echo "0")
total_size=$(cat "$temp_size" 2>/dev/null || echo "0")
oldest_date=$(cat "$temp_dir/oldest.txt" 2>/dev/null || echo "")
newest_date=$(cat "$temp_dir/newest.txt" 2>/dev/null || echo "")

# Подсчет лет активности
years_active="0"
if [ -n "$oldest_date" ] && [ -n "$newest_date" ] && [ "$oldest_date" != "0000-00-00" ] && [ "$newest_date" != "0000-00-00" ]; then
    oldest_year=$(echo "$oldest_date" | cut -d'-' -f1)
    newest_year=$(echo "$newest_date" | cut -d'-' -f1)
    years_active=$((newest_year - oldest_year))
fi

# Генерация stats.json
total_size_mb=$(echo "scale=2; $total_size / 1048576" | bc 2>/dev/null || echo "0")

cat > "$WEB_DIR/stats.json" <<EOF
{
    "total_photos": $total,
    "total_size_mb": $total_size_mb,
    "date_range": {
        "oldest": "$oldest_date",
        "newest": "$newest_date",
        "years_active": $years_active
    },
    "cameras": $(counter_to_json "$camera_file"),
    "lenses": $(counter_to_json "$lens_file"),
    "timeline": $(counter_to_json "$timeline_file"),
    "categories": $(counter_to_json "$category_file"),
    "ratings": $(counter_to_json "$rating_file")
}
EOF

# Подсчет файлов в папках
full_count=0
thumb_count=0
if [ -d "$WEB_DIR/full" ]; then
    full_count=$(find "$WEB_DIR/full" -type f -name "*.jpg" 2>/dev/null | wc -l | tr -d ' ')
fi
if [ -d "$WEB_DIR/thumb" ]; then
    thumb_count=$(find "$WEB_DIR/thumb" -type f -name "*.jpg" 2>/dev/null | wc -l | tr -d ' ')
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Gallery generated!"
echo "📸 Processed: $total photos"
echo "📁 Files created:"
echo "   - $WEB_DIR/gallery.json"
echo "   - $WEB_DIR/stats.json"
echo "   - $WEB_DIR/full/*.jpg ($full_count files)"
echo "   - $WEB_DIR/thumb/*.jpg ($thumb_count files)"
echo ""
echo "📊 Statistics:"
echo "   - Total size: $total_size_mb MB"
echo "   - Date range: ${oldest_date:-N/A} → ${newest_date:-N/A}"
echo "   - Years active: $years_active"
echo "═══════════════════════════════════════════════════════════"

# Проверка location в gallery.json
echo ""
echo "📂 Checking locations in gallery.json:"
python3 << PYTHON_SCRIPT
import json
from collections import defaultdict

with open('$WEB_DIR/gallery.json') as f:
    data = json.load(f)

locations = defaultdict(set)
for item in data:
    cat = item.get('category', 'other')
    loc = item.get('location', '')
    if loc:
        locations[cat].add(loc)

if locations:
    for cat, locs in locations.items():
        print(f"   {cat}: {', '.join(sorted(locs))}")
else:
    print("   ⚠️ No locations found! Check folder structure.")
    print("   Expected structure: Source/Category/Subcategory/photo.jpg")
PYTHON_SCRIPT

echo ""
echo "🚀 To view the gallery:"
echo "   cd $WEB_DIR && python3 -m http.server 8000"
echo "   Then open http://localhost:8000"