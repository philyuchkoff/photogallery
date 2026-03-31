#!/usr/bin/env bash
# sync_to_web.sh - Синхронизация с удаленным сервером

set -euo pipefail

WEB_DIR="./Web"
REMOTE_USER="${1:-}"
REMOTE_HOST="${2:-}"
REMOTE_PATH="${3:-/var/www/photogallery}"

if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ]; then
    echo "Usage: $0 <user> <host> [remote_path]"
    echo "Example: $0 myuser myserver.com /var/www/photos"
    exit 1
fi

echo "🚀 Syncing to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

# Сначала генерируем свежую версию
./build_gallery.sh ./Source "$WEB_DIR"

# Синхронизация
rsync -avz --delete \
    --exclude="*.DS_Store" \
    "$WEB_DIR/" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/"

echo "✅ Sync complete!"
echo "🌐 Visit: http://$REMOTE_HOST"