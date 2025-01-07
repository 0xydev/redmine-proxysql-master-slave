#!/bin/bash
set -ex

# Sidekiq'i arka planda başlatıyoruz
echo "==> Starting Sidekiq..."
bundle exec sidekiq -C config/sidekiq.yml -e production &

# Puma (Redmine) sunucusunu ön planda başlatıyoruz
echo "==> Starting Redmine (Puma) server..."
bundle exec rails server -u puma -b 0.0.0.0 -e production

# Arka planda çalışan süreçlerin sonlanmasını bekle
wait -n
