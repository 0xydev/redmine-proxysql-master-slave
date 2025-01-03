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

for i in {1..10}
do
    echo "=== Test Iteration: $i ==="

    # 1. Insert a Test Issue
    echo "Inserting a test issue..."
    execute_mysql "
    USE $TEST_DB;
    INSERT INTO $TEST_TABLE (subject, description, project_id, tracker_id, status_id, priority_id, author_id, created_on, updated_on) 
    VALUES ('Test Issue $i', 'This is a test issue', 1, 1, 1, 2, 1, NOW(), NOW());
    "

    # 2. Retrieve Issues to Verify Routing
    echo "Retrieving issues..."
    execute_mysql "
    USE $TEST_DB;
    SELECT id, subject, created_on FROM $TEST_TABLE ORDER BY id DESC LIMIT 5;
    "

    # 3. Check ProxySQL Statistics
    echo "Fetching ProxySQL statistics..."
    docker compose exec proxysql mysql -h 127.0.0.1 -P 6032 -uadmin -padmin -e "
    SELECT hostgroup, srv_host, status, ConnUsed, ConnFree, ConnOK, ConnERR 
    FROM stats_mysql_connection_pool WHERE hostgroup IN (10, 20);
    
    SELECT rule_id, destination_hostgroup, hits 
    FROM stats_mysql_query_rules ORDER BY rule_id;
    "

    # 4. Check Replication Status on Slaves
    echo "Checking replication status on slaves..."
    for slave in {1..3}; do
        echo "=== Slave$slave Status ==="
        docker compose exec slave$slave mysql -uroot -proot_password -e "SHOW SLAVE STATUS\G" | grep -E "Slave_IO_Running:|Slave_SQL_Running:|Seconds_Behind_Master:"
    done

    echo "=== Test Iteration: $i Completed ==="
    echo "-------------------------------------"
    sleep 2
done

echo "=== ProxySQL Routing Test Completed ==="