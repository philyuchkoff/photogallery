# PhotoGallery – Personal Photography Portfolio & Gallery

A complete static website generator for photographers to organize, display, and analyze their photo collections with automatic gallery generation, hierarchical categories, and detailed statistics.

![Gallery Demo](https://via.placeholder.com/800x400?text=Gallery+Screenshot)

## ✨ Features

- **📸 Automatic Gallery Generation** – Convert PNG/JPG photos into a beautiful web gallery with thumbnails and full-size images
- **🏷️ Hierarchical Categories** – Organize photos by categories (Wildlife, Portrait, etc.) with automatic subcategory detection from folder structure
- **📊 Interactive Statistics** – View charts and analytics: timeline, camera/lens usage, category distribution, ratings
- **🌙☀️ Dark/Light Theme** – Toggle between themes with persistent user preference
- **⭐ Rating System** – Add ratings (1-5 stars) to your best photos
- **📱 Responsive Design** – Works perfectly on desktop, tablet, and mobile devices
- **🚀 Zero Dependencies** – Static site can be hosted anywhere (GitHub Pages, Netlify, etc.)
- **🛠️ Helper Scripts** – Easy category management, rating tools, and auto-rebuild
- **🔐 Admin Panel** – Web-based management interface with secure authentication

## 📋 Prerequisites

- **macOS / Linux** (bash 3.2+)
- **ImageMagick** – for image processing
- **exiftool** (optional) – for EXIF metadata extraction
- **Python 3** (optional) – for local preview server

Install dependencies on macOS:
```bash
brew install imagemagick exiftool
pip3 install flask flask-cors
```

## Structure

```text
photogallery/
├── Source/                      # Original photos (organized by category)
│   ├── Wildlife/                # Main category
│   │   ├── Bears/               # Subcategory
│   │   │   └── bear_photo.jpg
│   │   ├── Foxes/               # Subcategory
│   │   │   └── fox_photo.png
│   │   └── Seals/
│   ├── Portrait/                # Another category
│   │   ├── Studio/
│   │   └── Candid/
│   └── Portfolio/               # Best works
│
├── Web/                         # Generated website (auto-created)
│   ├── index.html               # Gallery viewer
│   ├── stats.html               # Statistics dashboard
│   ├── gallery.json             # Photo metadata
│   ├── stats.json               # Statistics data
│   ├── full/                    # Optimized full-size images
│   └── thumb/                   # Thumbnails (400px)
│   ├── godmode.html             # Admin panel
│
├── build_gallery.sh             # Main gallery generator
├── api_server.py                # Admin API server
├── start_server.sh              # Launch script with env vars
├── .env                         # Environment variables (optional)
└── scripts/                     # Helper utilities
    ├── add_category.sh          # Add new category
    ├── add_rating.sh            # Add rating to photos
    └── watch_and_build.sh       # Auto-rebuild on changes
```

## Quick Start
### 1. Clone or create the project
```bash
mkdir photogallery && cd photogallery
```
### 2. Add your photos
Organize photos by category and subcategory:
```text
Source/
├── Wildlife/
│   ├── Bears/
│   │   └── bear_kurilskoe.jpg
│   └── Foxes/
│       └── arctic_fox_rookery_1.png
└── Portrait/
    └── studio_portrait.jpg
```
### 3. Generate the gallery
```bash
chmod +x build_gallery.sh
./build_gallery.sh Source/ Web/
```
### 4. View locally
```bash
cd Web
python3 -m http.server 8000
```
then open [http://localhost:8000](http://localhost:8000) in your browser.

### 5. Add ratings for photos (optional)
```bash
echo "5" > "Source/Wildlife/Foxes/arctic_fox_rookery_1.rating"
```
and rebuild the gallery:
```bash
./build_gallery.sh Source/ Web/
```

### Start admin panel (optional)
```bash
# Set admin password
export PHOTOGALLERY_ADMIN_PASSWORD='your_secure_password'

# Start API server
python3 api_server.py
```

## Admin Panel
The admin panel provides a web-based interface for managing your photo gallery without touching the command line.

### Starting the Admin Server
```bash
# Method 1: Set environment variable directly
export PHOTOGALLERY_ADMIN_PASSWORD='your_secure_password'
python3 api_server.py

# Method 2: Use launch script
./start_server.sh

# Method 3: Use .env file
echo "PHOTOGALLERY_ADMIN_PASSWORD=your_secure_password" > .env
python3 api_server.py
```

### Admin Panel Features
- Secure authentication:	password stored in environment variable, not in code
- upload photos:	drag & drop or select files, choose category and subcategory
- delete photos:	browse all photos, select multiple, delete with confirmation
- add categories:	create new categories with custom name and icon
- generate gallery:	one-click rebuild of the entire gallery
- photo list:	view all photos with thumbnails and metadata

### Security Notes
- password storage: never stored in code, only in environment variables
- session tokens: temporary tokens generated on successful login
- logout: session expires on logout or server restart
- API protection: all admin endpoints require authentication

### Environment Variables

`PHOTOGALLERY_ADMIN_PASSWORD`	- default	`admin123` (⚠️ change for production!)

### Customizing Admin Password
```bash
# Temporary for current session
export PHOTOGALLERY_ADMIN_PASSWORD='my_secure_password_123'

# Permanent (add to your ~/.zshrc or ~/.bashrc)
echo "export PHOTOGALLERY_ADMIN_PASSWORD='my_secure_password_123'" >> ~/.zshrc

# Using .env file in project
echo "PHOTOGALLERY_ADMIN_PASSWORD=my_secure_password_123" > .env
chmod 600 .env  # Restrict file permissions
```

## Scripts Reference
### `build_gallery.sh`
Generates the complete website from your source photos.
Usage: `./build_gallery.sh [source_dir] [web_dir]`
where
- `source_dir`: Directory with original photos (default: ./Source)
- `web_dir`: Output directory for website (default: ./Web)

Features:

- converts PNG to JPG for web optimization
- creates thumbnails and full-size versions
- extracts EXIF metadata (date, camera, lens)
- detects categories from folder names
- detects subcategories from nested folders
- reads ratings from `.rating` files
- generates `gallery.json` and `stats.json`

### `scripts/add_category.sh`
Adds a new category with automatic updates to all necessary files.

```bash
./scripts/add_category.sh <category_key> [options]
```

Options:
  - `--icon <icon>`     Emoji icon (e.g., 🦊, 🌄, 👤)
  - `--name <name>`     Display name (Russian or English)
  - `--pattern <pattern>` Search patterns (default: category name)

Examples:
  `./scripts/add_category.sh Macro --icon "🔬" --name "Macro"`
  `./scripts/add_category.sh Architecture --icon "🏛️" --name "Architecture"`

### `scripts/add_rating.sh`

Quickly add or view photo ratings.

```bash
# Add rating
./scripts/add_rating.sh photo_name 5

# List all rated photos
./scripts/add_rating.sh --list

# Remove rating
./scripts/add_rating.sh --clear photo_name
```
### `scripts/watch_and_build.sh`
Auto-rebuild the gallery when photos change (requires `fswatch`).
```bash
brew install fswatch
./scripts/watch_and_build.sh
```

## Gallery Features
### Category Navigation
- Main categories displayed as buttons at the top
- subcategories appear when selecting a parent category (e.g., Wildlife → Bears, Foxes, Seals)
- breadcrumbs show navigation path
- photo count for each category and subcategory

### Photo Display
- Click any photo to open in lightbox
- hover effects reveal photo info (title, location, date, rating)
- lazy loading for better performance
- responsive grid adapts to screen size

### Statistics Dashboard
- Total photos and total size
- date range and years active
- timeline chart: photos by month/year
- camera distribution: most used cameras
- lens distribution: most used lenses
- category distribution: pie chart
- rating distribution: star ratings chart
- top 5 lists with progress bars

## Customization
### Adding a New Photo
Place the photo in the appropriate folder: `Source/Category/Subcategory/photo.jpg`

Optionally add a rating: `echo "5" > "Source/Category/Subcategory/photo.rating"`

Regenerate gallery: `./build_gallery.sh Source/ Web/`

### Adding a New Category
```bash
# Simple
./scripts/add_category.sh Marine --icon "🌊" --name "Marine Life"

# With custom pattern
./scripts/add_category.sh Night --icon "🌙" --name "Night Photography" --pattern "Night,night,nocturnal"
```

### Modifying Themes
Themes are controlled via CSS variables in `index.html`. Dark theme is default, light theme toggles with `body.light` class.

### Customizing Image Sizes
Edit these variables in `build_gallery.sh`:
```bash
THUMB_SIZE="400"      # Thumbnail size in pixels
FULL_SIZE="1920"      # Full image max size
QUALITY="85"          # JPG quality (1-100)
```

## Deployment
### GitHub Pages
```bash
# Generate gallery
./build_gallery.sh Source/ Web/

# Deploy Web folder to gh-pages branch
cd Web
git init
git add .
git commit -m "Deploy gallery"
git push origin gh-pages --force
```

### Any Web Server
Copy the entire `Web/` folder to your server:
```bash
rsync -avz Web/ user@server.com:/var/www/html/
```

### Production with Admin Panel
For production, consider:

- use a proper database for sessions (Redis, PostgreSQL)
- add HTTPS with SSL certificates
- use a production WSGI server (gunicorn)
- set a strong admin password
- restrict API access with firewall rules

## Troubleshooting
### Images not processing
- Check ImageMagick: `convert --version`
- supported formats: `JPG`, `JPEG`, `PNG`
- check file permissions: `chmod 644 Source/**/*.jpg`
  
### Subcategories not showing
- Ensure folder structure: `Category/Subcategory/photo.jpg`
- check `gallery.json` for location field: `grep location Web/gallery.json`

### Statistics not updating
- Regenerate gallery with: `./build_gallery.sh Source/ Web/`
- check `Web/stats.json` is valid: `python3 -m json.tool Web/stats.json`

### Admin panel won't start
- Check Flask is installed: `pip3 install flask flask-cors`
- verify password is set: `echo $PHOTOGALLERY_ADMIN_PASSWORD`
- check port 5000 is not used by another service: `lsof -i :5000`

### JSON errors on macOS
- bash 3.2 doesn't support associative arrays. The script is already compatible.
- use included `perl` and `awk` for processing.

## License
MIT License – free for personal and commercial use.

Made with ❤️ for photographers

Questions or suggestions? Open an issue!