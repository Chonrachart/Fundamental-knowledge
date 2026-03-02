#!/bin/bash

set -e

VERSION="11.0.18"
INSTALL_DIR="/opt/tomcat"
INSTALL_TARGET="$INSTALL_DIR/apache-tomcat-$VERSION"
TOMCAT_CONFIG="$INSTALL_TARGET/conf/server.xml"
TAR_FILE="$INSTALL_DIR/apache-tomcat-$VERSION.tar.gz"
URL="https://dlcdn.apache.org/tomcat/tomcat-11/v$VERSION/bin/apache-tomcat-$VERSION.tar.gz"

######### This section need to change to install another version ############
################### Can't use with install sameversion ######################
SERVICE_NAME="tomcat"
SYMLINK_NAME="apache-tomcat"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"  ## change unique service name
SYMLINK="$INSTALL_DIR/$SYMLINK_NAME"               ## change to unique symlink name
JMX_PORT="9010"
SHUTDOWN_PORT="8005"
HTTP_PORT="8080"
##############################################################################


check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[FAIL] Run as root"
        exit 1
    fi
}

make_dir() {
    mkdir -p "$INSTALL_DIR"
}

download_gz() {
    if [ ! -f "$TAR_FILE" ]; then
        echo "[INFO] Downloading Tomcat $VERSION..."
        wget -P "$INSTALL_DIR" "$URL"
    else
        echo "[INFO] $TAR_FILE already exists"
    fi
}

extract_tomcat() {
    if [ ! -d "$INSTALL_TARGET" ]; then
        echo "[INFO] Extracting Tomcat..."
        tar -xzf "$TAR_FILE" -C "$INSTALL_DIR"
    else
        echo "[INFO] Tomcat version already extracted."
    fi

    echo "[INFO] Updating symlink..."
    ln -sfn "$INSTALL_TARGET" "$SYMLINK"
}

create_tomcat_user() {
    if id "tomcat" &>/dev/null; then
        echo "[INFO] User 'tomcat' already exists."
    else
        echo "[INFO] Creating system user 'tomcat'..."
        useradd -r -m -U -d "$INSTALL_DIR" -s /bin/false tomcat
        echo "[SUCCESS] User created."
    fi

    chown -R tomcat:tomcat "$INSTALL_TARGET"
}

verify_tomcat() {
    if [ -f "$SYMLINK/bin/startup.sh" ]; then
        echo "[SUCCESS] Tomcat installation verified."
    else
        echo "[FAIL] Tomcat installation failed."
        exit 1
    fi
}

create_service() {

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/opt/java/java
Environment=CATALINA_HOME=$SYMLINK

ExecStart=$SYMLINK/bin/startup.sh
ExecStop=$SYMLINK/bin/shutdown.sh

User=tomcat
Group=tomcat
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    echo "[SUCCESS] Systemd service created/updated."
}

configure_tomcat_user() {
    TOMCAT_USERS_FILE="$SYMLINK/conf/tomcat-users.xml"

    [ -f "$TOMCAT_USERS_FILE.bkp" ] || cp "$TOMCAT_USERS_FILE" "$TOMCAT_USERS_FILE.bkp"

    if ! grep -q 'username="tomcat" password="tomcat"' "$TOMCAT_USERS_FILE"; then
        sed -i '/<\/tomcat-users>/ i\
  <role rolename="manager-gui"/>\
  <role rolename="admin-gui"/>\
  <role rolename="manager-status"/>\
  <user username="tomcat" password="tomcat" roles="manager-gui,manager-status,admin-gui"/>' "$TOMCAT_USERS_FILE"

        echo "[SUCCESS] Manager user added."
    else
        echo "[INFO] Manager user already exists."
    fi
}

configure_manager_context() { 
    CONTEXT_FILE="$INSTALL_TARGET/webapps/manager/META-INF/context.xml" 
    if grep -q '10.0.0.0/8' "$CONTEXT_FILE"; then 
        echo "[INFO] 10.0.0.0/8 already allowed for manager_context.xml." 
    else 
        sed -i 's|allow="127.0.0.0/8,::1/128"|allow="10.0.0.0/8,127.0.0.0/8,::1/128"|' "$CONTEXT_FILE" 
        echo "[SUCCESS] Added 10.0.0.0/8 to manager allow rule." 
    fi
} 

configure_host_manager_context() { 
    CONTEXT_FILE="$INSTALL_TARGET/webapps/host-manager/META-INF/context.xml" 
    if grep -q '10.0.0.0/8' "$CONTEXT_FILE"; then 
        echo "[INFO] 10.0.0.0/8 already allowed for host_manager_context.xml." 
    else 
        sed -i 's|allow="127.0.0.0/8,::1/128"|allow="10.0.0.0/8,127.0.0.0/8,::1/128"|' "$CONTEXT_FILE" 
        echo "[SUCCESS] Added 10.0.0.0/8 to host_manager allow rule." 
    fi 
}

enable_jmx() {
    SETENV_FILE="$SYMLINK/bin/setenv.sh"

    if [ ! -f "$SETENV_FILE" ]; then
        cat > "$SETENV_FILE" <<EOF
CATALINA_OPTS="\$CATALINA_OPTS \
-Dcom.sun.management.jmxremote \
-Dcom.sun.management.jmxremote.port=$JMX_PORT \
-Dcom.sun.management.jmxremote.rmi.port=$JMX_PORT \
-Dcom.sun.management.jmxremote.local.only=false \
-Dcom.sun.management.jmxremote.authenticate=false \
-Dcom.sun.management.jmxremote.ssl=false \
-Djava.rmi.server.hostname=$(hostname -I | awk '{print $1}')"
EOF
        echo "[SUCCESS] JMX enabled."
    else
        echo "[INFO] JMX already configured."
    fi
}

config_http_port() {

    if grep -q '<Connector port="8080"' "$TOMCAT_CONFIG"; then
        echo "[INFO] Changing HTTP port..."

        cp "$TOMCAT_CONFIG" "${TOMCAT_CONFIG}.bkp.$(date +%F-%H%M%S)"

        sed -i "s/port=\"8080\"/port=\"${HTTP_PORT}\"/" "$TOMCAT_CONFIG"

        echo "[SUCCESS] HTTP Port changed"
    else
        echo "[INFO] HTTP Port already customized"
    fi
}

config_shutdown_port() {

    if grep -q '<Server port="8005"' "$TOMCAT_CONFIG"; then
        echo "[INFO] Changing shutdown port..."

        cp "$TOMCAT_CONFIG" "${TOMCAT_CONFIG}.bkp.$(date +%F-%H%M%S)"

        sed -i "s/<Server port=\"8005\"/<Server port=\"${SHUTDOWN_PORT}\"/" "$TOMCAT_CONFIG"

        echo "[SUCCESS] Shutdown port changed"
    else
        echo "[INFO] Shutdown port already customized"
    fi
}

main() {
    check_root
    make_dir
    download_gz
    extract_tomcat
    create_tomcat_user
    verify_tomcat
    create_service
    configure_tomcat_user
    configure_manager_context
    configure_host_manager_context
    enable_jmx
    config_http_port
    config_shutdown_port

    systemctl enable "$SERVICE_NAME"
    systemctl restart "$SERVICE_NAME"

    echo "[SUCCESS] Tomcat $VERSION deployed successfully."
    echo "[INFO] Symlink points to: $INSTALL_TARGET"
    echo "[WARNING] This is hardcode to tomcat version 11.0.18 !!!!"
}

main "$@"

### in old system it may be not create service it use /etc/init.d/tomcat
### in this script it set in setenv.sh