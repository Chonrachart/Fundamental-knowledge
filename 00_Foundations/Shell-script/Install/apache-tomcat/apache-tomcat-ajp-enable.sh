#!/bin/bash

set -e


TOMCAT_CONFIG="/opt/tomcat/apache-tomcat/conf/server.xml"
BACKUP_FILE="$TOMCAT_CONFIG.bkp"
AJP_PORT="8009"
AJP_SECRET="MyStrongSecret123"
AJP_ADDRESS="10.100.70.45"

log()        { echo "[INFO] $1"; }
log_success(){ echo "[SUCCESS] $1"; }
log_fail()   { echo "[FAIL] $1"; exit 1; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_fail "No root privilege"
    fi
}

backup_config() {
    if [ ! -f "$BACKUP_FILE" ]; then
        cp "$TOMCAT_CONFIG" "$BACKUP_FILE"
        log_success "Backup created"
    else
        log "Backup already exists"
    fi
    chown tomcat:tomcat "$TOMCAT_CONFIG"
    chmod 640 "$TOMCAT_CONFIG"
    chown tomcat:tomcat "$BACKUP_FILE"
    chmod 640 "$BACKUP_FILE"
    # This fix ownership cause when cp it do with root 
    # if want to use bkp file it will permission denine
}

add_ajp_connector() {

    if awk ' 
    /<!--/ {comment=1} 
    /-->/ {comment=0; next} 
    !comment && /<Connector/ && /protocol="AJP\/1\.3"/ {found=1} 
    END {exit !found}' "$TOMCAT_CONFIG"; then 
        log "AJP connector already exists" 
        return 
    fi 

    log "Adding AJP connector..."

    sed -i '/<Service name="Catalina">/ a\
    <Connector protocol="AJP/1.3" \
            address="10.100.70.45" \
            port="8009" \
            secretRequired="true" \
            secret="P@ssw0rd" \
            redirectPort="8443" />' "$TOMCAT_CONFIG"

    log_success "AJP connector added"
}

restart_tomcat() {
    systemctl restart tomcat
    log_success "Tomcat restarted"
}

verify_port() {
    for i in {1..10}; do
        if ss -lnt | grep -q ":$AJP_PORT\b"; then
            log_success "Port $AJP_PORT is listening"
            return 0
        fi
        sleep 1
    done

    log_fail "Port $AJP_PORT not listening"
}

main() {
    check_root
    backup_config
    add_ajp_connector
    restart_tomcat
    verify_port
}

main "$@"