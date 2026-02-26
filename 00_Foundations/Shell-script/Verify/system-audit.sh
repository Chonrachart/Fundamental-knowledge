#!/bin/bash

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

log_success() { echo "  [SUCCESS] $1"; ((PASS_COUNT++)); }
log_fail()    { echo "  [FAIL] $1"; ((FAIL_COUNT++)); }
log_warn()    { echo "  [WARNING] $1"; ((WARN_COUNT++)); }

echo "=================================="
echo "        SYSTEM AUDIT CHECK        "
echo "=================================="
echo ""

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

check_ssh() {
    echo "[1] SSH Hardening"
    CONFIG="/etc/ssh/sshd_config"

    if [ ! -f "$CONFIG" ]; then
        log_fail "sshd_config not found"
        echo ""
        return
    fi

    if sshd -T 2>/dev/null | grep -q "^permitrootlogin no$"; then
        log_success "PermitRootLogin disabled"
    else
        log_fail "PermitRootLogin not disabled"
    fi

    if sshd -T 2>/dev/null | grep -q "^passwordauthentication no$"; then
        log_success "PasswordAuthentication disabled"
    else
        log_fail "PasswordAuthentication not disabled"
    fi

    if sshd -T 2>/dev/null | grep -q "^pubkeyauthentication yes$"; then
        log_success "PubkeyAuthentication enabled"
    else
        log_fail "PubkeyAuthentication disabled"
    fi
    
    echo ""
}

check_ntp() {
    echo "[2] NTP Service"

    if systemctl is-active --quiet chronyd; then
        log_success "chronyd running"
    elif systemctl list-unit-files | grep -q "^chronyd"; then
        log_fail "chronyd installed but not running"
    else
        log_fail "chronyd not installed"
    fi

    echo ""
}

check_zabbix() {
    echo "[3] Zabbix Agent2"

    if systemctl list-unit-files | grep -q "^zabbix-agent2"; then
        if systemctl is-active --quiet zabbix-agent2; then
            log_success "zabbix-agent2 running"
        else
            log_fail "zabbix-agent2 installed but not running"
        fi
    else
        log_fail "zabbix-agent2 not installed"
    fi

    echo ""
}

check_tools() {
    echo "[4] Additional Tools"

    command -v ifconfig >/dev/null 2>&1 \
        && log_success "net-tools installed (ifconfig)" \
        || log_fail "net-tools not installed"

    command -v netstat >/dev/null 2>&1 \
        && log_success "netstat available" \
        || log_fail "netstat not available"

    echo ""
}

check_users() {
    echo "[5] User Account Audit"

    CONSOLE_LOGIN_USERS=()

    while IFS=: read -r username _ uid _ _ home shell; do

        # Skip system accounts
        if [ "$uid" -lt 1000 ]; then
            continue
        fi

        # Skip users without valid login shell
        # /etc/shells show shell that system allow to login
        if ! grep -qx "$shell" /etc/shells; then
            continue
        fi

        echo "  User: $username"

        status=$(passwd -S "$username" 2>/dev/null | awk '{print $2}')

        case "$status" in
            L)
                log_success "account locked"
                ;;
            P)
                log_warn "console login possible (password set)"
                CONSOLE_LOGIN_USERS+=("$username")
                ;;
            NP)
                log_fail "no password set"
                ;;
            *)
                log_warn "unknown password state"
                ;;
        esac

        if id -nG "$username" | grep -qw sudo ; then
            log_warn "has sudo privilege"
        else
            log_success "no sudo privilege"
        fi

        echo ""

    done < <(getent passwd)
}

Print_summary() {
    echo "=================================="
    echo "SUMMARY"
    echo "----------------------------------"
    echo "PASS  : $PASS_COUNT"
    echo "FAIL  : $FAIL_COUNT"
    echo "WARN  : $WARN_COUNT"
    echo "=================================="
    echo "Console Login Enabled Accounts:"
    echo "----------------------------------"
    if [ "${#CONSOLE_LOGIN_USERS[@]}" -eq 0 ]; then
        log_success "No user can login via console"
    else
        for u in "${CONSOLE_LOGIN_USERS[@]}"; do
            echo "[WARN] $u"
        done
    fi

    echo "=================================="
}

main() {
    check_root
    check_ssh
    check_ntp
    check_zabbix
    check_tools
    check_users
    Print_summary
}

main "$@"


