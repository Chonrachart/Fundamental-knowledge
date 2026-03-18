# Linux Networking Overview

- Linux implements networking inside the kernel network stack; no separate user-space daemon is required for basic IP networking
- Applications use the socket API to create endpoints; the kernel handles TCP/UDP, IP, routing, firewall, and interface management
- The stack is modular: each layer (transport, IP, netfilter, interface) can be inspected and configured independently

# Architecture

```text
┌─────────────────────────────────────────────────────────┐
│  Application (curl, nginx, sshd, etc.)                  │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  Socket API (socket, bind, connect, send, recv)         │
│  - Creates file descriptor for network I/O              │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  Transport Layer (TCP / UDP)                            │
│  - Port numbers, connections, checksums                 │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  IP Layer                                               │
│  - IP addressing, routing decision, fragmentation       │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  Netfilter (iptables / nftables)                        │
│  - Firewall, NAT, packet mangling                       │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  Network Interface Layer                                │
│  - eth0, lo, bridge, veth pairs                         │
└─────────────────────────┬───────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────┐
│  NIC / Driver (hardware or virtual)                     │
└─────────────────────────────────────────────────────────┘
```

# Mental Model

```text
Outgoing packet flow:

  Process calls send()
       │
       ▼
  Socket buffers data, passes to kernel
       │
       ▼
  DNS resolve (if hostname) ── /etc/resolv.conf, systemd-resolved
       │
       ▼
  Routing lookup ── kernel checks routing table for next hop + output interface
       │
       ▼
  Netfilter ── iptables/nftables processes packet (filter, nat, mangle)
       │
       ▼
  Network interface ── packet queued and sent via chosen interface
       │
       ▼
  Packet on the wire (or to another namespace/VM)


Incoming packet flow:

  NIC receives frame ── driver passes to kernel
       │
       ▼
  Netfilter ── prerouting, input chains
       │
       ▼
  Routing ── local host? → input chain │ else → forward chain
       │
       ▼
  Transport ── TCP/UDP demultiplexes by port to socket
       │
       ▼
  Application receives via recv()
```

Example: `curl http://example.com`

```bash
# 1. curl creates a TCP socket
# 2. DNS resolves example.com → 93.184.216.34
# 3. Kernel routing table selects default gateway + eth0
# 4. Netfilter OUTPUT chain evaluates the packet
# 5. Packet sent out eth0 to the gateway
# 6. Response follows the incoming path back to curl's socket
```

# Core Building Blocks

### Socket API

- Interface between application and kernel
- Creates file descriptors for network I/O (send, recv, bind, connect)
- Supports TCP (SOCK_STREAM) and UDP (SOCK_DGRAM)

Related notes: [004-Socket-and-Port](./004-Socket-and-Port.md)

### Transport Layer (TCP/UDP)

- Handles port numbers, connections, checksums, flow control
- TCP: reliable, connection-oriented; UDP: connectionless, best-effort

Related notes: [004-Socket-and-Port](./004-Socket-and-Port.md)

### IP Layer and Routing

- Addressing, fragmentation, routing decisions
- Kernel selects output interface and next hop via routing table (longest prefix match)

Related notes: [003-Route-table](./003-Route-table.md), [008-Packet-flow](./008-Packet-flow.md)

### Netfilter (Firewall)

- Packet filtering, NAT, packet mangling via iptables or nftables
- Hook points: prerouting, input, forward, output, postrouting

Related notes: [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md)

### Network Interfaces

- Physical (NIC): eth0, enp0s3, wlan0
- Virtual: lo (loopback), bridge (virtual switch), veth (paired interfaces for namespaces)

Related notes: [001-Network-interface](./001-Network-interface.md)

### DNS Resolution

- Resolves hostnames to IP addresses before routing
- Uses /etc/resolv.conf, /etc/nsswitch.conf, systemd-resolved

Related notes: [005-dns-resolution-linux](./005-dns-resolution-linux.md)

### Network Namespaces

- Isolated network stacks on one host: own interfaces, routing tables, firewall rules
- Used by containers (Docker, Podman), VMs, VPNs, complex network topologies

Related notes: [007-Network-namespace](./007-Network-namespace.md)

---

# Practical Command Set (Core)

```bash
# Show all interfaces and addresses
ip addr show

# Show routing table
ip route show

# Show listening sockets
ss -tlnp

# Show active connections
ss -tanp

# Trace packet path to a host
traceroute 8.8.8.8

# Test connectivity
ping -c 3 8.8.8.8

# DNS lookup
dig example.com
```

One tool per layer: `ip` for interfaces/routes, `ss` for sockets, `iptables`/`nft` for firewall.

# Troubleshooting Guide

```text
Network issue?
  │
  ├─ Interface up? ──── ip link show ──── DOWN? → ip link set <iface> up
  │
  ├─ IP assigned? ──── ip addr show ──── No IP? → ip addr add ... dev <iface>
  │
  ├─ Route exists? ──── ip route show ──── No default? → ip route add default via ...
  │
  ├─ DNS resolves? ──── dig <host> ──── Fails? → check /etc/resolv.conf
  │
  ├─ Firewall blocking? ──── iptables -L -n / nft list ruleset
  │
  └─ Port open? ──── ss -tlnp | grep :<port> ──── Not listening? → check service
```

# Quick Facts (Revision)

- Linux networking runs entirely in-kernel; applications only interact via socket API
- Packet path (outgoing): socket → transport → IP/routing → netfilter → interface → wire
- Packet path (incoming): NIC → netfilter (prerouting) → routing → transport → socket
- Routing uses longest prefix match: /24 beats /16 beats default
- `ip` (iproute2) replaces ifconfig, route, arp, and netstat
- `ss` replaces netstat for socket inspection
- Network namespaces give full stack isolation (interfaces, routes, firewall)
- Netfilter hooks: prerouting → input/forward → output → postrouting

# Topic Map

- [001-Network-interface](./001-Network-interface.md) — Physical vs virtual interfaces
- [002-ip-command](./002-ip-command.md) — `ip` configuration tool
- [003-Route-table](./003-Route-table.md) — Routing tables and rules
- [004-Socket-and-Port](./004-Socket-and-Port.md) — Sockets and ports
- [005-dns-resolution-linux](./005-dns-resolution-linux.md) — DNS resolution on Linux
- [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md) — Firewall (iptables, nftables)
- [007-Network-namespace](./007-Network-namespace.md) — Network namespaces
- [008-Packet-flow](./008-Packet-flow.md) — Packet flow through the stack
