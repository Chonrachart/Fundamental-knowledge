#!/bin/bash

set -e

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "[FAIL] No root privilege"
        exit 1
    fi
}

install_zabbix_gateway() {

    echo "Installing Zabbix Java Gateway..."
    apt update -y > /dev/null
    apt install -y zabbix-java-gateway > /dev/null || {
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

configuration_server() {

    SERVER_CONF="/etc/zabbix/zabbix_server.conf"
    
    [ -f "$SERVER_CONF.bkp" ] || cp "$SERVER_CONF" "$SERVER_CONF.bkp"

    echo "[INFO] Configuring Zabbix Server..."

    # JavaGateway
    if grep -q "^[#[:space:]]*JavaGateway=" "$SERVER_CONF"; then
        sed -i 's|^[#[:space:]]*JavaGateway=.*|JavaGateway=127.0.0.1|' "$SERVER_CONF"
    else
        echo "JavaGateway=127.0.0.1" >> "$SERVER_CONF"
    fi

    # JavaGatewayPort
    if grep -q "^[#[:space:]]*JavaGatewayPort=" "$SERVER_CONF"; then
        sed -i 's|^[#[:space:]]*JavaGatewayPort=.*|JavaGatewayPort=10052|' "$SERVER_CONF"
    else
        echo "JavaGatewayPort=10052" >> "$SERVER_CONF"
    fi

    # StartJavaPollers
    if grep -q "^[#[:space:]]*StartJavaPollers=" "$SERVER_CONF"; then
        sed -i 's|^[#[:space:]]*StartJavaPollers=.*|StartJavaPollers=5|' "$SERVER_CONF"
    else
        echo "StartJavaPollers=5" >> "$SERVER_CONF"
    fi

    echo "[SUCCESS] Zabbix Server configured."
}

restart_zabbix() {
    systemctl enable zabbix-java-gateway > /dev/null
    systemctl restart zabbix-java-gateway > /dev/null
    systemctl restart zabbix-server > /dev/null
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
    install_zabbix_gateway
    configure_java_gateway
    configuration_server
    restart_zabbix
    check_zabbix
}

main "$@"


