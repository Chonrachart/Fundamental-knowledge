#!/bin/bash

set -e

FILE="$HOME/.bashrc"
PROMPT='export PS1="\[\e[1;32m\]\u\[\e[0m\]@\[\e[1;35m\]\h\[\e[0m\]:\[\e[1;36m\]\w\[\e[0m\]\$ "'

log() { echo "[INFO] $1"; }
success() { echo "[SUCCESS] $1"; }
fail() { echo "[FAIL] $1"; exit 1; }

check_file() {
    if [ ! -f "$FILE" ]; then
        log ".bashrc not found, creating it"
        touch "$FILE"
    fi
}

validate_prompt() {
    bash -n <<< "$PROMPT" || fail "Prompt syntax appears invalid"
}

check_existing() {
    if grep -Fq "$PROMPT" "$FILE"; then
        log "Prompt already configured in $FILE"
        exit 0
    fi
}

backup_file() {
    cp "$FILE" "$FILE.bak.$(date +%F-%H%M%S)"
    log "Backup created"
}

add_prompt() {
    {
        echo ""
        echo "# Custom prompt"
        echo "$PROMPT"
    } >> "$FILE"
}

main() {
    check_file
    validate_prompt
    check_existing
    backup_file
    add_prompt
    success "Prompt added to $FILE"
    log "Run: source ~/.bashrc or open a new shell"
    log "This change in $HOME"
}

main