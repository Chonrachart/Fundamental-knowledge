#!/bin/bash

set -e


##### GUIDE you need to wget image you want first
##### you need to set bridge first
##### SET VM manually

if [ "$EUID" -ne 0 ]; then
    echo "No root privilege"
    exit 1
fi

if ! [ -d /opt/libvirt/images ]; then
    mkdir -p /opt/libvirt/images
    chown -R libvirt-qemu:kvm /opt/libvirt/images
    chmod 755 /opt/libvirt/images
    echo "create storage path"
fi

virt-install \
--name ubuntu-desktop \
--memory 4096 \
--vcpus 2 \
--cpu host \
--disk path=/opt/libvirt/images/ubuntu-desktop.qcow2,size=40,format=qcow2 \
--os-variant ubuntu24.04 \
--network bridge=br-vm,model=virtio,virtualport_type=openvswitch \
--graphics vnc \
--cdrom /var/lib/libvirt/images/ubuntu-24.04.4-desktop-amd64.iso \
--noautoconsole

# --cpu host vm can see real host cpu
# oso-variant tell libvirt which os to install to use correct driver
# graphics vnc enable GUI via vnc
# noautoconsole do not auto open console after finish