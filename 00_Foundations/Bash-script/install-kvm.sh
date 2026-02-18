#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]; then
    echo "No root privilege"
    exit 1
fi

if [ "$(egrep -c '(vmx|svm)' /proc/cpuinfo)" -eq 0 ]; then
    echo "Virtualization not supported(or disabled in BIOS)"
    exit 1 
fi

apt update
apt install -y qemu-kvm \
                libvirt-daemon-system \
                libvirt-clients \
                bridge-utils \
                virtinst \
                virt-manager

usermod -aG libvirt $SUDO_USER
usermod -aG kvm $SUDO_USER

systemctl enable libvirtd
systemctl restart libvirtd

#verify
kvm-ok
