#!/bin/bash

set -e

##### GUIDE you need to wget image you want first
##### you need to set bridge first
##### SET VM manually

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

prepare_storage() {
    local storage_path="/opt/libvirt/images"

    if ! [ -d "$storage_path" ]; then
        mkdir -p "$storage_path"
        chown -R libvirt-qemu:kvm "$storage_path"
        chmod 755 "$storage_path"
        echo "create storage path"
    fi
}

create_vm() {
    virt-install \
    --name ubuntu-desktop \
    --memory 4096 \
    --vcpus 2 \
    --cpu host \
    --disk path=/opt/libvirt/images/ubuntu-desktop.qcow2,size=40,format=qcow2 \
    --os-variant ubuntu24.04 \
    --network bridge=ovs-br-trust,model=virtio,virtualport_type=openvswitch \
    --graphics vnc \
    --cdrom /var/lib/libvirt/images/ubuntu-24.04.4-desktop-amd64.iso \
    --noautoconsole
}

main() {
    check_root
    prepare_storage
    create_vm
}

main "$@"

# must change cdrom, disk path, name
# --cpu host vm can see real host cpu
# oso-variant tell libvirt which os to install to use correct driver
# graphics vnc enable GUI via vnc
# noautoconsole do not auto open console after finish