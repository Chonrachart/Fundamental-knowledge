### this set network via openvswitch

### this set where system initial should start


<!-- Your original notes below — reorganize into subsections -->

# -- set Interface vnet-trust99 type=internal this tell linux it vNIC that can see by linux

/sbin/ip addr add [ip/CIDR] dev [port_namevnet]
/sbin/ip link set [NIC1] [NIC2] up
/sbin/ip link set [bridge_name] up
/sbin/ip link set [port_name] up

/sbin/ip route add default via [ip_gateway]

## Add route
#/sbin/ip route add [ip/CIDR] via [ip_gateway]
## Ping outside gateway for trigger packet
# echo $(date) > /tmp/vnet-ping-result
# SEC=1
# while [ $SEC -lt 90 ]
# do
#  /bin/ping -c1 [ip_gateway] >> /tmp/vnet-ping-result
#  if [ $? -eq 0 ]
#  then
#   SEC=90
#  fi
#  SEC=$[$SEC+1]
# done
```

### this set where system initial should start

- at /etc/systemd/system/[script_name].service

```bash
[Unit]
Description=OpenVSwitch vnet-trust Service
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=root
RemainAfterExit=yes
ExecStart=/etc/network/openvswitch/[script-name].bash
ExecStop=/usr/bin/ovs-vsctl del-br [bridge_name]

[Install]
WantedBy=multi-user.target
```
