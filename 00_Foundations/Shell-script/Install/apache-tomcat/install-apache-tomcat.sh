#!/bin/bash

set -e

INSTALL_DIR="/opt/tomcat"
INSTALL_TARGET="$INSTALL_DIR/apache-tomcat-11.0.18"
TAR_FILE="$INSTALL_DIR/apache-tomcat-11.0.18.tar.gz"
URL="https://dlcdn.apache.org/tomcat/tomcat-11/v11.0.18/bin/apache-tomcat-11.0.18.tar.gz"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[FAIL] No root privilege"
        exit 1
    fi
}

download_gz() {
    if [ ! -f "$TAR_FILE" ]; then
        wget -P "$INSTALL_DIR" "$URL"
    else
        echo "[INFO] $TAR_FILE already exists"
    fi
}

make_dir() {
    mkdir -p "$INSTALL_DIR"
}

extract_tomcat() {
    if [ ! -d "$INSTALL_TARGET" ]; then
        echo "Extracting Tomcat..."
        tar -xzf "$TAR_FILE" -C "$INSTALL_DIR"
    else
        echo "[INFO] Tomcat already installed."
    fi
}

verify_tomcat() {
    if [ -f "$INSTALL_TARGET/bin/startup.sh" ]; then
        echo "[SUCCESS] Tomcat installation verified."
    else
        echo "[FAIL] Tomcat installation failed!"
        exit 1
    fi
}


create_service() {
    SERVICE_FILE="/etc/systemd/system/tomcat.service"
    if [ ! -f "$SERVICE_FILE" ]; then
        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/opt/java/jdk-21.0.10
Environment=CATALINA_HOME=/opt/tomcat/apache-tomcat-11.0.18

ExecStart=/opt/tomcat/apache-tomcat-11.0.18/bin/startup.sh
ExecStop=/opt/tomcat/apache-tomcat-11.0.18/bin/shutdown.sh

User=root
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl start tomcat
        echo "[SUCCESS] Tomcat systemd service created."
    else
        echo "[INFO] Tomcat systemd service already exist."
    fi
}

configure_tomcat_user() {
    TOMCAT_USERS_FILE="$INSTALL_TARGET/conf/tomcat-users.xml"
    [ -f "$TOMCAT_USERS_FILE.bkp" ] || cp "$TOMCAT_USERS_FILE" "$TOMCAT_USERS_FILE.bkp" 

    if ! grep -q 'username="tomcat" password="tomcat" ' "$TOMCAT_USERS_FILE"; then
        sed -i '/<\/tomcat-users>/ i\
  <role rolename="manager-gui"/>\
  <role rolename="admin-gui"/>\
  <role rolename="manager-status"/>\
  <user username="tomcat" password="tomcat" roles="manager-gui,manager-status,admin-gui"/>' "$TOMCAT_USERS_FILE"

        echo "[SUCCESS] Tomcat manager user added."
    else
        echo "[INFO] Tomcat manager user already exists."
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

Enable_JMX() {
    SETENV_FILE="$INSTALL_TARGET/bin/setenv.sh"
    if [ ! -f "$SETENV_FILE" ]; then
        cat > "$SETENV_FILE" <<EOF
CATALINA_OPTS="\$CATALINA_OPTS \
-Dcom.sun.management.jmxremote \
-Dcom.sun.management.jmxremote.port=9010 \
-Dcom.sun.management.jmxremote.rmi.port=9010 \
-Dcom.sun.management.jmxremote.local.only=false \
-Dcom.sun.management.jmxremote.authenticate=false \
-Dcom.sun.management.jmxremote.ssl=false \
-Djava.rmi.server.hostname=10.100.70.45"
EOF
    else
        echo "[INFO] Already have setenv.sh"
    fi

}

install_zabbix_gateway() {

    echo "Installing Zabbix Java Gateway..."
    apt update -yqq > /dev/null
    apt install -qy zabbix-java-gateway > /dev/null || {
        echo "[FAIL]Install failed"
        return 1
    }
}

configure_java_gateway() {
    JAVA_GATEWAY_CONF="/etc/zabbix/zabbix_java_gateway.conf"

    [ -f "$JAVA_GATEWAY_CONF.bkp" ] || cp "$JAVA_GATEWAY_CONF" "$JAVA_GATEWAY_CONF.bkp"

    sed -i 's|^[#[:space:]]*LISTEN_IP=.*|LISTEN_IP="0.0.0.0"|' "$JAVA_GATEWAY_CONF"
    sed -i 's|^[#[:space:]]*LISTEN_PORT=.*|LISTEN_PORT=10052|' "$JAVA_GATEWAY_CONF"
    sed -i 's|^[#[:space:]]*START_POLLERS=.*|START_POLLERS=5|' "$JAVA_GATEWAY_CONF"

    echo "[SUCCESS] Java Gateway configured."
}

restart_zabbix() {
    systemctl enable zabbix-java-gateway > /dev/null
    systemctl restart zabbix-java-gateway > /dev/null
}

check_zabbix() {
    if ss -tulpn | grep -q ":10052" ;then
        echo "[SUCCESS] install JMX success"
    else
        echo "[FAIL] install JMX failed"
        return 1
    fi
}



main() {
    check_root
    make_dir
    download_gz
    extract_tomcat
    verify_tomcat
    create_service
    configure_tomcat_user
    configure_manager_context
    configure_host_manager_context
    Enable_JMX
    install_zabbix_gateway
    configure_java_gateway
    restart_zabbix
    check_zabbix
    systemctl restart tomcat
    echo "[WARNING] You need to config zabbix server if needed"
    echo "[WARNING] This is hardcode to tomcat version 11.0.18 !!!!"
    echo "[WARNING] This is hardcode to tomcat server 10.100.70.45 !!!!"
}

# ADD this in server_zabbix in /etc/zabbix/zabbix_server.d/*.conf
# JavaGateway=10.100.70.45
# JavaGatewayPort=10052
# StartJavaPollers=5


main "$@"