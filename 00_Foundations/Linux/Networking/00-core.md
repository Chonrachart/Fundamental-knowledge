1. Linux networking overview
Linux implements networking inside the kernel network stack.

Applications communicate through sockets, which interact with the
kernel networking subsystem to send and receive packets through
network interfaces.

2. Linux networking architecture
diagram ง่าย ๆ

Application
    ↓
Socket API
    ↓
TCP / UDP
    ↓
IP layer
    ↓
Routing decision
    ↓
Netfilter (iptables/nftables)
    ↓
Network interface
    ↓
NIC / driver

3. Packet flow overview
   Process → socket
        ↓
DNS resolve
        ↓
Routing lookup
        ↓
Firewall rules
        ↓
Network interface
        ↓
Packet transmitted


4. Network isolation concept

Linux supports network namespaces, allowing multiple isolated
network stacks on the same system
   


