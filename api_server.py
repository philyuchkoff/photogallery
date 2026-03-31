#!/usr/bin/env python3
"""
API Server for PhotoGallery Admin Panel
Run: python3 api_server.py
"""

import os
import json
import shutil
import subprocess
import secrets
from pathlib import Path
from functools import wraps
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

app = Flask(__name__, static_folder='Web')
CORS(app)

BASE_DIR = Path(__file__).parent
SOURCE_DIR = BASE_DIR / 'Source'
WEB_DIR = BASE_DIR / 'Web'
BUILD_SCRIPT = BASE_DIR / 'build_gallery.sh'

# Получаем пароль из переменной окружения
ADMIN_PASSWORD = os.environ.get('PHOTOGALLERY_ADMIN_PASSWORD', 'admin123')
if ADMIN_PASSWORD == 'admin123':
    print("⚠️  WARNING: Using default password 'admin123'")
    print("   Set PHOTOGALLERY_ADMIN_PASSWORD environment variable for security:")
    print("   export PHOTOGALLERY_ADMIN_PASSWORD='your_secure_password'")
    print("")

# Хранилище сессий (простое, для демо)
sessions = {}

def require_auth(f):
    """Декоратор для проверки авторизации"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('X-Auth-Token')
        if not token or token not in sessions:
            return jsonify({'success': False, 'error': 'Unauthorized'}), 401
        return f(*args, **kwargs)
    return decorated

# Категории по умолчанию
CATEGORIES = [
    {'key': 'wildlife', 'name': 'Дикая природа', 'icon': '🦊'},
    {'key': 'portrait', 'name': 'Портреты', 'icon': '👤'},
    {'key': 'landscape', 'name': 'Пейзажи', 'icon': '🌄'},
    {'key': 'portfolio', 'name': 'Портфолио', 'icon': '⭐'},
    {'key': 'street', 'name': 'Уличная', 'icon': '🚶'},
    {'key': 'other', 'name': 'Другое', 'icon': '📁'}
]

# Загрузка пользовательских категорий
CATEGORIES_FILE = BASE_DIR / 'categories.json'
if CATEGORIES_FILE.exists():
    try:
        with open(CATEGORIES_FILE) as f:
            user_categories = json.load(f)
            # Объединяем, избегая дубликатов
            existing_keys = {c['key'] for c in CATEGORIES}
            for cat in user_categories:
                if cat['key'] not in existing_keys:
                    CATEGORIES.append(cat)
    except:
        pass


@app.route('/api/login', methods=['POST'])
def login():
    """Авторизация"""
    data = request.json
    password = data.get('password')
    
    if password == ADMIN_PASSWORD:
        token = secrets.token_urlsafe(32)
        sessions[token] = True
        return jsonify({'success': True, 'token': token})
    else:
        return jsonify({'success': False, 'error': 'Invalid password'}), 401


@app.route('/api/logout', methods=['POST'])
@require_auth
def logout():
    """Выход"""
    token = request.headers.get('X-Auth-Token')
    if token in sessions:
        del sessions[token]
    return jsonify({'success': True})


@app.route('/')
def index():
    """Главная страница"""
    return send_from_directory('Web', 'index.html')


@app.route('/godmode')
def godmode():
    """Админка"""
    return send_from_directory('Web', 'godmode.html')


@app.route('/api/categories', methods=['GET'])
@require_auth
def get_categories():
    """Получить список категорий"""
    categories = []
    for cat in CATEGORIES:
        cat_dir = SOURCE_DIR / cat['key'].capitalize()
        if cat_dir.exists() or True:  # Показываем все категории
            categories.append({
                'key': cat['key'],
                'name': cat['name'],
                'icon': cat['icon']
            })
    return jsonify(categories)


@app.route('/api/photos', methods=['GET'])
@require_auth
def get_photos():
    """Получить список всех фото"""
    photos = []
    for ext in ['*.jpg', '*.JPG', '*.jpeg', '*.JPEG', '*.png', '*.PNG']:
        for photo in SOURCE_DIR.rglob(ext):
            rel_path = photo.relative_to(SOURCE_DIR)
            parts = rel_path.parts
            
            category = parts[0].lower() if len(parts) > 0 else 'other'
            subcategory = parts[1] if len(parts) > 2 else ''
            
            # Ищем миниатюру
            thumb_name = photo.stem + '.jpg'
            thumb_path = WEB_DIR / 'thumb' / thumb_name
            
            photos.append({
                'name': photo.name,
                'path': str(rel_path),
                'category': category,
                'subcategory': subcategory,
                'thumbnail': f'/thumb/{thumb_name}' if thumb_path.exists() else '/thumb/placeholder.jpg'
            })
    
    return jsonify(photos)


@app.route('/api/upload', methods=['POST'])
@require_auth
def upload_photos():
    """Загрузить фото"""
    category = request.form.get('category')
    subcategory = request.form.get('subcategory', '')
    files = request.files.getlist('photos')
    
    if not category:
        return jsonify({'success': False, 'error': 'Category required'}), 400
    
    # Создаем директорию
    category_dir = SOURCE_DIR / category.capitalize()
    if subcategory:
        category_dir = category_dir / subcategory.capitalize()
    
    category_dir.mkdir(parents=True, exist_ok=True)
    
    uploaded = []
    for file in files:
        if file.filename:
            # Сохраняем оригинальное имя
            filepath = category_dir / file.filename
            # Если файл существует, добавляем суффикс
            counter = 1
            while filepath.exists():
                name, ext = os.path.splitext(file.filename)
                filepath = category_dir / f"{name}_{counter}{ext}"
                counter += 1
            file.save(filepath)
            uploaded.append(filepath.name)
    
    return jsonify({'success': True, 'uploaded': len(uploaded)})


@app.route('/api/delete', methods=['POST'])
@require_auth
def delete_photos():
    """Удалить фото"""
    data = request.json
    photos = data.get('photos', [])
    
    deleted = []
    for photo_path in photos:
        filepath = SOURCE_DIR / photo_path
        if filepath.exists():
            filepath.unlink()
            deleted.append(photo_path)
            
            # Удаляем миниатюру если есть
            thumb_name = filepath.stem + '.jpg'
            thumb_path = WEB_DIR / 'thumb' / thumb_name
            if thumb_path.exists():
                thumb_path.unlink()
    
    return jsonify({'success': True, 'deleted': len(deleted)})


@app.route('/api/generate', methods=['POST'])
@require_auth
def generate_gallery():
    """Запустить build_gallery.sh"""
    try:
        result = subprocess.run(
            [str(BUILD_SCRIPT), str(SOURCE_DIR), str(WEB_DIR)],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        if result.returncode == 0:
            return jsonify({'success': True, 'message': 'Галерея сгенерирована'})
        else:
            return jsonify({'success': False, 'error': result.stderr})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/add-category', methods=['POST'])
@require_auth
def add_category():
    """Добавить новую категорию"""
    data = request.json
    key = data.get('key')
    name = data.get('name')
    icon = data.get('icon', '📁')
    
    if not key or not name:
        return jsonify({'success': False, 'error': 'Key and name required'}), 400
    
    # Проверяем, нет ли уже такой категории
    if any(c['key'] == key for c in CATEGORIES):
        return jsonify({'success': False, 'error': f'Category "{key}" already exists'}), 400
    
    # Создаем папку
    category_dir = SOURCE_DIR / key.capitalize()
    category_dir.mkdir(exist_ok=True)
    
    # Сохраняем категорию
    new_category = {'key': key, 'name': name, 'icon': icon}
    CATEGORIES.append(new_category)
    
    # Сохраняем в файл
    with open(CATEGORIES_FILE, 'w') as f:
        json.dump([c for c in CATEGORIES if c['key'] not in ['wildlife', 'portrait', 'landscape', 'portfolio', 'street', 'other']], 
                  f, ensure_ascii=False, indent=2)
    
    return jsonify({'success': True, 'category': new_category})


@app.route('/<path:filename>')
def serve_static(filename):
    """Отдать статический файл"""
    return send_from_directory('Web', filename)


if __name__ == '__main__':
    print("=" * 50)
    print("🚀 PhotoGallery API Server")
    print("=" * 50)
    print(f"📁 Source dir: {SOURCE_DIR}")
    print(f"🌐 Web dir: {WEB_DIR}")
    print(f"🔗 Admin panel: http://localhost:5000/godmode")
    print(f"📷 Gallery: http://localhost:5000")
    print("")
    print("🔐 Authentication:")
    print(f"   Password from: PHOTOGALLERY_ADMIN_PASSWORD env var")
    if ADMIN_PASSWORD == 'admin123':
        print("   ⚠️  Using DEFAULT password: admin123")
        print("   Set environment variable for security:")
        print("   export PHOTOGALLERY_ADMIN_PASSWORD='your_secure_password'")
    else:
        print("   ✅ Custom password loaded from environment")
    print("=" * 50)
    print("")
    app.run(host='0.0.0.0', port=5000, debug=True)