#!/bin/bash

set -e

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

install_network_tools() {
    apt install -y \
        net-tools \
        iproute2 \
        dnsutils \
        inetutils-traceroute \
        mtr \
        tcpdump \
        nmap \
        curl \
        wget \
        telnet \
        netcat-openbsd
}

install_system_tools() {
    apt install -y \
        htop \
        iotop \
        dstat \
        sysstat \
        lsof \
        strace \
        psmisc \
        tree
}

install_filesystem_tools() {
    apt install -y \
        ncdu \
        jq \
        rsync \
        zip \
        unzip \
        p7zip-full
}

install_general_tools() {
    apt install -y \
        git \
        vim \
        tmux \
        bash-completion
}

main() {
    check_root

    apt update

    install_network_tools
    install_system_tools
    install_filesystem_tools
    install_general_tools

    echo "Base system tools installation completed."
}

main "$@"