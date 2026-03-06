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

---

# Linux Networking Overview 

- Linux networking is implemented in the kernel.
- Applications use the **socket API** to create endpoints for communication.
- The kernel handles TCP/UDP, IP, routing, firewall, and physical/virtual interfaces.
- No separate user-space daemon is required for basic IP networking; the kernel does it.

### Key Components

| Component        | Role                                              |
| :--------------- | :------------------------------------------------ |
| Socket API       | Interface between application and kernel          |
| TCP/UDP          | Transport layer (ports, connections)              |
| IP layer         | Addressing, fragmentation, routing decisions      |
| Netfilter        | Packet filtering, NAT (iptables/nftables)         |
| Network interface| Physical (NIC) or virtual (lo, bridge, veth)      |

# Linux Networking Architecture 

```
┌─────────────────────────────────────────────────────────┐
│  Application (curl, nginx, sshd, etc.)                   │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  Socket API (socket, bind, connect, send, recv)           │
│  - Creates file descriptor for network I/O               │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  Transport Layer (TCP/UDP)                               │
│  - Port numbers, connections, checksums                  │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  IP Layer                                                │
│  - IP addressing, routing decision, fragmentation        │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  Netfilter (iptables / nftables)                          │
│  - Firewall, NAT, packet mangling                        │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  Network Interface Layer                                 │
│  - eth0, lo, bridge, veth pairs                          │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  NIC / Driver (hardware or virtual)                       │
└─────────────────────────────────────────────────────────┘
```

# Packet Flow Overview 

### Outgoing (Application → Wire)

1. **Process** calls `send()` on a socket.
2. **Socket** buffers data and passes to kernel.
3. **DNS resolve** (if hostname): `/etc/resolv.conf`, `systemd-resolved`, or `getaddrinfo`.
4. **Routing lookup**: kernel checks routing table to find next hop and output interface.
5. **Firewall rules**: Netfilter (iptables/nftables) processes packet (filter, nat, mangle).
6. **Network interface**: packet is queued and sent out via the chosen interface.
7. **Packet transmitted** on the wire (or to another namespace/VM).

### Incoming (Wire → Application)

1. **NIC** receives frame; driver passes to kernel.
2. **Netfilter** processes (prerouting, input chains).
3. **Routing**: if for local host, goes to input; else forwarded.
4. **Transport**: TCP/UDP demultiplexes by port to socket.
5. **Application** receives via `recv()`.

# Network Isolation Concept 

- **Network namespaces** provide isolated network stacks on one host.
- Each namespace has its own interfaces, routing tables, and firewall rules.
- Used by: containers (Docker, Podman), VMs, VPNs, complex network topologies.
- See [007-Network-namespace](./007-Network-namespace.md) for details.

# Topic Map

- [001-Network-interface](./001-Network-interface.md) — Physical vs virtual interfaces
- [002-ip-command](./002-ip-command.md) — `ip` configuration tool
- [003-Route-table](./003-Route-table.md) — Routing tables and rules
- [004-Socket-and-Port](./004-Socket-and-Port.md) — Sockets and ports
- [005-dns-resolution-linux](./005-dns-resolution-linux.md) — DNS resolution on Linux
- [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md) — Firewall (iptables, nftables)
- [007-Network-namespace](./007-Network-namespace.md) — Network namespaces
- [008-Packet-flow](./008-Packet-flow.md) — Packet flow through the stack


