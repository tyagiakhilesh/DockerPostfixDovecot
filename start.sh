#!/bin/bash

# default 
DB_NAME=automation
DB_PASSWORD=mysqlpswd
DB_USER=root
MAIL_USER1=verity
MAIL_PASS1=skyline
DB_SCHEMA_FILE=mailschema.sql

echo "Running Dovecot + Postfix"
echo "Host: $APP_HOST (should be set)"
echo "Database: $DB_NAME (should be set)"
echo "Available environment vars:"
echo "APP_HOST *required*, DB_NAME *required*, DB_USER, DB_PASSWORD"

# adding IP of a host to /etc/hosts
export HOST_IP=$(/sbin/ip route|awk '/default/ { print $3 }')
echo "$HOST_IP dockerhost" >> /etc/hosts

# defining mail name
echo "localhost" > /etc/mailname

# update config templates
sed -i "s/{{DB_USER}}/$DB_USER/g" /etc/postfix/mysql-email2email.cf
sed -i "s/{{DB_HOST}}/$DB_HOST/g" /etc/postfix/mysql-email2email.cf
sed -i "s/{{DB_NAME}}/$DB_NAME/g" /etc/postfix/mysql-email2email.cf
sed -i "s/{{DB_PASSWORD}}/$DB_PASSWORD/g" /etc/postfix/mysql-email2email.cf

sed -i "s/{{DB_USER}}/$DB_USER/g" /etc/postfix/mysql-users.cf
sed -i "s/{{DB_HOST}}/$DB_HOST/g" /etc/postfix/mysql-users.cf
sed -i "s/{{DB_NAME}}/$DB_NAME/g" /etc/postfix/mysql-users.cf
sed -i "s/{{DB_PASSWORD}}/$DB_PASSWORD/g" /etc/postfix/mysql-users.cf

sed -i "s/{{DB_USER}}/$DB_USER/g" /etc/postfix/mysql-virtual-alias-maps.cf
sed -i "s/{{DB_HOST}}/$DB_HOST/g" /etc/postfix/mysql-virtual-alias-maps.cf
sed -i "s/{{DB_NAME}}/$DB_NAME/g" /etc/postfix/mysql-virtual-alias-maps.cf
sed -i "s/{{DB_PASSWORD}}/$DB_PASSWORD/g" /etc/postfix/mysql-virtual-alias-maps.cf

sed -i "s/{{DB_USER}}/$DB_USER/g" /etc/postfix/mysql-virtual-mailbox-maps.cf
sed -i "s/{{DB_HOST}}/$DB_HOST/g" /etc/postfix/mysql-virtual-mailbox-maps.cf
sed -i "s/{{DB_NAME}}/$DB_NAME/g" /etc/postfix/mysql-virtual-mailbox-maps.cf
sed -i "s/{{DB_PASSWORD}}/$DB_PASSWORD/g" /etc/postfix/mysql-virtual-mailbox-maps.cf

sed -i "s/{{DB_USER}}/$DB_USER/g" /etc/postfix/mysql-virtual-mailbox-domains.cf
sed -i "s/{{DB_HOST}}/$DB_HOST/g" /etc/postfix/mysql-virtual-mailbox-domains.cf
sed -i "s/{{DB_NAME}}/$DB_NAME/g" /etc/postfix/mysql-virtual-mailbox-domains.cf
sed -i "s/{{DB_PASSWORD}}/$DB_PASSWORD/g" /etc/postfix/mysql-virtual-mailbox-domains.cf

sed -i "s/{{DB_USER}}/$DB_USER/g" /etc/dovecot/dovecot-sql.conf
sed -i "s/{{DB_HOST}}/$DB_HOST/g" /etc/dovecot/dovecot-sql.conf
sed -i "s/{{DB_NAME}}/$DB_NAME/g" /etc/dovecot/dovecot-sql.conf
sed -i "s/{{DB_PASSWORD}}/$DB_PASSWORD/g" /etc/dovecot/dovecot-sql.conf

sed -i "s/{{APP_HOST}}/$APP_HOST/g" /etc/dovecot/local.conf

mkdir /run/dovecot
chmod -R +r /run/dovecot
chmod -R +w /run/dovecot
chmod -R 777 /home/vmail
# start logger
rsyslogd 

# run Postfix and Dovecot
if [ ! -f /var/lib/mysql/ibdata1 ]; then
    mysql_install_db
    /usr/bin/mysqld_safe &
    sleep 10s
    echo "GRANT ALL ON *.* TO admin@'%' IDENTIFIED BY 'changeme' WITH GRANT OPTION; FLUSH PRIVILEGES" | mysql
    killall mysqld
    sleep 10s
fi
/usr/bin/mysqld_safe &
sleep 10s
echo "Creating database ${DB_NAME}"
mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -e "CREATE DATABASE ${DB_NAME} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
#mysql -e "CREATE USER ${DB_NAME}@localhost IDENTIFIED BY '${PASSWDDB}';"
mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO 'root'@'localhost';"
mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -e "FLUSH PRIVILEGES;"
mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -e "FLUSH PRIVILEGES;"

mysql -h localhost -u $DB_USER -p${DB_PASSWORD} ${DB_NAME} < "/${DB_SCHEMA_FILE}"
mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -D $DB_NAME -e "insert into mail_virtual_domains set name='$APP_HOST';"
mysql -u ${DB_USER} -p${DB_PASSWORD} -h localhost -D $DB_NAME -e "insert into mail_virtual_users (domain_id,user,password) VALUES (1,'$MAIL_USER1','$MAIL_PASS1');"
echo "DONE!"

postfix start
dovecot -F
