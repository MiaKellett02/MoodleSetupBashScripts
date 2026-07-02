#!/bin/bash
set -euo pipefail

# Set your domain name or IP address as a temporary variable as it will be needed several times in the installation
PROTOCOL="http://";
read -p "Enter the web address (without the http:// prefix, eg domain name mymoodle123.com or IP address 192.168.1.1.): " WEBSITE_ADDRESS

MOODLE_PATH="/var/www/html"
MOODLE_CODE_FOLDER="/home/mia/repos/moodle"
MOODLE_DATA_FOLDER="/var/moodledata/"
sudo mkdir -p $MOODLE_PATH
sudo mkdir -p $MOODLE_DATA_FOLDER

# Refresh and download latest versions of all packages
sudo apt-get update && sudo apt upgrade -y

# Get php-fpn and required php extensions using the package manager apt-get
sudo apt-get install -y php8.5-fpm php8.5-cli php8.5-curl php8.5-zip php8.5-gd php8.5-xml php8.5-intl  php8.5-mbstring php8.5-xmlrpc php8.5-soap php8.5-bcmath php8.5-exif php8.5-ldap php8.5-mysql
sudo systemctl start php8.5-fpm

# Database and packgages required by Moodle
sudo apt-get install -y unzip mariadb-server mariadb-client ufw nano graphviz aspell git clamav ghostscript composer
sudo systemctl start mariadb

# Ensure GitHub CLI is installed and up to date.
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y
sudo apt update
sudo apt install gh

#Install and setup the web server.
sudo apt-get install -y nginx

# Set up the configuration file including the fallback required for the router
# Using tee allows the file to be written in a single (rather long command). This could also been have done with a text editor.
# Be sure to copy and paste entire block from "sudo" to "EOF"
sudo tee /etc/nginx/sites-available/moodle.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $WEBSITE_ADDRESS www.$WEBSITE_ADDRESS;
    root $MOODLE_PATH/public;
    index index.php index.html index.htm;
    client_max_body_size 100M;

    location / {
        try_files \$uri \$uri/ /index.php?\$args /r.php;
    }

    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_pass unix:/var/run/php/php8.5-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

sudo systemctl start nginx

# Recognise the new config file
if [ ! -L /etc/nginx/sites-enabled/moodle.conf ]; then
  sudo ln -s /etc/nginx/sites-available/moodle.conf /etc/nginx/sites-enabled/moodle.conf
fi

sudo systemctl reload nginx

# Make necessary changes to the php configuration required by Moodle
# Using sed finds and replaces text. This could have been done in a test editor
sudo sed -i 's/^;max_input_vars =.*/max_input_vars = 5000/' /etc/php/8.5/fpm/php.ini
sudo sed -i 's/^;max_input_vars =.*/max_input_vars = 5000/' /etc/php/8.5/cli/php.ini
sudo sed -i 's/^post_max_size =.*/post_max_size = 256M/' /etc/php/8.5/fpm/php.ini
sudo sed -i 's/^post_max_size =.*/post_max_size = 256M/' /etc/php/8.5/cli/php.ini
sudo sed -i 's/^upload_max_filesize =.*/upload_max_filesize = 256M/' /etc/php/8.5/fpm/php.ini
sudo sed -i 's/^upload_max_filesize =.*/upload_max_filesize = 256M/' /etc/php/8.5/cli/php.ini
sudo systemctl reload php8.5-fpm

# Clone to the Moodle code folder
sudo git clone -b v5.1.0 https://github.com/moodle/moodle.git $MOODLE_CODE_FOLDER
sudo chmod 755 $MOODLE_CODE_FOLDER
sudo chown -R www-data:www-data $MOODLE_CODE_FOLDER
sudo chmod 755 $MOODLE_PATH
sudo chown -R www-data:www-data $MOODLE_CODE_FOLDER

cd  $MOODLE_CODE_FOLDER
#sudo chown -R www-data:www-data vendor
sudo chmod -R 755 $MOODLE_CODE_FOLDER

