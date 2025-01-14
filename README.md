docker compose down -v && sudo rm -rf ../volume/ && docker compose up -d && sudo chown -R 65534:65534 ../volume/prometheus_data

sudo chown -R 65534:65534 ../volume/prometheus_data

http://localhost:9090/targets prometheus
 
http://localhost:3000 grafana

