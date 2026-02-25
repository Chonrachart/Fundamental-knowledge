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
        echo "[SUCCESS] SSH reloaded"
    else
        echo "[ERROR] Invalid sshd_config. Restoring backup..."
        cp "$CONFIG_FILE.bkp" "$CONFIG_FILE"
        exit 1
    fi
}

check_ssh() {
    
    CONFIG="/etc/ssh/sshd_config"

    if [ ! -f "$CONFIG" ]; then
        echo "[FAIL] sshd_config not found"
        echo ""
        return
    fi

    if sshd -T 2>/dev/null | grep -q "^permitrootlogin no$"; then
        echo "[SUCCESS] PermitRootLogin disabled"
    else
        echo "[FAIL] PermitRootLogin not disabled"
    fi

    if sshd -T 2>/dev/null | grep -q "^passwordauthentication no$"; then
        echo "[SUCCESS] PasswordAuthentication disabled"
    else
        echo "[FAIL] PasswordAuthentication not disabled"
    fi

    if sshd -T 2>/dev/null | grep -q "^pubkeyauthentication yes$"; then
        echo "[SUCCESS] PubkeyAuthentication enabled"
    else
        echo "[FAIL] PubkeyAuthentication disabled"
    fi
    
    echo ""
}

main() {
    check_root
    harden_ssh
    validate_config_file
    check_ssh
}

main "$@"