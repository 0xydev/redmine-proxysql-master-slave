#!/bin/bash

# Önce container IP'lerini alalım ve değişkenlere atayalım
redmine1_ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' redmine1)
redmine2_ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' redmine2)
redmine3_ip=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' redmine3)

echo "Redmine Container IP'leri:"
echo "Redmine1: $redmine1_ip"
echo "Redmine2: $redmine2_ip"
echo "Redmine3: $redmine3_ip"
echo "----------------------------------------"

while true; do
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ==="
    echo "İstek gönderiliyor..."
    
    # İsteği gönder ve IP'yi al
    response_ip=$(curl -s -i http://localhost | grep -i "X-Served-By" | cut -d' ' -f2 | cut -d':' -f1)
    http_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
    
    # IP'ye göre hangi container olduğunu belirle
    if [ "$response_ip" = "$redmine1_ip" ]; then
        container="Redmine1"
    elif [ "$response_ip" = "$redmine2_ip" ]; then
        container="Redmine2"
    elif [ "$response_ip" = "$redmine3_ip" ]; then
        container="Redmine3"
    else
        container="Bilinmeyen"
    fi
    
    echo "HTTP Status: $http_status"
    echo "Yönlendirildi -> $container ($response_ip:3000)"
    echo "----------------------------------------"
    
    sleep 2
done