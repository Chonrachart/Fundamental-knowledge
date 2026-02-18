#!/bin/bash

set -e

Serverip=$1
Hostname=$2

if [ "$EUID" -ne 0 ]; then
    echo "No root privilege"
    exit 1
fi

# 2 argument only $# numbered argument passed
if [ "$#" -nq 2 ]; then
    echo "ERROR Usage: sudo ./install-zabbix-agent2.sh \"serverip\" \"hotsname\""
    exit 1
fi

if ! dpkg -s zabbix-release >/dev/null 2>&1; then
    wget https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
    dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
fi

apt update
apt install -y zabbix-agent2 \
               zabbix-agent2-plugin-mongodb \
               zabbix-agent2-plugin-mssql \
               zabbix-agent2-plugin-postgresql

systemctl enable zabbix-agent2
systemctl restart zabbix-agent2


conf=/etc/zabbix/zabbix_agent2.conf

[ -f "$conf.bkp" ] || cp "$conf" "$conf.bkp" 

sed -i "s/^[[:space:]]*Server=.*/Server=${Serverip}/" "$conf"
sed -i "s/^[[:space:]]*ServerActive=.*/ServerActive=${Serverip}:10051/" "$conf"
sed -i "s/^[[:space:]]*Hostname=.*/Hostname=${Hostname}/" "$conf"