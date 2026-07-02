
#!/bin/bash
set -euo pipefail

echo "🔥 FULL MOODLE + STACK UNINSTALL (idempotent)"
sh uninstallmoodlesetup.sh
sudo rm -rf /home/mia/repos/moodle

# -------------------------------------------------------------------
# Paths / names used by the installer
# -------------------------------------------------------------------
MOODLE_PATH="/var/www/html"
MOODLE_DATA_ROOT="/var/moodledata"
MOODLE_REPO="$HOME/repos/moodle"

NGINX_CONF="/etc/nginx/sites-available/moodle.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/moodle.conf"

PHP_VERSION="8.5"

DB_NAME="moodle"
DB_USER="moodleuser"

# -------------------------------------------------------------------
# Helper: remove package if installed
# -------------------------------------------------------------------
purge_if_installed() {
  local pkg="$1"
  if dpkg -s "$pkg" &>/dev/null; then
    echo "🧹 Purging package: $pkg"
    sudo apt-get purge -y "$pkg"
  else
    echo "✔ Package already absent: $pkg"
  fi
}

# -------------------------------------------------------------------
# CRON
# -------------------------------------------------------------------
echo "🕒 Removing Moodle cron job (if present)"
if sudo crontab -u www-data -l &>/dev/null; then
  sudo crontab -u www-data -l \
    | grep -v "cron.php" \
    | sudo crontab -u www-data -
fi

# -------------------------------------------------------------------
# DATABASE
# -------------------------------------------------------------------
echo "🗄 Removing database and user (if present)"
if systemctl is-active --quiet mariadb || systemctl is-active --quiet mysql; then
  sudo mysql <<EOF
DROP DATABASE IF EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
else
  echo "✔ MariaDB/MySQL not running or already removed"
fi

# -------------------------------------------------------------------
# NGINX
# -------------------------------------------------------------------
echo "🌐 Removing nginx config"

[ -L "$NGINX_ENABLED" ] && sudo rm -f "$NGINX_ENABLED"
[ -f "$NGINX_CONF" ] && sudo rm -f "$NGINX_CONF"

sudo systemctl reload nginx 2>/dev/null || true

# -------------------------------------------------------------------
# FILESYSTEM
# -------------------------------------------------------------------
echo "🗑 Removing Moodle files and data"

[ -d "$MOODLE_PATH" ] && sudo rm -rf "$MOODLE_PATH"
[ -d "$MOODLE_DATA_ROOT" ] && sudo rm -rf "$MOODLE_DATA_ROOT"
[ -d "$MOODLE_REPO" ] && sudo rm -rf "$MOODLE_REPO"

sudo rm -rf /var/www/.cache/composer || true

# -------------------------------------------------------------------
# SERVICES
# -------------------------------------------------------------------
echo "🛑 Stopping services (if running)"

sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop php${PHP_VERSION}-fpm 2>/dev/null || true
sudo systemctl stop mariadb 2>/dev/null || true

# -------------------------------------------------------------------
# PACKAGES — EVERYTHING THE INSTALLER TOUCHED
# -------------------------------------------------------------------
echo "📦 Purging packages"

PACKAGES=(
  nginx
  mariadb-server mariadb-client
  php${PHP_VERSION}-fpm
  php${PHP_VERSION}-cli
  php${PHP_VERSION}-curl
  php${PHP_VERSION}-zip
  php${PHP_VERSION}-gd
  php${PHP_VERSION}-xml
  php${PHP_VERSION}-intl
  php${PHP_VERSION}-mbstring
  php${PHP_VERSION}-xmlrpc
  php${PHP_VERSION}-soap
  php${PHP_VERSION}-bcmath
  php${PHP_VERSION}-exif
  php${PHP_VERSION}-ldap
  php${PHP_VERSION}-mysql
  unzip
  graphviz
  aspell
  git
  clamav
  ghostscript
  composer
  gh
  ufw
  nano
)

for pkg in "${PACKAGES[@]}"; do
  purge_if_installed "$pkg"
done

# -------------------------------------------------------------------
# PHP & WEB LEFTOVERS
# -------------------------------------------------------------------
echo "🧹 Removing leftover language runtimes"

sudo rm -rf /etc/php/${PHP_VERSION} || true
sudo rm -rf /var/run/php || true
sudo rm -rf /var/lib/php || true

# -------------------------------------------------------------------
# GITHUB CLI APT REPO
# -------------------------------------------------------------------
echo "🔑 Removing GitHub CLI APT repo"

sudo rm -f /etc/apt/sources.list.d/github-cli.list
sudo rm -f /etc/apt/keyrings/githubcli-archive-keyring.gpg

# -------------------------------------------------------------------
# FINAL CLEANUP
# -------------------------------------------------------------------
echo "🧼 Final apt cleanup"

sudo apt-get autoremove -y
sudo apt-get autoclean -y
sudo apt-get update

# -------------------------------------------------------------------
echo "✅ COMPLETE: system returned to pre‑Moodle state"
echo "You can now safely re‑run the installer."
