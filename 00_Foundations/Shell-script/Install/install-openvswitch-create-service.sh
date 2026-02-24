


[Unit]
Description=OpenVSwitch [service-name] Service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=root
RemainAfterExit=yes
ExecStart=/etc/network/openvswitch/[setup-file].bash
ExecStop=/usr/bin/ovs-vsctl del-br [bridge-name]

[Install]
WantedBy=multi-user.target