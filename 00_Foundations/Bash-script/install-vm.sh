#!/bin/bash

set -e


##### GUIDE you need to wget image you want first
##### SET VM manually

if [ "$EUID" -ne 0 ]; then
    echo "No root privilege"
    exit 1
fi

NIC=${1:-}

if ! ovs-vsctl br-exists br-vm; then
    ovs-vsctl add-br br-vm
    echo "create br-vm"
fi

if [ -n "$NIC" ] && ! ovs-vsctl list-ports br-vm | grep -qw "$NIC"; then
    ovs-vsctl add-port br-vm "$NIC"
    echo "create port ${NIC}"
fi

if ! [ -d /opt/libvirt/images ]; then 
    mkdir -p /opt/libvirt/images
    chown -R libvirt-qemu:kvm /opt/libvirt/images
    chmod 755 /opt/libvirt/images
    echo "create storage path"
fi

virt-install \
--name ubuntu-desktop \
--memory 2048 \
--vcpus 2 \
# vm cansee real host cpu
--cpu host 
--disk path=/opt/libvirt/images/ubuntu-desktop.qcow2,size=40,format=qcow2 \
# tell libvirt which os to install to use correct driver 
--os-variant ubuntu24.04 \
--network bridge=br-vm,model=virtio \
# enable GUI via vnc
--graphics vnc \
--cdrom /var/lib/libvirt/images/ubuntu-24.04.4-desktop-amd64.iso \
# do not auto open console after finish
--noautoconsole