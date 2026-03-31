#!/usr/bin/env bash
# add_rating.sh - Быстрое добавление рейтинга фото

set -euo pipefail

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] <photo_name> <rating>

Add rating to a photo (1-5 stars).

Examples:
    $0 arctic_fox_rookery_1 5
    $0 fox_vilyuchinsk_ready_1 4
    $0 --list                # Show all rated photos
    $0 --clear fox_vilyuchinsk_ready_1  # Remove rating
EOF
}

list_ratings() {
    echo "📸 Photos with ratings:"
    echo "========================"
    find ./Source -name "*.rating" -type f | while read -r rating_file; do
        photo="${rating_file%.rating}"
        rating=$(cat "$rating_file")
        filename=$(basename "$photo")
        echo "$filename: ⭐ $rating/5"
    done
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

if [ "$1" = "--list" ]; then
    list_ratings
    exit 0
fi

if [ "$1" = "--clear" ]; then
    if [ -z "$2" ]; then
        echo "Error: Photo name required"
        exit 1
    fi
    find ./Source -name "$2.*" -type f ! -name "*.rating" | while read -r photo; do
        rating_file="${photo}.rating"
        if [ -f "$rating_file" ]; then
            rm "$rating_file"
            echo "✅ Removed rating for $(basename "$photo")"
        else
            echo "⚠️  No rating found for $(basename "$photo")"
        fi
    done
    exit 0
fi

if [ $# -ne 2 ]; then
    show_help
    exit 1
fi

photo_name="$1"
rating="$2"

# Проверка рейтинга
if ! [[ "$rating" =~ ^[1-5]$ ]]; then
    echo "Error: Rating must be 1-5"
    exit 1
fi

# Поиск фото
photo=$(find ./Source -name "$photo_name.*" -type f ! -name "*.rating" | head -1)

if [ -z "$photo" ]; then
    echo "Error: Photo '$photo_name' not found in ./Source"
    exit 1
fi

# Добавление рейтинга
rating_file="${photo}.rating"
echo "$rating" > "$rating_file"
echo "✅ Added rating $rating/5 to $(basename "$photo")"

# Предложение перегенерировать галерею
echo ""
echo "📊 Run './build_gallery.sh ./Source ./Web' to update gallery"