#!/bin/bash

set -e

CONFIG_FILE="/etc/ssh/sshd_config"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

harden_ssh() {

    [ -f "$CONFIG_FILE.bkp" ] || cp "$CONFIG_FILE" "$CONFIG_FILE.bkp"

    # Remove existing directives completely
    sed -i '/^[#[:space:]]*PasswordAuthentication/d' "$CONFIG_FILE"
    sed -i '/^[#[:space:]]*PubkeyAuthentication/d' "$CONFIG_FILE"
    sed -i '/^[#[:space:]]*PermitRootLogin/d' "$CONFIG_FILE"

    # Add hardened settings once
    {
        echo "PasswordAuthentication no"
        echo "PubkeyAuthentication yes"
        echo "PermitRootLogin no"
    } >> "$CONFIG_FILE"

    echo "[SUCCESS] Harden SSH configuration"
}

validate_config_file() {

    if sshd -t; then
        systemctl reload sshd 2>/dev/null || systemctl reload ssh
        echo "[SUCCESS] SSH hardened and reloaded"
    else
        echo "[ERROR] Invalid sshd_config. Restoring backup..."
        cp "$CONFIG_FILE.bkp" "$CONFIG_FILE"
        exit 1
    fi
}

main() {
    check_root
    harden_ssh
    validate_config_file
}

main "$@"