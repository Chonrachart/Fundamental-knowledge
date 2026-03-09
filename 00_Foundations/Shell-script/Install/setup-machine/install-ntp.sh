#!/bin/bash

set -e

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

install_chrony() {
    apt update
    apt install -y chrony
}

configure_chrony() {
    local conf="/etc/chrony/chrony.conf"

    sed -i.bkp '/^[[:space:]]*pool/ s/^/#/' "$conf"

    grep -q "^[[:space:]]*server 192.168.10.254 iburst" "$conf" \
        || echo "server 192.168.10.254 iburst" >> "$conf"

    grep -q "^[[:space:]]*allow 10.100.0.0/16" "$conf" \
        || echo "allow 10.100.0.0/16" >> "$conf"
}

enable_service() {
    systemctl enable chrony
    systemctl restart chrony
}

force_sync() {
    chronyc makestep
}

wait_for_sync() {
    for i in {1..10}; do
        if chronyc sources | grep -q "^\^\*"; then
            echo "Chrony synchronized"
            break
        fi
        sleep 1
    done
}

verify_sync() {
    chronyc tracking
}

main() {
    check_root
    install_chrony
    configure_chrony
    enable_service
    force_sync
    wait_for_sync
    verify_sync
}

main "$@"

############################# In short ################################
### Traditional daemon: ntpd
### Modern alternative: chronyd
### You use Chrony because it is a modern NTP implementation that:
###     syncs time faster, especially when the system starts.
###     handles unstable networks better, ntpd assumes stable connectivity.
###     works well with VMs
###     maintains accurate system time
#######################################################################