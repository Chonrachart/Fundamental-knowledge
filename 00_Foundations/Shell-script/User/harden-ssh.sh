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

    # Replace or uncomment existing lines
    sed -i 's|^[#[:space:]]*PasswordAuthentication[[:space:]].*|PasswordAuthentication no|' "$CONFIG_FILE"
    sed -i 's|^[#[:space:]]*PubkeyAuthentication[[:space:]].*|PubkeyAuthentication yes|' "$CONFIG_FILE"
    sed -i 's|^[#[:space:]]*PermitRootLogin[[:space:]].*|PermitRootLogin no|' "$CONFIG_FILE"

    # Append if missing
    grep -q "^PasswordAuthentication" "$CONFIG_FILE" || echo "PasswordAuthentication no" >> "$CONFIG_FILE"
    grep -q "^PubkeyAuthentication" "$CONFIG_FILE" || echo "PubkeyAuthentication yes" >> "$CONFIG_FILE"
    grep -q "^PermitRootLogin" "$CONFIG_FILE" || echo "PermitRootLogin no" >> "$CONFIG_FILE"

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