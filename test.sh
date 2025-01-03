#!/bin/bash

# Script to Test ProxySQL Routing

# Variables
PROXYSQL_HOST="proxysql"
PROXYSQL_PORT=6033
PROXYSQL_USER="redmine"
PROXYSQL_PASSWORD="redmine_password"
TEST_DB="redmine"
TEST_TABLE="issues"

# Function to execute MySQL commands via ProxySQL
execute_mysql() {
    local query="$1"
    docker compose exec proxysql mysql -h "$PROXYSQL_HOST" -P "$PROXYSQL_PORT" -u "$PROXYSQL_USER" -p"$PROXYSQL_PASSWORD" -e "$query"
}

echo "=== ProxySQL Routing Test Started ==="

for i in {1..3}
do


    # 2. Retrieve Issues to Verify Routing
    echo "Retrieving issues..."
    execute_mysql "
    USE $TEST_DB;
    SELECT * FROM users;
    "

    # 3. Check ProxySQL Statistics
    echo "Fetching ProxySQL statistics..."
    docker compose exec proxysql mysql -h 127.0.0.1 -P 6032 -uadmin -padmin -e "
    SELECT hostgroup, srv_host, status, ConnUsed, ConnFree, ConnOK, ConnERR 
    FROM stats_mysql_connection_pool WHERE hostgroup IN (10, 20);
    
    SELECT rule_id, destination_hostgroup, hits 
    FROM stats_mysql_query_rules ORDER BY rule_id;
    "

done

echo "=== ProxySQL Routing Test Completed ==="