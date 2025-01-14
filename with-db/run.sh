#!/bin/bash
set -x
set -e

# Log fonksiyonu
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@"
}

# Hata kontrolü
check_mysql_error() {
    if [ $? -ne 0 ]; then
        log "MySQL error occurred. Exiting..."
        exit 1
    fi
}

# MySQL hazır olana kadar bekle
wait_for_mysql() {
    local host=$1
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if mysqladmin ping -h"$host" -uroot -proot_password >/dev/null 2>&1; then
            log "$host is ready"
            return 0
        fi
        log "Waiting for $host to be ready... (attempt $attempt/$max_attempts)"
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log "Timeout waiting for $host"
    return 1
}

# Config dosyaları oluştur
cat << EOF > /tmp/master.cnf
[client]
host=master
user=root
password=$MYSQL_ROOT_PASSWORD
EOF

for i in 1 2 3; do
    cat << EOF > /tmp/slave$i.cnf
[client]
host=slave$i
user=root
password=$MYSQL_ROOT_PASSWORD
EOF
done

# Database durumunu kontrol et
check_db_initialized() {
    local status=$(mysql --defaults-file=/tmp/master.cnf -N -s -e "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema='redmine' 
        AND table_name='schema_migrations_status';")
    
    if [ "$status" -eq "1" ]; then
        local migration_status=$(mysql --defaults-file=/tmp/master.cnf -N -s -e "
            SELECT status FROM redmine.schema_migrations_status WHERE id=1;")
        if [ "$migration_status" = "completed" ]; then
            return 0
        fi
    fi
    return 1
}

# Master kurulumu
initialize_master() {
    log "Waiting for master..."
    wait_for_mysql "master"
    
    log "Initializing master..."
    mysql --defaults-file=/tmp/master.cnf -e "
        RESET MASTER;
        SET SQL_LOG_BIN=0;
        
        # Monitor kullanıcısını oluştur
        DROP USER IF EXISTS 'monitor'@'%';
        CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitor';
        GRANT REPLICATION CLIENT ON *.* TO 'monitor'@'%';
        GRANT SELECT ON *.* TO 'monitor'@'%';
        GRANT SUPER ON *.* TO 'monitor'@'%';
        GRANT PROCESS ON *.* TO 'monitor'@'%';
        
        # Replikasyon kullanıcısını oluştur
        DROP USER IF EXISTS 'repl_user'@'%';
        CREATE USER 'repl_user'@'%' IDENTIFIED BY 'repl_pass123';
        GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%';
        
        # Redmine kullanıcısını oluştur
        DROP USER IF EXISTS 'redmine'@'%';
        CREATE USER 'redmine'@'%' IDENTIFIED BY 'redmine_password';
        GRANT ALL PRIVILEGES ON *.* TO 'redmine'@'%';

        # ----- YENİ: Backup kullanıcısı oluştur -----
        DROP USER IF EXISTS 'backup_user'@'%';
        CREATE USER 'backup_user'@'%' IDENTIFIED BY 'backup_pass';
        GRANT SELECT, LOCK TABLES, SHOW VIEW, TRIGGER, RELOAD, REPLICATION CLIENT ON *.* TO 'backup_user'@'%';
        
        FLUSH PRIVILEGES;
        SET SQL_LOG_BIN=1;"
    check_mysql_error

    # Redmine database oluştur
    mysql --defaults-file=/tmp/master.cnf -e "CREATE DATABASE IF NOT EXISTS redmine CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    check_mysql_error
    
    # Dump varsa import et ve migration durumunu işaretle
    if [ -f "/redmine-dump.sql" ]; then
        log "Found redmine-dump.sql, importing..."
        mysql --defaults-file=/tmp/master.cnf redmine < /redmine-dump.sql
        check_mysql_error
        
        # Migration durumunu kaydet
        mysql --defaults-file=/tmp/master.cnf -e "
            USE redmine;
            CREATE TABLE IF NOT EXISTS schema_migrations_status (
                id INT PRIMARY KEY AUTO_INCREMENT,
                status VARCHAR(50),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            INSERT INTO schema_migrations_status (status) 
            VALUES ('completed') 
            ON DUPLICATE KEY UPDATE status='completed', created_at=CURRENT_TIMESTAMP;"
        check_mysql_error
        log "Dump import completed and migration status set"
    else
        log "No redmine-dump.sql found. Please make sure dump file exists!"
        exit 1
    fi
    
    log "Master initialization completed"
}

# Slave kurulumu
initialize_slave() {
    local slave_num=$1
    log "Waiting for slave$slave_num..."
    wait_for_mysql "slave$slave_num"
    
    log "Initializing slave$slave_num..."
    mysql --defaults-file=/tmp/slave$slave_num.cnf -e "
        STOP SLAVE;
        RESET SLAVE ALL;
        
        # Monitor kullanıcısını oluştur
        DROP USER IF EXISTS 'monitor'@'%';
        CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitor';
        GRANT REPLICATION CLIENT ON *.* TO 'monitor'@'%';
        GRANT SELECT ON *.* TO 'monitor'@'%';
        GRANT PROCESS ON *.* TO 'monitor'@'%';
        
        # Redmine kullanıcısını oluştur
        DROP USER IF EXISTS 'redmine'@'%';
        CREATE USER 'redmine'@'%' IDENTIFIED BY 'redmine_password';
        GRANT ALL PRIVILEGES ON *.* TO 'redmine'@'%';

        # ----- YENİ: Backup kullanıcısı oluştur -----
        DROP USER IF EXISTS 'backup_user'@'%';
        CREATE USER 'backup_user'@'%' IDENTIFIED BY 'backup_pass';
        GRANT SELECT, LOCK TABLES, SHOW VIEW, TRIGGER, RELOAD, REPLICATION CLIENT ON *.* TO 'backup_user'@'%';
        
        # Replikasyon ayarlarını yap
        CHANGE MASTER TO 
            MASTER_HOST='master',
            MASTER_USER='repl_user',
            MASTER_PASSWORD='repl_pass123',
            MASTER_AUTO_POSITION=1;
        
        FLUSH PRIVILEGES;
        
        # Replikasyonu başlat
        START SLAVE;
        
        # Read-only ayarlarını aktifleştir
        SET GLOBAL read_only=1;
        SET GLOBAL super_read_only=1;"
    check_mysql_error
    
    # Slave durumunun stabil olması için bekle
    sleep 5
    
    # Slave durumunu kontrol et ve logla
    log "Checking status of slave$slave_num..."
    mysql --defaults-file=/tmp/slave$slave_num.cnf -e "
        SHOW SLAVE STATUS\G;
        SHOW VARIABLES LIKE '%read_only%';"
    
    # Replikasyon durumunu kontrol et
    local slave_status=$(mysql --defaults-file=/tmp/slave$slave_num.cnf -N -e "
        SELECT 
            Slave_IO_Running = 'Yes' AND 
            Slave_SQL_Running = 'Yes' AND 
            @@global.read_only = 1 AND 
            @@global.super_read_only = 1
        FROM performance_schema.replication_applier_status 
        LIMIT 1;")
    
    if [ "$slave_status" != "1" ]; then
        log "WARNING: Slave$slave_num might not be properly configured. Please check the logs."
    else
        log "Slave$slave_num initialization completed successfully"
    fi
}

# Ana akış
log "Starting setup process with database dump..."
initialize_master

for i in 1 2 3; do
    initialize_slave $i
done

log "Checking replication status..."
sleep 10

for i in 1 2 3; do
    mysql --defaults-file=/tmp/slave$i.cnf -e "SHOW SLAVE STATUS\G"
done

log "Setup completed successfully!"