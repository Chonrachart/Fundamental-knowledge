#!/bin/bash

set -e

### Preliminary 
# Atleast 2 empty disk
# All data on diks will be delete!!!

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

install_mdadm() {
    apt update
    apt install -y mdadm
}

create_raid() {
    mdadm --create --verbose /dev/[raid-name] \
    --level=[0,1,5,6,10] --raid-devices=[number-of-raid-devices] \
    [/dev/sda] [/dev/sdb] [if-more]...[device]
}

verify_raid() {
    # Verify
    cat /proc/mdstat
}

create_filesystem() {
    # Create file system on raid and mount
    mkfs.ext4 /dev/[raid-name]
}

mount_raid() {
    mkdir [new-dir-to-mount]
    mount [raid-name] [dir-to-mount]

    # Verify
    df -h
}

save_raid_config() {
    # save raid config .conf read when boot tell about which disks belong to whick raid
    # 'tee' write output to a file '-a' mean append 
    # can't use >> cause when pipe it handle by the shell   
    # if your shell not root it permission denied (shell root sudo -i)
    mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

    # initramfs = temporary mini filesystem loaded during early boot.
    update-initramfs -u
}

show_uuid_and_fstab_note() {
    # See UUID 
    echo "UUID IS"
    blkid /dev/[raid-name]
    echo "Add UUID to /etc/fstab"
    echo "UUID=xxxx-xxxx [dir-to-mount] ext4 defaults 0 0"
}

main() {
    check_root
    install_mdadm
    create_raid
    verify_raid
    create_filesystem
    mount_raid
    save_raid_config
    show_uuid_and_fstab_note
}

main "$@"