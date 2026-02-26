#!/bin/bash

set -e

PROPERTIES_FILE=/etc/apache2/workers.properties
JK_CONF="/etc/apache2/mods-available/jk.conf"

log()        { echo "[INFO] $1"; }
log_success(){ echo "[SUCCESS] $1"; }
log_fail()   { echo "[FAIL] $1"; exit 1; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_fail "No root privilege"
    fi
}

install_apache() {
    if ! dpkg -s apache2 >/dev/null 2>&1; then
        apt update
        apt install -y apache2
    fi
}

install_mod_jk() {
    if ! dpkg -s libapache2-mod-jk >/dev/null 2>&1; then
        apt update
        apt install -y libapache2-mod-jk
    fi
}

create_properties_file() {

    [ -f "$PROPERTIES_FILE" ] || touch "$PROPERTIES_FILE"

    if grep -q "^worker.tomcat1.host=" "$PROPERTIES_FILE"; then
        log "Updating existing tomcat worker configuration"

        if [ -s "$PROPERTIES_FILE" ]; then
            log "Creating backup of workers.properties"
            cp "$PROPERTIES_FILE" "${PROPERTIES_FILE}.bkp.$(date +%F-%H%M%S)"
        fi

        sed -i 's|^worker.tomcat1.host=.*|worker.tomcat1.host=10.100.70.45|' "$PROPERTIES_FILE"
        sed -i 's|^worker.tomcat1.port=.*|worker.tomcat1.port=8009|' "$PROPERTIES_FILE"
        sed -i 's|^worker.tomcat1.secret=.*|worker.tomcat1.secret=P@ssw0rd|' "$PROPERTIES_FILE"

        log_success "workers.properties updated"

    else
        log "Adding tomcat worker configuration"

        cat <<EOF >> "$PROPERTIES_FILE"

worker.list=tomcat1
worker.tomcat1.type=ajp13
worker.tomcat1.host=10.100.70.45
worker.tomcat1.port=8009
worker.tomcat1.secret=P@ssw0rd
worker.tomcat1.lbfactor=1
EOF

        log_success "workers.properties added"
    fi
}

configure_mod_jk () {

    [ -f "$JK_CONF" ] || touch "$JK_CONF"

    if grep -q "JkWorkersFile" "$JK_CONF"; then
        log "mod_jk already configured"
        return
    fi

    if [ -s "$JK_CONF" ]; then
        log "Creating backup of jk.conf"
        cp "$JK_CONF" "${JK_CONF}.bkp.$(date +%F-%H%M%S)"
    fi

    log "Adding mod_jk config"

    cat <<EOF >> "$JK_CONF"

JkWorkersFile /etc/apache2/workers.properties
JkLogFile     /var/log/apache2/mod_jk.log
JkLogLevel    info
JkMount  /*  tomcat1
EOF
    log_success "mod_jk config added"

}

enable_module() {
    systemctl restart apache2
    log_success "mod_jk config added and apache restarted"
}

main() {
    check_root
    install_apache
    install_mod_jk
    create_properties_file
    configure_mod_jk
    enable_module
}

main "$@"