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

# Master kurulumu
initialize_master() {
    log "Waiting for master..."
    wait_for_mysql "master"
    
    log "Initializing master..."
    mysql --defaults-file=/tmp/master.cnf -e "
        RESET MASTER;
        SET SQL_LOG_BIN=0;
        
        CREATE DATABASE IF NOT EXISTS redmine CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        
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
        GRANT ALL PRIVILEGES ON redmine.* TO 'redmine'@'%';
        
        FLUSH PRIVILEGES;
        SET SQL_LOG_BIN=1;"
    check_mysql_error
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
        RESET SLAVE;
        
        # Monitor kullanıcısını oluştur
        DROP USER IF EXISTS 'monitor'@'%';
        CREATE USER 'monitor'@'%' IDENTIFIED BY 'monitor';
        GRANT REPLICATION CLIENT ON *.* TO 'monitor'@'%';
        GRANT SELECT ON *.* TO 'monitor'@'%';
        GRANT PROCESS ON *.* TO 'monitor'@'%';
        
        CHANGE MASTER TO 
            MASTER_HOST='master',
            MASTER_USER='repl_user',
            MASTER_PASSWORD='repl_pass123',
            MASTER_AUTO_POSITION=1;
            
        START SLAVE;"
    check_mysql_error
    log "Slave$slave_num initialization completed"
}

# Ana akış
log "Starting setup process..."
initialize_master

for i in 1 2 3; do
    initialize_slave $i
done

log "Setup completed successfully!"