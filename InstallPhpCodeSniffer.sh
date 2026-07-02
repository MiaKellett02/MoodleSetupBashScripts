sudo apt update
sudo apt upgrade

# Download using curl
curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar
curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar

# Then test the downloaded PHARs
php phpcs.phar -h
php phpcbf.phar -h

# Add moodle specific
composer global config minimum-stability dev
composer global require moodlehq/moodle-cs
