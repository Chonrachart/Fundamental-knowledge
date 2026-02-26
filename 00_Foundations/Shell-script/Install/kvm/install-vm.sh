#!/bin/bash

set -e

##### GUIDE you need to wget image you want first
##### you need to set bridge first
##### SET VM manually

VM_NAME="ubuntu-desktop"
ISO_PATH="/var/lib/libvirt/images/ubuntu-24.04.4-desktop-amd64.iso"
DISK_PATH="/opt/libvirt/images/${VM_NAME}.qcow2"
BRIDGE="ovs-br-trust"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

prepare_storage() {
    mkdir -p /opt/libvirt/images
    chown libvirt-qemu:kvm /opt/libvirt/images
    chmod 755 /opt/libvirt/images
}

create_vm() {
    virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --cpu host \
    --machine q35 \
    --video virtio \
    --boot uefi \
    --disk path="$DISK_PATH",size=40,format=qcow2,bus=virtio \
    --os-variant ubuntu22.04 \
    --network bridge="$BRIDGE",model=virtio,virtualport_type=openvswitch\
    --graphics vnc,listen=0.0.0.0 \
    --cdrom "$ISO_PATH" \
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