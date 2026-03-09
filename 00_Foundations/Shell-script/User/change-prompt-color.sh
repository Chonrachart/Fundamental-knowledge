#!/bin/bash

set -e

PS1_VALUE='export PS1="\[\e[32m\]\u\[\e[0m\]@\[\e[35m\]\h\[\e[0m\]:\[\e[36m\]\w\[\e[0m\]\$ "'
TARGET_FILE="/etc/bash.bashrc"

log() { echo "[INFO] $1"; }
success() { echo "[SUCCESS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        fail "No root privilege"
    fi
}

check_bashrc() {
    if [ ! -f "$TARGET_FILE" ]; then
        fail "$TARGET_FILE does not exist"
    fi
}

check_existing() {
    if grep -Fq "$PS1_VALUE" "$TARGET_FILE"; then
        log "PS1 already configured"
        exit 0
    fi
}

validate_ps1() {
    bash -n <<< "$PS1_VALUE" || fail "PS1 syntax appears invalid"
}

add_ps1() {
    echo "" >> "$TARGET_FILE"
    echo "# Custom colored prompt" >> "$TARGET_FILE"
    echo "$PS1_VALUE" >> "$TARGET_FILE"
}

main() {
    check_root
    check_bashrc
    check_existing
    validate_ps1
    add_ps1
    success "PS1 added to $TARGET_FILE"
}

main