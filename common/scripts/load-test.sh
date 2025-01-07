#!/bin/bash

# Log fonksiyonu
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $@"
}

# Load test başlat
start_load_test() {
    log "Starting k6 load test..."
    
    # k6 container'ı oluştur ve başlat
    docker run --rm \
        --name k6-load-test \
        --network mysql_network \
        -v ${PWD}/test.js:/test.js \
        grafana/k6:latest \
        run /test.js
}

# Metrikleri izle
monitor_metrics() {
    while true; do
        log "=== System Metrics During Load Test ==="
        
        # Redmine containerlarının durumu
        for container in $(docker ps -f name=redmine[0-9] --format '{{.Names}}'); do
            stats=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $container)
            log "$stats"
        done
        
        # ProxySQL metrikleri
        log "=== ProxySQL Metrics ==="
        docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -e "
            SELECT hostgroup, srv_host, status, ConnUsed, ConnFree, Queries, Latency_us 
            FROM stats_mysql_connection_pool 
            WHERE status='ONLINE';"
        
        sleep 5
    done
}

# Ana fonksiyon
main() {
    log "🚀 Starting Load Test Suite"
    
    # Monitoring'i arka planda başlat
    monitor_metrics &
    MONITOR_PID=$!
    
    # Load testi başlat
    start_load_test
    
    # Test bitince monitoring'i durdur
    kill $MONITOR_PID
    
    log "✅ Load Test Completed"
}

# Scripti çalıştır
main