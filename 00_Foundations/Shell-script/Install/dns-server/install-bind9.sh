#!/bin/bash

set -e

ZONE_CONF="/etc/bind/named.conf.local"
ZONE_DB="/etc/bind/db.somapait"
OPTIONS_CONF="/etc/bind/named.conf.options"

log()        { echo "[INFO] $1"; }
log_success(){ echo "[SUCCESS] $1"; }
log_fail()   { echo "[FAIL] $1"; exit 1; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_fail "No Root Privilege"
    fi
}

install_bind9() {
    if ! dpkg -s bind9 >/dev/null 2>&1; then
        apt update
        apt install -y bind9 dnsutils
        log_success "Installed bind9"
    else
        log "bind9 is already exists."
    fi
}

define_zone() {
    if grep -q '^[[:space:]]*zone "somapait"' "$ZONE_CONF"; then
        log "Zone file already configure"
    else
        cat >> "$ZONE_CONF" << EOF
zone "somapait" {
    type master;
    file "/etc/bind/db.somapait";
};
EOF
        log_success "Add zone configuration"
    fi
    if named-checkconf; then
        log_success "zone configuration correct"
    else
        log_fail "Zone configure incorrect"
    fi
}

create_zone_db() {

    if [ -f "$ZONE_DB" ]; then
        log "Zone database already exists"
    else
        cat > "$ZONE_DB" << EOF
\$TTL 86400
@   IN  SOA ns.somapait. admin.somapait. (
        2026030501
        3600
        1800
        604800
        86400 )

@               IN  NS  ns.somapait.

ns              IN  A   10.100.75.49
web             IN  A   10.100.75.49
chonrachart1    IN  A   10.100.75.49
chonrachart2    IN  A   10.100.75.49
app             IN  A   10.100.70.45
zabbix          IN  A   10.100.75.45
server          IN  A   10.100.75.47
EOF
    fi
    if named-checkzone somapait "$ZONE_DB" | grep -q OK ; then
        log_success "zone database correct"
    else
        log_fail "Zone database incorrect"
    fi
}

configure_forwarders() {
    if grep -q '192.168.10.254;' "$OPTIONS_CONF"; then
        log "Forwarders already configured"
        return
    fi

    cat > "$OPTIONS_CONF" << 'EOF'
options {
        directory "/var/cache/bind";

        recursion yes;
        allow-query {127.0.0.1; 10.100.0.0/16; };
        forwarders {
                192.168.10.254;
        };

        dnssec-validation auto;
        listen-on-v6 { none; };
};
EOF

    if named-checkconf; then
        log_success "Configured internet domain forwarding"
    else
        log_fail "Forwarders configuration incorrect"
    fi
}

main() {
    check_root
    install_bind9
    define_zone
    create_zone_db
    configure_forwarders
    systemctl restart bind9
}

main "$@"


### IN = internet it a DNS class 
### SOA start of Authority record Defines the primary DNS server and administrative metadata for the zone.
### ns = name server
### admin.somapait. DNS format replaces @ with . so it admin@somapait
### 2026030501 YYYYMMDDNN NN = number if modify the zone file this must increase
### 3600 = 3600 second Secondary DNS server check for updates every 3600 sec
### 1800 If refresh fails, retry after 1800 sec
### 604800 If the secondary server cannot contact the primary for 604800 sec stop serving the zone
### 86400 Default negative caching time. Resolvers will cache failed lookups for 24 hours.
### ns.somapa to 10.100.75.49
### web.somapait to 10.100.75.49
### chonrachart1.somapait to 10.100.75.49
### chonrachart2.somapait to 10.100.75.49
### app.somapait to 10.100.70.45
### zabbix.somapait to 10.100.75.45
### server.somapait to 10.100.75.47
