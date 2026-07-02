
#!/bin/bash
set -euo pipefail

echo "⚠️ Rolling back Moodle installation (safe & idempotent)"

MOODLE_PATH="/var/www/html"
MOODLE_CODE_FOLDER="/home/mia/repos/moodle"
MOODLE_DATA_ROOT="/var/moodledata"
NGINX_CONF="/etc/nginx/sites-available/moodle.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/moodle.conf"

# --- CRON JOB ---------------------------------------------------------------
echo "▶ Removing Moodle cron (if exists)"
sudo crontab -u www-data -l 2>/dev/null | grep -v "cron.php" | sudo crontab -u www-data - || true

# --- DATABASE ---------------------------------------------------------------
echo "▶ Removing Moodle database and user (if they exist)"
sudo mysql <<'EOF'
DROP DATABASE IF EXISTS moodle;
DROP USER IF EXISTS 'moodleuser'@'localhost';
FLUSH PRIVILEGES;
EOF

# --- NGINX CONFIG -----------------------------------------------------------
echo "▶ Removing nginx Moodle config"
if [ -L "$NGINX_ENABLED" ]; then
  sudo rm -f "$NGINX_ENABLED"
fi

if [ -f "$NGINX_CONF" ]; then
  sudo rm -f "$NGINX_CONF"
fi

sudo systemctl reload nginx 2>/dev/null || true

# --- FILESYSTEM -------------------------------------------------------------
echo "▶ Removing Moodle web files"
if [ -d "$MOODLE_PATH" ]; then
  sudo rm -rf "$MOODLE_PATH"
fi

echo "▶ Removing Moodle data directory"
if [ -d "$MOODLE_DATA_ROOT" ]; then
  sudo rm -rf "$MOODLE_DATA_ROOT"
fi

echo "▶ Removing cloned Moodle repository"
if [ -d "$MOODLE_CODE_FOLDER" ]; then
  sudo rm -rf "$MOODLE_CODE_FOLDER"
fi

echo "▶ Removing Composer cache"
sudo rm -rf /var/www/.cache/composer || true

# --- SERVICES ---------------------------------------------------------------
echo "▶ Stopping services"
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop php8.4-fpm 2>/dev/null || true
sudo systemctl stop mariadb 2>/dev/null || true