# Copy the moodle code folder to the moodle folder.
sudo cp -r $MOODLE_CODE_FOLDER/. $MOODLE_PATH
sudo chown -R www-data:www-data $MOODLE_PATH
sudo chmod -R 755 $MOODLE_PATH

#  Create the moodledata directory outside your web server's document root
sudo mkdir -p $MOODLE_DATA_FOLDER/moodledata

# Set the webserver as the owner and group recursively ( for both the files and contents)
sudo chown -R www-data:www-data $MOODLE_DATA_FOLDER/moodledata

#  Set the  moodledata directory permissions so only the web server can read, write, and access them.
sudo find $MOODLE_DATA_FOLDER/moodledata -type d -exec chmod 700 {} \;

# Set the  moodledata file permissions so only the web server can read and write them.
sudo find $MOODLE_DATA_FOLDER/moodledata -type f -exec chmod 600 {} \;

# Call the cron.php in the moodle admin directory to run every minute.
echo "* * * * * /usr/bin/php $MOODLE_PATH/admin/cli/cron.php >/dev/null 2>&1" | sudo crontab -u www-data -

# Setup the moodle database
MYSQL_MOODLEUSER_PASSWORD=$(openssl rand -base64 12)

sudo mysql -e "CREATE DATABASE IF NOT EXISTS moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

sudo mysql -e "CREATE USER IF NOT EXISTS 'moodleuser'@'localhost' IDENTIFIED BY '${MYSQL_MOODLEUSER_PASSWORD}';"

sudo mysql -e "GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';"

sudo mysql -e "FLUSH PRIVILEGES;"

# Display credentials
echo "======================================"
echo "Moodle DB setup complete"
echo "Database: moodle"
echo "Username: moodleuser"
echo "Password: ${MYSQL_MOODLEUSER_PASSWORD}"
echo "======================================"


MOODLE_ADMIN_PASSWORD=$(openssl rand -base64 8)
echo "MOODLE ADMIN PASSWORD: $MOODLE_ADMIN_PASSWORD , MYSQL_MOODLE_USER_PASSWORD: $MYSQL_MOODLEUSER_PASSWORD"
sudo chmod -R 0777 $MOODLE_PATH
cd $MOODLE_PATH

sudo -u www-data /usr/bin/php $MOODLE_PATH/admin/cli/install.php \
--non-interactive \
--agree-license \
--lang=en \
--wwwroot="$PROTOCOL$WEBSITE_ADDRESS" \
--dataroot="$MOODLE_DATA_FOLDER/moodledata" \
--dbtype=mariadb \
--dbhost=localhost \
--dbname=moodle \
--dbuser=moodleuser \
--dbpass="$MYSQL_MOODLEUSER_PASSWORD" \
--adminuser=admin \
--adminpass="$MOODLE_ADMIN_PASSWORD" \
--fullname="Moodle Site" \
--shortname="Moodle"


echo "$PROTOCOL"
echo "$WEBSITE_ADDRESS"
echo "$MOODLE_ADMIN_PASSWORD"

echo "Moodle installation completed successfully. You can now log on to your new Moodle at ${PROTOCOL}${WEBSITE_ADDRESS} as admin with $MOODLE_ADMIN_PASSWORD and complete your site registration"
echo "Remember to change the admin email, name and shortname using the browser in your new Moodle"
sudo find $MOODLE_PATH -type d -exec chmod 755 {} \;
sudo find $MOODLE_PATH -type f -exec chmod 644 {} \;


sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;


sudo nginx -t
sudo systemctl reload nginx

chmod o+rx /var
chmod o+rx /var/www
chmod o+rx /var/www/html

sudo nginx -t
sudo systemctl reload nginx

# nginx needs slash arguments set
sudo sed -i "/require_once(__DIR__ . '\/lib\/setup.php');/i \$CFG->slasharguments = false;" /var/www/html/moodle/config.php
