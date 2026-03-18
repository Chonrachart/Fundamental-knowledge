# Packet Flow Through Linux Network Stack

- Every packet traverses a defined path through the kernel: socket layer, transport, IP, Netfilter hooks, and NIC driver
- Routing decisions determine whether a packet is delivered locally, forwarded, or sent out
- Netfilter hooks (PREROUTING, INPUT, FORWARD, OUTPUT, POSTROUTING) allow filtering and NAT at each stage

# Architecture

```text
  +------------------+          +------------------+
  |   Application    |          |   Application    |
  |   send()/write() |          |   recv()/read()  |
  +--------+---------+          +--------+---------+
           |                             ^
           v                             |
  +--------+---------+          +--------+---------+
  |   Socket Layer    |          |   Socket Layer    |
  +--------+---------+          +--------+---------+
           |                             ^
           v                             |
  +--------+---------+          +--------+---------+
  |  TCP/UDP          |          |  TCP/UDP          |
  |  (add/strip hdr)  |          |  (demux by port)  |
  +--------+---------+          +--------+---------+
           |                             ^
           v                             |
  +--------+---------+          +--------+---------+
  |  IP Layer         |          |  IP Layer         |
  |  (hdr, routing)   |          |  (strip hdr)      |
  +--------+---------+          +--------+---------+
           |                             ^
           v                             |
  +------------------------------------------------+
  |              Netfilter Hooks                    |
  |  OUTPUT -> routing -> POSTROUTING  (outgoing)   |
  |  PREROUTING -> routing -> INPUT    (incoming)   |
  |  PREROUTING -> routing -> FORWARD -> POSTROUTING|
  +------------------------+------------------------+
                           |
                           v
                  +--------+---------+
                  |  Network Driver   |
                  |  (Ethernet hdr)   |
                  +--------+---------+
                           |
                           v
                  +--------+---------+
                  |       NIC        |
                  |   (wire/air)     |
                  +------------------+
```

# Mental Model

```text
OUTGOING (Application -> Wire):
  App -> Socket -> TCP/UDP -> IP -> NF:OUTPUT -> Routing -> NF:POSTROUTING -> Driver -> NIC

INCOMING (Wire -> Application):
  NIC -> Driver -> IP -> NF:PREROUTING -> Routing decision
                                            |
                              +---------+   +----------+
                              | Local   |              | Forward  |
                              v                        v
                         NF:INPUT                 NF:FORWARD
                              |                        |
                         TCP/UDP demux            NF:POSTROUTING
                              |                        |
                         Socket -> App            Out via NIC

FORWARDED (through host):
  NIC -> NF:PREROUTING -> Routing -> NF:FORWARD -> NF:POSTROUTING -> NIC
  (requires net.ipv4.ip_forward=1)
```

```bash
# Example: trace where a packet would be filtered
# Outgoing SSH connection from this host:
#   App (ssh) -> Socket -> TCP (sport:random, dport:22)
#   -> IP (src: local, dst: remote) -> NF:OUTPUT -> Routing
#   -> NF:POSTROUTING (MASQUERADE if NAT) -> eth0 -> wire

# Check if forwarding is enabled
sysctl net.ipv4.ip_forward
# Enable forwarding
sysctl -w net.ipv4.ip_forward=1
```

# Core Building Blocks

### Outgoing Packet Flow (Application to Wire)

1. **Application** -- calls `send()` or `write()` on a socket; data copied into kernel socket buffer
2. **Socket Layer** -- kernel looks up socket (protocol, local/remote IP:port); prepares for transport
3. **Transport (TCP/UDP)** -- TCP: segments data, adds header (ports, sequence, checksum); UDP: adds header
4. **IP Layer** -- adds IP header (src/dst IP, TTL); performs routing lookup for interface and next hop; may fragment if exceeding MTU
5. **Netfilter OUTPUT** -- iptables/nftables OUTPUT chain; can filter, NAT, or mangle
6. **Routing (final)** -- determines final output interface after OUTPUT chain
7. **Netfilter POSTROUTING** -- SNAT/MASQUERADE; last modification point before send
8. **Network Driver** -- adds Ethernet header (src/dst MAC); queues frame for transmission
9. **NIC** -- sends bits on the wire

