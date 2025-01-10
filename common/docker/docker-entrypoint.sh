#!/bin/bash
set -e

# Log dizinini oluştur
mkdir -p "/var/log/redmine/${CONTAINER_NAME}"
chown -R redmine:redmine /var/log/redmine

# Migrations dosyasını kaldır
rm -f /usr/src/redmine/config/initializers/migrations.rb

# Rails sunucusunu başlat
exec "$@" 