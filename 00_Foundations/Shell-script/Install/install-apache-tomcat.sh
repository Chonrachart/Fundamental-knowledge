#!/bin/bash

set -e

INSTALL_DIR="/opt/tomcat"
INSTALL_TARGET="$INSTALL_DIR/apache-tomcat-11.0.18"
TAR_FILE="$INSTALL_DIR/apache-tomcat-11.0.18.tar.gz"
URL="https://dlcdn.apache.org/tomcat/tomcat-11/v11.0.18/bin/apache-tomcat-11.0.18.tar.gz"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "No root privilege"
        exit 1
    fi
}

download_gz() {
    if [ ! -f "$TAR_FILE" ]; then
        wget -P "$INSTALL_DIR" "$URL"
    else
        echo "$TAR_FILE already exists"
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
        echo "Tomcat already installed."
    fi
}

verify_tomcat() {
    if [ -f "$INSTALL_TARGET/bin/startup.sh" ]; then
        echo "Tomcat installation verified."
    else
        echo "Tomcat installation failed!"
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
        echo "Tomcat systemd service created."
    else
        echo "Tomcat systemd service already exist."
    fi
}

configure_tomcat_user() {
    TOMCAT_USERS_FILE="$INSTALL_TARGET/conf/tomcat-users.xml"
    [ -f "$TOMCAT_USERS_FILE.bkp" ] || cp "$TOMCAT_USERS_FILE" "$TOMCAT_USERS_FILE.bkp" 

    if ! grep -q 'username="tomcat" password="tomcat" ' "$TOMCAT_USERS_FILE"; then
        sed -i '/<\/tomcat-users>/ i\
  <role rolename="manager-gui"/>\
  <role rolename="admin-gui"/>\
  <role rolename="manager-status"/>
  <user username="tomcat" password="tomcat" roles="manager-gui,manager-status,admin-gui"/>' "$TOMCAT_USERS_FILE"

        echo "Tomcat manager user added."
    else
        echo "Tomcat manager user already exists."
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
    echo "This is hardcode to tomcat version 11.0.18 !!!!"
}

main "$@"