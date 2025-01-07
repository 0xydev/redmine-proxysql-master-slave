#!/bin/bash

# Yapılandırma
MIN_INSTANCES=3
MAX_INSTANCES=10
CPU_THRESHOLD=80  # %
MEMORY_THRESHOLD=85  # %
CHECK_INTERVAL=10  # 10 saniyede bir kontrol
SCALE_COOLDOWN=120  # 2 dakika cooldown
LAST_SCALE_ACTION=0

# Log fonksiyonu
log() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $@"
}

# Container sayısını al
get_container_count() {
    docker ps -f name=redmine[0-9] --format '{{.Names}}' | wc -l
}

# CPU kullanımını kontrol et
check_cpu_usage() {
    local container=$1
    local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" $container | sed 's/%//')
    echo "${cpu_usage:-0}"
}

# Memory kullanımını kontrol et
check_memory_usage() {
    local container=$1
    local memory_usage=$(docker stats --no-stream --format "{{.MemPerc}}" $container | sed 's/%//')
    echo "${memory_usage:-0}"
}

# ProxySQL metriklerini kontrol et
get_proxysql_metrics() {
    local metrics=$(docker exec proxysql mysql -h127.0.0.1 -P6032 -uadmin -padmin -N -e "
        SELECT hostgroup, srv_host, status, ConnUsed, ConnFree, ConnOK, ConnERR, Queries, Latency_us 
        FROM stats_mysql_connection_pool 
        WHERE status='ONLINE'")
    echo "$metrics"
}

# Detaylı container metriklerini göster
show_container_metrics() {
    log "=== Container Metrics ==="
    for container in $(docker ps -f name=redmine[0-9] --format '{{.Names}}'); do
        local cpu=$(check_cpu_usage $container)
        local mem=$(check_memory_usage $container)
        log "$container: CPU: ${cpu}%, Memory: ${mem}%"
    done
}

# ProxySQL metriklerini göster
show_proxysql_metrics() {
    log "=== ProxySQL Metrics ==="
    local metrics=$(get_proxysql_metrics)
    echo "$metrics" | while read -r line; do
        if [ ! -z "$line" ]; then
            log "Connection Pool: $line"
        fi
    done
}

# Yeni instance oluştur
scale_up() {
    local current_count=$(get_container_count)
    local new_instance=$((current_count + 1))
    
    if [ $current_count -lt $MAX_INSTANCES ]; then
        log "⬆️ Scaling UP: Creating redmine$new_instance"
        docker compose up -d --no-deps --scale "redmine$new_instance=1"
        LAST_SCALE_ACTION=$(date +%s)
    else
        log "🚫 Cannot scale up: Maximum instance limit ($MAX_INSTANCES) reached"
    fi
}

# Instance sil
scale_down() {
    local current_count=$(get_container_count)
    
    if [ $current_count -gt $MIN_INSTANCES ]; then
        local container_to_remove="redmine$current_count"
        log "⬇️ Scaling DOWN: Removing $container_to_remove"
        docker compose stop $container_to_remove
        docker compose rm -f $container_to_remove
        LAST_SCALE_ACTION=$(date +%s)
    else
        log "🚫 Cannot scale down: Minimum instance limit ($MIN_INSTANCES) reached"
    fi
}

# Ana döngü
log "🚀 Starting Auto-scale Monitor..."
log "Configuration: MIN=$MIN_INSTANCES, MAX=$MAX_INSTANCES, CPU_THRESHOLD=$CPU_THRESHOLD%, MEM_THRESHOLD=$MEMORY_THRESHOLD%"
log "Check Interval: ${CHECK_INTERVAL}s, Cooldown: ${SCALE_COOLDOWN}s"

while true; do
    current_time=$(date +%s)
    scale_cooldown_passed=$(( $current_time - $LAST_SCALE_ACTION ))
    
    # Container metriklerini topla
    total_cpu_usage=0
    total_memory_usage=0
    container_count=0
    
    show_container_metrics
    show_proxysql_metrics
    
    for container in $(docker ps -f name=redmine[0-9] --format '{{.Names}}'); do
        cpu_usage=$(check_cpu_usage $container)
        memory_usage=$(check_memory_usage $container)
        
        total_cpu_usage=$(echo "$total_cpu_usage + $cpu_usage" | bc)
        total_memory_usage=$(echo "$total_memory_usage + $memory_usage" | bc)
        container_count=$((container_count + 1))
    done
    
    # Ortalama hesapla
    avg_cpu_usage=$(echo "scale=2; $total_cpu_usage / $container_count" | bc)
    avg_memory_usage=$(echo "scale=2; $total_memory_usage / $container_count" | bc)
    
    log "📊 AVERAGES - CPU: ${avg_cpu_usage}%, Memory: ${avg_memory_usage}%"
    
    if [ $scale_cooldown_passed -ge $SCALE_COOLDOWN ]; then
        # Scale kararı
        if (( $(echo "$avg_cpu_usage > $CPU_THRESHOLD" | bc -l) )) || \
           (( $(echo "$avg_memory_usage > $MEMORY_THRESHOLD" | bc -l) )); then
            scale_up
        elif (( $(echo "$avg_cpu_usage < $((CPU_THRESHOLD/2))" | bc -l) )) && \
             (( $(echo "$avg_memory_usage < $((MEMORY_THRESHOLD/2))" | bc -l) )); then
            scale_down
        else
            log "✅ No scaling action needed"
        fi
    else
        log "⏳ Cooling down... $(($SCALE_COOLDOWN - $scale_cooldown_passed))s remaining"
    fi
    
    log "-------------------------------------------"
    sleep $CHECK_INTERVAL
done