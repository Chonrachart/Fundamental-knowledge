#!/bin/bash

### This file is use for generate self certification

set -e

KEY_FILE="/etc/ssl/private/apache-ed25519.key"
CERT_FILE="/etc/ssl/certs/apache-ed25519.crt"

log()        { echo "[INFO] $1"; }
log_success(){ echo "[SUCCESS] $1"; }
log_fail()   { echo "[FAIL] $1"; exit 1; }

check_root() {
    if [ $EUID -ne 0 ]; then
        log_fail "No Root Privilege"
        exit 1
    fi
}

makedir(){
    mkdir -p /etc/ssl/private
    mkdir -p /etc/ssl/certs
}

key_gen() {
    if [ -s "$KEY_FILE" ]; then
        log "Key already exists"
    else
        openssl genpkey -algorithm ED25519 -out "$KEY_FILE" 
        log_success "Generate key ED25519"
    fi
}

cert_gen() {
    if [ -s "$CERT_FILE" ]; then
        log "CERTIFICATE already exists"
    else
        openssl req -new -x509 \
        -key "$KEY_FILE" \
        -out "$CERT_FILE" \
        -days 365
        log_success "Generate CERTIFICATE"
    fi
}

main() {
    check_root
    makedir
    key_gen
    cert_gen
}

main "$@"
