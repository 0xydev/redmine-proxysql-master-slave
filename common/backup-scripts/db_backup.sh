#!/bin/sh
set -ex

BACKUP_DATE=$(date +"%Y%m%d_%H%M")
BACKUP_DIR="/db_backups"

# MySQL bağlantı bilgileri: backup_user + backup_pass
HOST="${MYSQL_HOST:-proxysql}"
PORT="${MYSQL_PORT:-6033}"
USER="${MYSQL_USER:-backup_user}"
PASS="${MYSQL_PASSWORD:-backup_pass}"
DB="${MYSQL_DATABASE:-redmine}"

# Yedek alma
mysqldump -h "$HOST" -P "$PORT" -u"$USER" -p"$PASS" "$DB" \
> "${BACKUP_DIR}/redmine_${BACKUP_DATE}.sql"

# Sıkıştır
gzip "${BACKUP_DIR}/redmine_${BACKUP_DATE}.sql"

echo "[`date '+%Y-%m-%d %H:%M:%S'`] Backup complete: redmine_${BACKUP_DATE}.sql.gz"
