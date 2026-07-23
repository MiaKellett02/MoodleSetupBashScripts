#!/bin/bash

clear
echo "=============================="
echo "Starting UoG plugin deployment"
echo "=============================="

cd "$HOME/repos/UoGPlugins/"
echo "Moving to $HOME/repos/UoGPlugins"

# Ensure the temp directory exists
if [ -d "temp" ]; then
    # Do nothing
    echo "                             "
else
    echo "Creating directory: $PWD/temp"
    mkdir "temp"
fi

uogpluginDir="$PWD"
mainDir="$PWD/temp"

# Process directories.
for dir in */; do
    dir="${dir%/}"

    # Ignore the temp directory
    if [ "$dir" = "temp" ]; then
        continue
    fi

    # Move to the temp dir.
    cd "$mainDir"

    # Split the directory into it's parts
    echo "Processing directory: $dir"
    IFS='_' read -ra parts <<< "$dir"

    # Process each part
    for part in "${parts[@]}"; do
        echo "  Part: $part"

	currentDir="$PWD"
        if [ -d "$part" ]; then
            echo "    Directory exists: $currentDir/$part"
	    cd "$part"
        else
            echo "    Creating Directory $currentDir/$part"
            mkdir "$part"
	    cd "$part"
        fi
    done
    
    # After processing each part, move everything from the directory to the bottom of the subdir.
    currentDir="$PWD"
    echo "    Moving all items from $uogpluginDir/$dir to $currentDir"
    echo "                                           "
    
    cp -r "$uogpluginDir/$dir"/* "$currentDir"

    cd "$mainDir"
done

#Code paths.
MOODLE_PATH="/var/www/html"
MOODLE_CODE_FOLDER="$HOME/repos/moodle"
MY_PLUGINS_PATH="$HOME/repos/UoGPlugins/temp"

# Update plugins repo (read‑only)
echo "Changing directory to plugins path"
echo $MY_PLUGINS_PATH
cd "$MY_PLUGINS_PATH"

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

read -p 'Remove temp directory? y/n: ' answer
if [ "$answer" = "y" ]; then
    cd ~/repos/UoGPlugins/
    echo "Removing directory $PWD/temp...."
    sudo rm -rf temp
else
    cd ~/repos/UoGPlugins/
    echo "Not removing temp directory...."
fi
