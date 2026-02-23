#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
    echo "No root privilege"
    exit 1
fi

apt install net-tools
apt install inetutils-traceroute