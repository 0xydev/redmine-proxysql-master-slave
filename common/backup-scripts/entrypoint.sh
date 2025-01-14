#!/bin/sh
set -ex

# Cron için gerekli dosyayı doğru yere kopyala
cp /scripts/root-cron /etc/crontabs/root

# Foreground (-f) modda cron başlat; -l 2 ile log detay seviyesi
crond -f -l 2
