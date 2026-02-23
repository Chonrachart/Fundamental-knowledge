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

echo "Changing hostname to ${Hostname}"
hostnamectl set-hostname "$Hostname"

[ -f /etc/hosts.bkp ] || cp /etc/hosts /etc/hosts.bkp

sed -i "s/127.0.1.1[[:space:]].*/127.0.1.1 ${Hostname}/" /etc/hosts