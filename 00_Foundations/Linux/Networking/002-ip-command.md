configuration tool

---

# ip Command Overview

- `ip` is the modern tool for configuring Linux networking (replaces `ifconfig`, `route`, `arp`).
- Part of `iproute2` package.
- Subcommands: `ip addr`, `ip link`, `ip route`, `ip neigh`, `ip netns`, etc.

# ip addr (Address Management)

- View and configure IP addresses on interfaces.

```bash
# Show all addresses
ip addr show
ip a

# Add IP to interface
ip addr add 192.168.1.10/24 dev eth0

# Remove IP
ip addr del 192.168.1.10/24 dev eth0

# Show only IPv4
ip -4 addr show
```

### Key Output Fields

- `inet` — IPv4 address with CIDR
- `inet6` — IPv6 address
- `scope` — global, link, host
- `state` — UP, DOWN

# ip link (Interface Management)

- Manage network interfaces (bring up/down, set MTU, etc.).

```bash
# List interfaces
ip link show

# Bring interface up/down
ip link set eth0 up
ip link set eth0 down

# Set MTU
ip link set eth0 mtu 1500

# Rename interface (when down)
ip link set eth0 name eth1
```

# ip route (Routing Table)

- View and modify routing table.

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

### Routing Table Fields

- `default` or `0.0.0.0/0` — default gateway
- `via` — next hop IP
- `dev` — output interface

# ip neigh (ARP / Neighbor Table)

- View and manage ARP/neighbor cache (IP → MAC mapping).

```bash
# Show neighbor table
ip neigh show

# Flush ARP cache
ip neigh flush all
```

# ip netns (Network Namespaces)

- Manage network namespaces.

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

# Common Workflow Example

```bash
# Configure static IP
ip addr add 192.168.1.100/24 dev eth0
ip link set eth0 up
ip route add default via 192.168.1.1
```