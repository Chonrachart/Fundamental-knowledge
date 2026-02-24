#!/bin/bash

set -e

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

install_ovs() {
    if ! dpkg -s openvswitch-switch >/dev/null 2>&1; then
        apt update
        apt install -y openvswitch-switch
    fi
}

enable_service() {
    systemctl enable openvswitch-switch
    systemctl restart openvswitch-switch
}

verify_installation() {
    echo "Service status:"
    systemctl is-active openvswitch-switch

    echo "OVS configuration:"
    ovs-vsctl show
}

main() {
    check_root
    install_ovs
    enable_service
    verify_installation
}

main "$@"