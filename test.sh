#!/bin/bash

while true; do
    echo -e "\n=== $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo -e "\nSorgu Dağılımı ve Yönlendirme İstatistikleri:"
    docker compose exec proxysql mysql -h 127.0.0.1 -P 6032 -uadmin -padmin -e "
    SELECT hostgroup, digest_text, count_star as hit_count, sum_time as total_time_ms 
    FROM stats_mysql_query_digest 
    WHERE digest_text IS NOT NULL 
    ORDER BY hostgroup, count_star DESC;"

    echo -e "\nSunucu Bağlantı Havuzu Durumu:"
    docker compose exec proxysql mysql -h 127.0.0.1 -P 6032 -uadmin -padmin -e "
    SELECT hostgroup, srv_host, status, ConnUsed, ConnFree, ConnOK, ConnERR 
    FROM stats_mysql_connection_pool 
    WHERE hostgroup IN (10, 20);"

    sleep 5
done