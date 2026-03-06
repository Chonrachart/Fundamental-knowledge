routing decision

---

# Routing Table Overview

- The Linux kernel uses a routing table to decide where to send each packet.
- Each entry has: destination, gateway (next hop), interface, and optionally metrics.
- The kernel selects the most specific matching route (longest prefix match).

# Viewing the Routing Table

```bash
ip route show
# or
route -n
```

### Example Output

```
default via 192.168.1.1 dev eth0
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.100
10.0.0.0/8 via 192.168.1.1 dev eth0
```

- `default` — catch-all when no specific route matches
- `192.168.1.0/24 dev eth0` — directly connected network
- `10.0.0.0/8 via 192.168.1.1` — static route via gateway

# Routing Decision Process

1. Packet arrives with destination IP.
2. Kernel looks up routing table.
3. **Longest prefix match**: most specific route wins (e.g. /24 over /16 over default).
4. Result: output interface and next-hop IP (or "direct" if on same subnet).

```
Destination: 192.168.1.50
  → Match: 192.168.1.0/24 dev eth0 (direct)

Destination: 8.8.8.8
  → Match: default via 192.168.1.1 dev eth0
```

# Multiple Routing Tables

- Linux supports multiple routing tables (e.g. `main`, `local`, `default`).
- **Policy routing** uses rules to select which table to use (e.g. by source IP, fwmark).

```bash
# List routing tables
ip rule show
ip route show table main
ip route show table 100
```

### Common Tables

| Table   | Number | Purpose                    |
| :------ | :----- | :------------------------- |
| local   | 255    | Local addresses            |
| main    | 254    | Default table              |
| default | 253    | Fallback                   |

# Adding Routes

```bash
# Default gateway
ip route add default via 192.168.1.1 dev eth0

# Specific network
ip route add 172.16.0.0/16 via 192.168.1.1

# Route in specific table
ip route add default via 10.0.0.1 table 100
```

# Policy Routing Rules

- Rules determine which routing table is consulted.

```bash
# Show rules
ip rule show

# Add rule: use table 100 for packets from 10.0.0.0/24
ip rule add from 10.0.0.0/24 table 100
```

# How Routing Affects Packet Flow

- Outgoing: application → socket → transport → **routing lookup** → output interface → Netfilter → wire.
- Routing happens after transport layer; kernel needs destination IP to look up route.
- If no route: packet dropped, "Network unreachable" or "No route to host".