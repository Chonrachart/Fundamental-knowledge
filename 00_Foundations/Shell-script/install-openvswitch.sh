#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
    echo "No root privilege"
    exit 1
fi
if ! dpkg -s openvswitch-switch >/dev/null 2>&1; then
    apt update
    apt install -y openvswitch-switch
fi
systemctl enable openvswitch-switch
systemctl restart openvswitch-switch

#verfify

echo "Service status:"
systemctl is-active openvswitch-switch

echo "OVS configuration:"
ovs-vsctl show