# Multicast and Broadcast

- Unicast sends to one destination; broadcast sends to all devices on a LAN; multicast sends to a subscribed group.
- Broadcast is confined to the local network segment — routers do not forward broadcasts (this is why DHCP relay exists).
- Multicast uses special IP addresses (224.0.0.0/4) and IGMP to manage group membership.

# Architecture

```text
Unicast (1:1):
  Host A ─────────────────────→ Host B
  Only Host B receives the frame

Broadcast (1:all):
  Host A ─────────────────────→ All devices on LAN
  Dst MAC: FF:FF:FF:FF:FF:FF
  Every device must process the frame (even if irrelevant)
  Does NOT cross routers

Multicast (1:group):
  Host A ─────────────────────→ Group members only
  Dst IP: 239.1.1.1 (multicast group)
  Only devices that joined this group receive the frame
  Can cross routers (if multicast routing is enabled)
```

# Mental Model

```text
Analogy:
  Unicast    = phone call (one-to-one)
  Broadcast  = shouting in a room (everyone hears, whether they want to or not)
  Multicast  = radio channel (only people who tuned in hear it)

When is each used?
  Unicast:    most traffic — HTTP, SSH, email, API calls
  Broadcast:  ARP requests, DHCP Discover, network discovery
  Multicast:  video streaming, mDNS, OSPF routing updates, cluster heartbeats
```

```bash
# view multicast group memberships on Linux
ip maddr show

# view IGMP group membership
cat /proc/net/igmp
```

# Core Building Blocks

### Broadcast

- Layer 2 broadcast: destination MAC `FF:FF:FF:FF:FF:FF` — every device on the LAN receives the frame.
- Layer 3 broadcast: destination IP `255.255.255.255` (limited broadcast) or subnet broadcast (e.g., `192.168.1.255` for a /24).
- Broadcasts are confined to the local network segment — routers do not forward them (this is called a "broadcast domain").
- Used by: ARP (IP-to-MAC resolution), DHCP Discover (finding a server), NetBIOS, Wake-on-LAN.
- Problem: too many broadcasts waste bandwidth and CPU on every device — this is why large networks are segmented with VLANs.

Related notes: [002-link-layer-and-ethernet](./002-link-layer-and-ethernet.md), [004-dhcp](./004-dhcp.md)

### Multicast

- Multicast delivers packets to a group of interested receivers without sending individual copies to each one.
- Multicast IP range: `224.0.0.0/4` (224.0.0.0 – 239.255.255.255).
- Well-known multicast addresses:
  - `224.0.0.1` — all hosts on the subnet
  - `224.0.0.2` — all routers on the subnet
  - `224.0.0.5` — OSPF routers
  - `224.0.0.251` — mDNS
- IGMP (Internet Group Management Protocol): hosts use IGMP to tell routers which multicast groups they want to join or leave.
- Multicast-capable switches use IGMP snooping to deliver multicast frames only to ports with interested receivers (instead of flooding all ports).
- TTL (Time To Live) in multicast controls how far packets travel: TTL 1 = local subnet only; higher TTL = crosses routers.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### Unicast vs Broadcast vs Multicast

| Property | Unicast | Broadcast | Multicast |
|----------|---------|-----------|-----------|
| Destinations | One | All on LAN | Subscribed group |
| Dst MAC | Specific MAC | FF:FF:FF:FF:FF:FF | Multicast MAC |
| Crosses routers | Yes | No | Yes (if configured) |
| Bandwidth | Efficient for 1:1 | Wastes bandwidth | Efficient for 1:many |
| Examples | HTTP, SSH | ARP, DHCP | Video stream, mDNS |

Related notes: [005-transport-layer](./005-transport-layer.md)

### mDNS (Multicast DNS)

- mDNS allows devices to discover each other on a local network without a DNS server.
- Uses multicast address `224.0.0.251` on UDP port 5353.
- Domain: `.local` — e.g., `myprinter.local` resolves to the printer's IP.
- How it works: device sends a multicast query "Who is myprinter.local?"; the printer responds with its IP.
- Implementations: Apple Bonjour, Linux Avahi, Windows (limited support).
- Use cases: printers, smart speakers, development servers on local networks.

Related notes: [006-dns](./006-dns.md)

### Broadcast Storms

- A broadcast storm occurs when broadcast frames loop endlessly through the network, consuming all bandwidth.
- Cause: network loops — two switches connected by multiple paths without loop prevention.
- Symptoms: network slows to a crawl, switches max out CPU, devices become unreachable.
- Prevention:
  - **STP (Spanning Tree Protocol)**: detects loops and disables redundant links, keeping one active path.
  - **RSTP (Rapid STP)**: faster convergence than STP (seconds instead of 30-50 seconds).
  - **Storm control**: switches can rate-limit broadcast traffic and shut down ports exceeding thresholds.

Related notes: [002-link-layer-and-ethernet](./002-link-layer-and-ethernet.md)
