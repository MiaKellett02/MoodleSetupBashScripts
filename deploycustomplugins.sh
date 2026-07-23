#!/bin/bash

#Code paths.
MOODLE_PATH="/var/www/html"
MOODLE_CODE_FOLDER="$HOME/repos/moodle"
MY_PLUGINS_PATH="/home/mia/repos/MyPlugins"

# Update plugins repo (read‑only)
echo "Changing directory to plugins path"
echo $MY_PLUGINS_PATH
cd "$MY_PLUGINS_PATH"

# Commit local changes if any
if ! git diff --quiet; then
  git add .
  git commit -m "Local changes before pulling latest plugin code"
fi

# Pull latest code
git pull

# Copy plugins into correct Moodle locations.
# In this case the plugins path already has the correct structure for the public directory.
echo "Starting sync to moodle git code folder"
echo "$MY_PLUGINS_PATH/"
echo "to"
echo "$MOODLE_CODE_FOLDER/public/"
echo "======================================="
sudo rsync -av "$MY_PLUGINS_PATH/" "$MOODLE_CODE_FOLDER/public/"
echo "Sync to moodle git code folder finished"
echo "======================================="

# Enable maintenance FIRST
sudo -u www-data php "$MOODLE_PATH/admin/cli/maintenance.php" --enable

#Copy over the plugins to the moodle repo directory then sync to the web directory
sudo rsync -av $MOODLE_CODE_FOLDER/ $MOODLE_PATH/ >/dev/null
sudo chown -R www-data:www-data $MOODLE_PATH

#Change directory to web root then run the moodle upgrade.php script
echo "Changing directory to moodle path and running the upgrade script"
cd $MOODLE_PATH
sudo -u www-data php admin/cli/upgrade.php
sudo -u www-data php admin/cli/maintenance.php --disable
sudo -u www-data php admin/cli/checks.php
