# ip Command

- `ip` is the modern Linux networking configuration tool from the `iproute2` package, replacing `ifconfig`, `route`, and `arp`
- Organized by object type: `ip addr`, `ip link`, `ip route`, `ip neigh`, `ip netns`
- Changes made with `ip` are runtime-only; they do not persist across reboots unless scripted or managed by a network service

# Architecture

```text
┌─────────────────────────────────────────────────────┐
│                    ip command                        │
├──────────┬──────────┬──────────┬──────────┬─────────┤
│ ip addr  │ ip link  │ ip route │ ip neigh │ ip netns│
│ L3 addrs │ L2 iface │ routing  │ ARP/NDP  │ netns   │
├──────────┴──────────┴──────────┴──────────┴─────────┤
│              Replaces legacy tools:                  │
│  ifconfig    ifconfig   route      arp      --       │
└─────────────────────────────────────────────────────┘
```

# Mental Model

```text
Static IP configuration workflow:

  1. Assign IP to interface
     ip addr add 192.168.1.100/24 dev eth0
            │
            ▼
  2. Bring interface up
     ip link set eth0 up
            │
            ▼
  3. Set default gateway
     ip route add default via 192.168.1.1
            │
            ▼
  4. Verify
     ip addr show eth0
     ip route show
     ping -c 1 192.168.1.1
```

Example: full static IP setup

```bash
ip addr add 192.168.1.100/24 dev eth0
ip link set eth0 up
ip route add default via 192.168.1.1
```

# Core Building Blocks

### ip addr (Address Management)

- View and configure IP addresses on interfaces
- Key output fields: `inet` (IPv4 + CIDR), `inet6` (IPv6), `scope` (global/link/host), `state` (UP/DOWN)

```bash
# Show all addresses
ip addr show
ip a

# Show only IPv4
ip -4 addr show

# Add IP to interface
ip addr add 192.168.1.10/24 dev eth0

# Remove IP
ip addr del 192.168.1.10/24 dev eth0
```

Related notes: [001-Network-interface](./001-Network-interface.md)

### ip link (Interface Management)

- Manage network interfaces at Layer 2: bring up/down, set MTU, rename, create virtual interfaces

```bash
# List interfaces
ip link show

# Bring interface up/down
ip link set eth0 up
ip link set eth0 down

# Set MTU
ip link set eth0 mtu 1500

# Rename interface (must be down)
ip link set eth0 name eth1
```

Related notes: [001-Network-interface](./001-Network-interface.md)

### ip route (Routing Table)

- View and modify the kernel routing table
- Key fields: `default` or `0.0.0.0/0` (default gateway), `via` (next hop IP), `dev` (output interface)

```bash
# Show routing table
ip route show
ip r

# Add default gateway
ip route add default via 192.168.1.1

# Add route to specific network
ip route add 10.0.0.0/8 via 192.168.1.1 dev eth0

# Delete route
ip route del default
ip route del 10.0.0.0/8
```

Related notes: [003-Route-table](./003-Route-table.md)

### ip neigh (ARP / Neighbor Table)

- View and manage ARP/neighbor cache (IP to MAC address mapping)

```bash
# Show neighbor table
ip neigh show

# Flush ARP cache
ip neigh flush all
```

Related notes: [001-Network-interface](./001-Network-interface.md)

### ip netns (Network Namespaces)

- Manage network namespaces: create, delete, execute commands inside them

```bash
# List namespaces
ip netns list

# Create namespace
ip netns add myns

# Run command in namespace
ip netns exec myns ip addr show

# Delete namespace
ip netns del myns
```

Related notes: [007-Network-namespace](./007-Network-namespace.md)

---

# Troubleshooting Flow (Quick)

```text
Network not working after ip configuration?
  │
  ├─ IP assigned? ──── ip addr show <iface> ──── Missing? → ip addr add ...
  │
  ├─ Interface UP? ──── ip link show <iface> ──── DOWN? → ip link set <iface> up
  │
  ├─ Route exists? ──── ip route show ──── No default? → ip route add default via ...
  │
  ├─ ARP resolving? ──── ip neigh show ──── FAILED? → check L2 connectivity / ip neigh flush all
  │
  └─ Settings lost after reboot? ──── ip changes are runtime-only → use netplan/NetworkManager/ifupdown
```

# Quick Facts (Revision)

- `ip` is part of iproute2; it replaces ifconfig, route, and arp
- `ip addr` = L3 addresses; `ip link` = L2 interface state; `ip route` = routing table
- `ip -4 addr show` filters to IPv4 only; `ip -6` for IPv6
- All `ip` changes are ephemeral -- lost on reboot unless persisted by a network manager
- `ip addr show` scope values: `global` (routable), `link` (local subnet), `host` (loopback)
- `ip route add default via <gw>` sets the default gateway
- `ip neigh` shows ARP cache; useful for diagnosing L2 issues
- Shorthand: `ip a` = `ip addr show`, `ip r` = `ip route show`
