#!/bin/bash

set -e




if [ "$EUID" -ne 0 ]; then
    echo "No root privilege"
    exit 1
fi

# 1 argument only $# numbered argument passed
if [ "$#" -ne 1 ]; then
    echo "ERROR Usage: sudo ./change-hostname.sh \"hostname\""
    exit 1
fi

Hostname=$1

echo "This old hostname (hostname) will change to ${Hostname}"
sudo hostnamectl set-hostname "$Hostname"
sed -i.bkp "s/127.0.1.1 .*/127.0.1.1 ${Hostname}/"