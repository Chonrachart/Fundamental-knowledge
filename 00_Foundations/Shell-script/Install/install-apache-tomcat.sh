#!/bin/bash

set -e

INSTALL_DIR="/opt/tomcat"
INSTALL_TARGET="$INSTALL_DIR/jdk-"
TAR_FILE="$INSTALL_DIR/jdk-21_linux-x64_bin.tar.gz"
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

extract_java() {
    if [ ! -d "$INSTALL_TARGET" ]; then
        echo "Extracting Java..."
        tar -xzf "$TAR_FILE" -C "$INSTALL_DIR"
        mv "$INSTALL_DIR"/jdk-21.* "$INSTALL_TARGET"
    else
        echo "Java already installed."
    fi
}

