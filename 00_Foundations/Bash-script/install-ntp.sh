#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
    echo "No root privilege"
    exit 1
fi

conf=/etc/chrony/chrony.conf

apt update
apt install -y chrony 
sed -i.bkp '/^[[:space:]]*pool/ s/^/#' "$conf"
grep -q "^[[:space:]]*server 192.168.10.254 iburst" "$conf" || echo "server 192.168.10.254 iburst" >> "$conf"

systemctl enable chrony
systemctl restart chrony


#verify 
chronyc tracking
