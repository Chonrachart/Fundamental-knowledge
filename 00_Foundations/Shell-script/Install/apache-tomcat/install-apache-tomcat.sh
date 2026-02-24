#!/bin/bash

set -e

VERSION="11.0.18"
INSTALL_DIR="/opt/tomcat"
INSTALL_TARGET="$INSTALL_DIR/apache-tomcat-$VERSION"
SYMLINK="$INSTALL_DIR/apache-tomcat"
TAR_FILE="$INSTALL_DIR/apache-tomcat-$VERSION.tar.gz"
URL="https://dlcdn.apache.org/tomcat/tomcat-11/v$VERSION/bin/apache-tomcat-$VERSION.tar.gz"

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
    SERVICE_FILE="/etc/systemd/system/tomcat.service"

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Apache Tomcat
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/opt/java/jdk-21.0.10
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

    if ! grep -q 'username="tomcat"' "$TOMCAT_USERS_FILE"; then
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

enable_jmx() {
    SETENV_FILE="$SYMLINK/bin/setenv.sh"

    if [ ! -f "$SETENV_FILE" ]; then
        cat > "$SETENV_FILE" <<EOF
CATALINA_OPTS="\$CATALINA_OPTS \
-Dcom.sun.management.jmxremote \
-Dcom.sun.management.jmxremote.port=9010 \
-Dcom.sun.management.jmxremote.rmi.port=9010 \
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

main() {
    check_root
    make_dir
    download_gz
    extract_tomcat
    create_tomcat_user
    verify_tomcat
    create_service
    configure_tomcat_user
    enable_jmx

    systemctl enable tomcat
    systemctl restart tomcat

    echo "[SUCCESS] Tomcat $VERSION deployed successfully."
    echo "[INFO] Symlink points to: $INSTALL_TARGET"
}

main "$@"