# Routing Table

- The Linux kernel routing table maps destination IP prefixes to next-hop gateways and output interfaces
- Route selection uses longest prefix match: the most specific route wins
- Linux supports multiple routing tables with policy rules to select between them

# Architecture

```text
┌─────────────────────────────────────────────────────────┐
│                   ip rule (policy)                       │
│  Selects which routing table to consult based on:       │
│  source IP, fwmark, incoming interface, etc.            │
└────────────────────────┬────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
   ┌────────────┐ ┌────────────┐ ┌────────────┐
   │ table local│ │ table main │ │ table 100  │
   │   (255)    │ │   (254)    │ │  (custom)  │
   │ local addrs│ │ default tbl│ │ policy rt  │
   └────────────┘ └────────────┘ └────────────┘
          │              │              │
          └──────────────┼──────────────┘
                         ▼
               Route selected:
            destination + gateway + interface
```

# Mental Model

```text
Routing decision process:

  Packet with destination IP arrives at IP layer
       │
       ▼
  1. Consult ip rules (ip rule show) to find which table to use
       │
       ▼
  2. Search selected routing table for matching entries
       │
       ▼
  3. Apply longest prefix match
     /32 > /24 > /16 > /8 > /0 (default)
       │
       ▼
  4. Result: output interface + next-hop IP
     (or "direct" if destination is on same subnet)
       │
       ▼
  No match? → "Network unreachable" / "No route to host"
```

Example: how the kernel matches a destination

```text
Routing table:
  default via 192.168.1.1 dev eth0
  192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.100
  10.0.0.0/8 via 192.168.1.1 dev eth0

Destination: 192.168.1.50
  → Match: 192.168.1.0/24 dev eth0 (direct, no gateway)

Destination: 10.5.3.1
  → Match: 10.0.0.0/8 via 192.168.1.1 dev eth0

Destination: 8.8.8.8
  → Match: default via 192.168.1.1 dev eth0
```

# Core Building Blocks

### Viewing the Routing Table

- `ip route show` displays the main routing table
- `route -n` is the legacy equivalent
- Key fields: destination prefix, `via` (next hop), `dev` (interface), `proto`, `scope`, `src`
- Routing table maps destination prefixes to next-hop + output interface
- Longest prefix match: /32 beats /24 beats /16 beats default (/0)
- `ip route get <ip>` shows exactly which route the kernel would use
- Routing happens after transport layer; kernel needs destination IP to look up route

```bash
ip route show
ip route show table main
ip route show table local
route -n
```

Related notes: [002-ip-command](./002-ip-command.md)

### Route Entry Fields

- `default` or `0.0.0.0/0` -- catch-all when no specific route matches
- `via <ip>` -- next-hop gateway
- `dev <iface>` -- output interface
- `proto kernel` -- route added automatically by the kernel
- `scope link` -- destination is directly reachable on attached network
- `src <ip>` -- preferred source address for outgoing packets
- `proto kernel` routes are auto-added when an IP is assigned to an interface
- `scope link` means the destination is directly attached (no gateway needed)

Related notes: [008-Packet-flow](./008-Packet-flow.md)

### Multiple Routing Tables

- Linux supports multiple named/numbered routing tables
- Policy routing uses `ip rule` to select which table applies

| Table   | Number | Purpose                    |
| :------ | :----- | :------------------------- |
| local   | 255    | Local addresses            |
| main    | 254    | Default table              |
| default | 253    | Fallback                   |
- Linux has three built-in tables: local (255), main (254), default (253)

```bash
# List routing tables
ip route show table main
ip route show table 100

# Add route to specific table
ip route add default via 10.0.0.1 table 100
```

Related notes: [002-ip-command](./002-ip-command.md)

### Policy Routing Rules

- Rules determine which routing table is consulted for a given packet
- Rules are evaluated in priority order (lower number = higher priority)
- Match criteria: source IP, fwmark, incoming interface

```bash
# Show rules
ip rule show

# Add rule: use table 100 for packets from 10.0.0.0/24
ip rule add from 10.0.0.0/24 table 100

# Add rule: use table 200 for packets with fwmark 1
ip rule add fwmark 1 table 200
```
- `ip rule` controls which table is consulted (policy routing)

Related notes: [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md)

### Adding and Deleting Routes

```bash
# Default gateway
ip route add default via 192.168.1.1 dev eth0

# Specific network
ip route add 172.16.0.0/16 via 192.168.1.1

# Route in specific table
ip route add default via 10.0.0.1 table 100

# Delete routes
ip route del default
ip route del 172.16.0.0/16
```

Related notes: [002-ip-command](./002-ip-command.md)


---

# Troubleshooting Guide

```text
Packet not reaching destination?
  │
  ├─ Route exists? ──── ip route show ──── No match? → ip route add ...
  │
  ├─ Correct gateway? ──── ip route get <dest_ip> ──── Wrong via? → fix route
  │
  ├─ Gateway reachable? ──── ping <gateway> ──── No reply? → check L2/interface
  │
  ├─ Policy rules? ──── ip rule show ──── Wrong table? → ip rule add/del
  │
  └─ "No route to host"? ──── no matching entry in any consulted table → add route
```
