#!/bin/bash
 
# MySQL instance bilgilerini içeren bir dizi
instances=(
  ["master" "redmine" "redmine_password" "redmine"],
  ["slave1" "redmine" "redmine_password" "redmine"],
  ["slave2" "redmine" "redmine_password" "redmine"],
  ["slave3" "redmine" "redmine_password" "redmine"]
)
 
# Çalıştırılacak SQL sorgusu
 
# Her bir instance için sorguyu çalıştır
docker run -d --name test --network mysql_network mysql:5.7 tail -f /dev/null
for instance in "${instances[@]}"; do
  host=${instance[0]}
  user=${instance[1]}
  password=${instance[2]}
  database=${instance[3]}
 
  echo "Connecting to $host..."
   docker exec -it test mysql -h $host -u $user -p$password $database -e 'SELECT * FROM users;'
done
#docker rm -f test