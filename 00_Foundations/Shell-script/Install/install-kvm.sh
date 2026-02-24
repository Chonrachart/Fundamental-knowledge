#!/bin/bash

set -e

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

check_virtualization_support() {
    if [ "$(egrep -c '(vmx|svm)' /proc/cpuinfo)" -eq 0 ]; then
        echo "Virtualization not supported (or disabled in BIOS)"
        exit 1
    fi
}

install_kvm_packages() {
    apt update
    apt install -y qemu-kvm \
                    libvirt-daemon-system \
                    libvirt-clients \
                    bridge-utils \
                    virtinst \
                    virt-manager
}

configure_user_groups() {
    usermod -aG libvirt "$SUDO_USER"
    usermod -aG kvm "$SUDO_USER"
}

enable_libvirt_service() {
    systemctl enable libvirtd
    systemctl restart libvirtd
}

verify_installation() {
    kvm-ok
}

main() {
    check_root
    check_virtualization_support
    install_kvm_packages
    configure_user_groups
    enable_libvirt_service
    verify_installation
}

main "$@"