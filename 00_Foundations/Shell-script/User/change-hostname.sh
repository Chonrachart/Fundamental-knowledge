#!/bin/bash

set -e

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

check_argument() {
    if [ "$#" -ne 1 ]; then
        echo "ERROR Usage: sudo ./change-hostname.sh \"hostname\""
        exit 1
    fi
}

change_hostname() {
    local Hostname="$1"

    echo "Changing hostname to ${Hostname}"
    hostnamectl set-hostname "$Hostname"
}

update_hosts_file() {
    local Hostname="$1"
    local hosts_file="/etc/hosts"

    [ -f /etc/hosts.bkp ] || cp "$hosts_file" /etc/hosts.bkp

    sed -i "s/127.0.1.1[[:space:]].*/127.0.1.1 ${Hostname}/" "$hosts_file"
}

main() {
    check_root
    check_argument "$@"

    local Hostname="$1"

    change_hostname "$Hostname"
    update_hosts_file "$Hostname"
}

main "$@"