```text
Application (send)
    |
Socket buffer
    |
TCP/UDP (add transport header)
    |
IP (add IP header, routing lookup)
    |
Netfilter OUTPUT
    |
Routing (final interface)
    |
Netfilter POSTROUTING (NAT)
    |
Network interface (add Ethernet header)
    |
NIC -> Wire
```

Related notes: [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md), [004-Socket-and-Port](./004-Socket-and-Port.md)

### Incoming Packet Flow (Wire to Application)

1. **NIC** -- receives frame; driver passes to kernel
2. **Network Driver** -- strips Ethernet header; passes to IP layer
3. **Netfilter PREROUTING** -- DNAT, raw table, connection tracking; can change destination before routing
4. **Routing Decision** -- local destination: go to INPUT; forward destination: go to FORWARD
5. **Netfilter INPUT or FORWARD** -- filter table: accept, drop, reject; forwarded packets then go to POSTROUTING
6. **Transport (for local)** -- TCP/UDP demultiplexes by port; finds matching socket; data copied to socket buffer
7. **Application** -- `recv()` or `read()` returns data

```text
Wire -> NIC
    |
Network interface (strip Ethernet)
    |
Netfilter PREROUTING (DNAT)
    |
Routing: local or forward?
    |                          |
INPUT (local)              FORWARD (forwarded)
    |                          |
Netfilter filter           Netfilter FORWARD
    |                          |
TCP/UDP demux              POSTROUTING
    |                          |
Socket -> Application      Out via NIC
```

Related notes: [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md), [003-Route-table](./003-Route-table.md)

### Forwarded Packets

- When Linux acts as a router, packets not destined for the local host are forwarded
- Flow: PREROUTING -> Routing -> FORWARD -> POSTROUTING -> out
- Requires `net.ipv4.ip_forward=1` (disabled by default)

```bash
# Enable IPv4 forwarding (runtime)
sysctl -w net.ipv4.ip_forward=1

# Enable permanently
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p
```

Related notes: [003-Route-table](./003-Route-table.md), [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md), [007-Network-namespace](./007-Network-namespace.md)

---

# Troubleshooting Guide

```text
Packet not reaching destination?
  |
  +-> Is the packet leaving the application?
  |     ss -tnp / tcpdump on lo
  |
  +-> Check routing table
  |     ip route get <dest-ip>
  |
  +-> Is Netfilter dropping it?
  |     iptables -L -n -v  (check counters on DROP rules)
  |     nft list ruleset
  |
  +-> For forwarded traffic:
  |     - Is ip_forward=1?
  |     - Check FORWARD chain rules
  |     - Check POSTROUTING NAT rules
  |
  +-> Capture at each stage with tcpdump
        tcpdump -i eth0 host <ip>        (NIC level)
        tcpdump -i any host <ip>         (all interfaces)
```

# Quick Facts (Revision)

- Outgoing: App -> Socket -> TCP/UDP -> IP -> OUTPUT -> Routing -> POSTROUTING -> NIC
- Incoming: NIC -> PREROUTING -> Routing -> INPUT -> TCP/UDP -> Socket -> App
- Forwarded: NIC -> PREROUTING -> Routing -> FORWARD -> POSTROUTING -> NIC
- Routing decision determines local delivery (INPUT) vs forwarding (FORWARD)
- Netfilter hooks allow filtering and NAT at five defined points in the path
- `net.ipv4.ip_forward=1` must be set for Linux to forward packets between interfaces
- Sockets are the endpoint; transport layer demuxes to the correct socket by IP:port
- POSTROUTING is the last Netfilter hook before a packet leaves the host
