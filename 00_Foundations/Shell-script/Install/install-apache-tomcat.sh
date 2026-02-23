#!/bin/bash

set -e

INSTALL_DIR="/opt/tomcat"
INSTALL_TARGET="$INSTALL_DIR/apache-tomcat-11.0.18"
TAR_FILE="$INSTALL_DIR/apache-tomcat-11.0.18.tar.gz"
URL="https://dlcdn.apache.org/tomcat/tomcat-11/v11.0.18/bin/apache-tomcat-11.0.18.tar.gz"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

download_gz() {
    if [ ! -f "$TAR_FILE" ]; then
        wget -P "$INSTALL_DIR" "$URL"
    else
        echo "$TAR_FILE already exists"
    fi
}

make_dir() {
    mkdir -p "$INSTALL_DIR"
}

extract_tomcat() {
    if [ ! -d "$INSTALL_TARGET" ]; then
        echo "Extracting Tomcat..."
        tar -xzf "$TAR_FILE" -C "$INSTALL_DIR"
    else
        echo "Tomcat already installed."
    fi
}

verify_tomcat() {
    if [ -f "$INSTALL_TARGET/bin/startup.sh" ]; then
        echo "Tomcat installation verified."
    else
        echo "Tomcat installation failed!"
        exit 1
    fi
}

main() {
    check_root
    download_gz
    make_dir
    extract_tomcat
    verify_tomcat
    echo "This is hardcode to tomcat version 11.0.18 !!!!"
}

main "$@"