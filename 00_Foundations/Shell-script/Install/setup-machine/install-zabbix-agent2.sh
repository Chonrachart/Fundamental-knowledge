#!/bin/bash

set -e

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

check_argument() {
    if [ "$#" -ne 2 ]; then
        echo "ERROR Usage: sudo ./install-zabbix-agent2.sh \"host_zabbix_serverip\" \"hostname\""
        exit 1
    fi
}

install_repo() {
    if ! dpkg -s zabbix-release >/dev/null 2>&1; then
        wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
        dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
    fi
}

install_agent() {
    apt update
    apt install -y zabbix-agent2 \
                   zabbix-agent2-plugin-mongodb \
                   zabbix-agent2-plugin-mssql \
                   zabbix-agent2-plugin-postgresql

    systemctl enable zabbix-agent2
    systemctl restart zabbix-agent2
}

configure_agent() {
    local Serverip="$1"
    local Hostname="$2"
    local conf="/etc/zabbix/zabbix_agent2.conf"

    [ -f "$conf.bkp" ] || cp "$conf" "$conf.bkp"

    sed -i "s/^[[:space:]]*Server=.*/Server=${Serverip}/" "$conf"
    sed -i "s/^[[:space:]]*ServerActive=.*/ServerActive=${Serverip}:10051/" "$conf"
    sed -i "s/^[[:space:]]*Hostname=.*/Hostname=${Hostname}/" "$conf"
}

main() {
    check_root
    check_argument "$@"

    local Serverip="$1"
    local Hostname="$2"

    install_repo
    install_agent
    configure_agent "$Serverip" "$Hostname"

    systemctl restart zabbix-agent2
}

main "$@"

### to Redirect zabbix to use only ip not use context/zabbix ###
### edit in /etc/apache2/sites-enabled/000-default.conf
### ---------------default----------------
### DocumentRoot /var/www/html
### --------------fix to-----------------
### DocumentRoot /usr/share/zabbix



### --------------- OR ----------------------
### edit /etc/apache2/conf-enabled/zabbix.conf
### ---------------default----------------
### Alias /zabbix /usr/share/zabbix
### <Directory "/usr/share/zabbix">
###     Options FollowSymLinks
###     AllowOverride None
###     Require all granted
### </Directory>
### --------------fix to-----------------
### DocumentRoot /usr/share/zabbix
### 
### <Directory "/usr/share/zabbix">
###     Options FollowSymLinks
###     AllowOverride None
###     Require all granted
### </Directory>