#!/bin/bash

set -e

JAVA_VERSION="21.0.10"
INSTALL_DIR="/opt/java"
INSTALL_TARGET="$INSTALL_DIR/jdk-$JAVA_VERSION"
TAR_FILE="$INSTALL_DIR/jdk-21_linux-x64_bin.tar.gz"
URL="https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.tar.gz"

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
    else
        echo "Java already installed."
    fi
}

verify_java() {
    "$INSTALL_TARGET/bin/java" -version
}

main() {
    check_root
    download_gz
    make_dir
    extract_java
    verify_java
    echo " This fix name version to 21.0.10 even it not check first!!!!"
}

main "$@"