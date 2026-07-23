#!/bin/bash

MOODLE_PATH="/var/www/html"
MOODLE_CODE_FOLDER="$HOME/repos/moodle"
MOODLE_VERSION_TO_UPGRADE_TO="MOODLE_501_STABLE"

cd "$MOODLE_CODE_FOLDER"
git checkout $MOODLE_VERSION_TO_UPGRADE_TO 2>/dev/null || git checkout -b $MOODLE_VERSION_TO_UPGRADE_TO origin/$MOODLE_VERSION_TO_UPGRADE_TO && git reset --hard origin/$MOODLE_VERSION_TO_UPGRADE_TO

# Commit local changes if any
if ! git diff --quiet; then
  git add .
  git commit -m "Local changes before Moodle upgrade"
fi

# Pull latest code

# git reset --hard HEAD
# git clean -fd
# git checkout -b MOODLE_501_STABLE origin/MOODLE_501_STABLE
git pull

# Enable maintenance BEFORE code sync
sudo -u www-data php "$MOODLE_PATH/admin/cli/maintenance.php" --enable

# Sync code
sudo rsync -av --delete \
  --exclude=config.php \
  $MOODLE_CODE_FOLDER/ $MOODLE_PATH/

# Ensure correct ownership
sudo chown -R www-data:www-data $MOODLE_PATH

# Run Moodle upgrade
cd "$MOODLE_PATH"
sudo -u www-data php admin/cli/upgrade.php --non-interactive

# Disable maintenance
sudo -u www-data php admin/cli/maintenance.php --disable

# Run Cron
php admin/cli/cron.php
