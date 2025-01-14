docker compose down -v && sudo rm -rf ../volume/ && docker compose up -d && sudo mkdir -p ../volume/{prometheus_data,grafana_data,loki_data,redmine-logs,redmine-plugins,redmine-themes,redmine-data,repos,backups} && sudo chown -R 65534:65534 ../volume/prometheus_data && sudo chmod -R 755 ../volume/prometheus_data && sudo chown -R 472:472 ../volume/grafana_data && sudo chown -R 10001:10001 ../volume/loki_data && sudo chown -R 999:999 ../volume/redmine-* && docker compose ps

sudo chown -R 65534:65534 ../volume/prometheus_data

http://localhost:9090/targets prometheus
 
http://localhost:3000 grafana

