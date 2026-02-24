#!/bin/bash

set -e

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

check_new_disk() {
    # this should see new add disk space
    lsblk
}

resize_partition() {
    # this update partition that want to resize  
    growpart /dev/sdx <partition>
}

resize_pv() {
    # this tell pv that partition was resize
    pvresize /dev/sdxx

    # verify
    pvs
}

extend_lv() {
    # this tell lv to use free pv
    lvextend -L +10G /dev/[vg]/[lv]
}

resize_filesystem() {
    # df -h stil see old disk space we need to tell file system
    resize2fs /dev/[vg]/[lv]
}

main() {
    check_root
    check_new_disk
    resize_partition
    resize_pv
    extend_lv
    resize_filesystem
}

main "$@"