#!/bin/bash

set -e

######### This section need to change to install another version ############
################### Can't use with install sameversion ######################
TOMCAT1_NAME="tomcat1"
TOMCAT1_HOST="10.100.70.45"
TOMCAT1_PORT="8009"
TOMCAT1_SECRET="ssw0rdP@"
TOMCAT1_SERVER_NAME="chonrachart1.somapait.com"

TOMCAT2_NAME="tomcat2"
TOMCAT2_HOST="10.100.70.45"
TOMCAT2_PORT="8010"
TOMCAT2_SECRET="P@ssw0rd"
TOMCAT2_SERVER_NAME="chonrachart2.somapait.com"
##################################SET PARAMETER###############################
WORKER_NAME="$TOMCAT1_NAME"                ## can switch to like $TOMCAT2_NAME
WORKER_HOST="$TOMCAT1_HOST"
WORKER_PORT="$TOMCAT1_PORT"
WORKER_SECRET="$TOMCAT1_SECRET"
WORKER_SERVER_NAME="$TOMCAT1_SERVER_NAME"
##############################################################################

PROPERTIES_FILE=/etc/apache2/workers.properties
JK_CONF="/etc/apache2/mods-available/jk.conf"
VHOST_FILE="/etc/apache2/sites-available/${WORKER_SERVER_NAME}.conf"

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

enable_mod_jk() {

    if ! apache2ctl -M | grep -q jk_module; then
        echo "[INFO] Enabling mod_jk..."
        a2enmod jk
        log_success "mod_jk enabled"
    else
        echo "[INFO] mod_jk already enabled"
    fi
}

create_properties_file() {

    [ -f "$PROPERTIES_FILE" ] || touch "$PROPERTIES_FILE"

    if grep -q "^worker.list=" "$PROPERTIES_FILE"; then
        if ! grep -q "^worker.list=.*${WORKER_NAME}" "$PROPERTIES_FILE"; then
            sed -i "s/^worker.list=.*/&,$WORKER_NAME/" "$PROPERTIES_FILE"
        fi
    else
        echo "worker.list=$WORKER_NAME" >> "$PROPERTIES_FILE"
    fi

    if grep -q "^worker.${WORKER_NAME}.host=" "$PROPERTIES_FILE"; then
        log "Updating existing ${WORKER_NAME} worker configuration"

        if [ -s "$PROPERTIES_FILE" ]; then
            log "Creating backup of workers.properties"
            cp "$PROPERTIES_FILE" "${PROPERTIES_FILE}.bkp.$(date +%F-%H%M%S)"
        fi

        sed -i "s|^worker.${WORKER_NAME}.host=.*|worker.${WORKER_NAME}.host=${WORKER_HOST}|" "$PROPERTIES_FILE"
        sed -i "s|^worker.${WORKER_NAME}.port=.*|worker.${WORKER_NAME}.port=${WORKER_PORT}|" "$PROPERTIES_FILE"
        sed -i "s|^worker.${WORKER_NAME}.secret=.*|worker.${WORKER_NAME}.secret=${WORKER_SECRET}|" "$PROPERTIES_FILE"

        log_success "${WORKER_NAME} updated"

    else
        log "Adding ${WORKER_NAME} worker configuration"

        cat >> "$PROPERTIES_FILE" <<EOF

worker.${WORKER_NAME}.type=ajp13
worker.${WORKER_NAME}.host=${WORKER_HOST}
worker.${WORKER_NAME}.port=${WORKER_PORT}
worker.${WORKER_NAME}.secret=${WORKER_SECRET}
worker.${WORKER_NAME}.lbfactor=1
EOF

        log_success "${WORKER_NAME} added"
    fi
}

configure_mod_jk () {

    [ -f "$JK_CONF" ] || touch "$JK_CONF"

    if grep -q "JkWorkersFile /etc/apache2/workers.properties" "$JK_CONF"; then
        log "mod_jk already correctly configured"
        return
    fi

    log "Updating mod_jk configuration"

    sed -i 's|JkWorkersFile .*|JkWorkersFile /etc/apache2/workers.properties|' "$JK_CONF"

    log_success "mod_jk config updated"
}

add_jkmount_to_vhost() {

    if [ ! -f "$VHOST_FILE" ]; then
        echo "[INFO] Creating VirtualHost for ${WORKER_SERVER_NAME}..."

        cat > "$VHOST_FILE" <<EOF 
<VirtualHost *:80>
    ServerName ${WORKER_SERVER_NAME}

    JkMount /* ${WORKER_NAME}
</VirtualHost>
EOF

        a2ensite "${WORKER_SERVER_NAME}.conf" # This will tell apache to use this conf file

        echo "[SUCCESS] VirtualHost created for ${WORKER_SERVER_NAME}"

    else
        echo "[INFO] VirtualHost already exists for ${WORKER_SERVER_NAME}"
    fi
}

enable_module() {
    systemctl restart apache2
    log_success "mod_jk config added and apache restarted"
}

main() {
    check_root
    install_apache
    install_mod_jk
    enable_mod_jk
    create_properties_file
    configure_mod_jk
    add_jkmount_to_vhost
    enable_module
}

main "$@"