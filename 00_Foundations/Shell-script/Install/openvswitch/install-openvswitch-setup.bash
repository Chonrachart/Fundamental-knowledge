#!/bin/bash

/usr/bin/ovs-vsctl add-br [bridge-name]
/usr/bin/ovs-vsctl add-bond [bridge-name] [bond-name] [NIC] [NIC] bond_mode=active-backup
/usr/bin/ovs-vsctl add-port [bridge-name] [port-name] -- set Interface [port-name] type=internal
/usr/bin/ovs-vsctl set port [port-name] tag=[VLAN-id]

/sbin/ip addr add [ip/CIDR] [port-name]
/sbin/ip link set [NIC] [NIC] up
/sbin/ip link set [bridge-name] up
/sbin/ip link set [port-name] up

/sbin/ip route add default via [gateway-ip]


