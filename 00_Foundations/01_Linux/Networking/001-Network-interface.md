# Network Interfaces

- A network interface is the access point between the kernel network stack and the physical or virtual network
- Physical interfaces map to hardware NICs; virtual interfaces are software-only constructs created by the kernel
- Every interface has a name, state (UP/DOWN), and can carry one or more IP addresses

# Architecture

```text
┌───────────────────────────────────────────────────────────┐
│                    Kernel Network Stack                    │
├──────────┬──────────┬──────────┬──────────┬───────────────┤
│   lo     │  eth0    │  br0     │  veth0   │  docker0      │
│ loopback │ physical │  bridge  │  veth    │  bridge       │
│ 127.0.0.1│ NIC/MAC  │ (switch) │  (pair)  │  (container)  │
└──────────┴────┬─────┴────┬─────┴────┬─────┴───────────────┘
                │          │          │
           Hardware    Connects    Connects
             NIC      multiple    namespaces
                      interfaces
```

# Mental Model

```text
How a bridge connects namespaces via veth pairs:

  Host namespace               Container namespace
  ┌──────────────┐             ┌──────────────┐
  │              │             │              │
  │  br0 (bridge)│             │  eth0        │
  │    │         │             │  (= veth1)   │
  │  veth0 ─────────────────────── veth1      │
  │              │             │              │
  └──────────────┘             └──────────────┘

  1. veth pair created: veth0 + veth1
  2. veth1 moved into container namespace
  3. veth0 attached to bridge br0
  4. Bridge forwards L2 frames between all attached ports
```

Example: create a bridge and connect a veth pair

```bash
# Create bridge
ip link add name br0 type bridge
ip link set br0 up

# Create veth pair
ip link add veth0 type veth peer name veth1

# Attach veth0 to bridge
ip link set veth0 master br0
ip link set veth0 up

# Move veth1 into a namespace
ip netns add container1
ip link set veth1 netns container1
ip netns exec container1 ip addr add 10.0.0.2/24 dev veth1
ip netns exec container1 ip link set veth1 up
```

# Core Building Blocks

### lo (Loopback)

- Always present on every Linux system
- Address: `127.0.0.1` (IPv4), `::1` (IPv6)
- Traffic never leaves the host; used for local services and testing
- Example: `curl http://127.0.0.1` talks to a local server
- Loopback (`lo`) is always present, address 127.0.0.1, traffic stays local

```bash
ip addr show lo
```

Related notes: [002-ip-command](./002-ip-command.md)

### eth0 / Physical NIC

- Tied to hardware; name depends on system naming scheme
- Naming conventions: `en` = Ethernet, `p0s3` = PCI bus/slot; `wlan0` = wireless
- Common names: `eth0`, `enp0s3`, `ens33`, `eno1`
- Each has a MAC address and can hold one or more IP addresses
- Physical interfaces map to hardware NICs; virtual ones are kernel constructs
- Interface naming: `en` = Ethernet, `wl` = wireless; suffix indicates bus/slot
- An interface must be UP and have an IP address to pass traffic
- Use `ip link` for L2 management, `ip addr` for L3 management

| Interface | Type     | Typical Use                   |
| :-------- | :------- | :---------------------------- |
| eth0      | Physical | Main network                  |
| lo        | Virtual  | Loopback                      |
| bridge    | Virtual  | Connect multiple interfaces   |
| veth      | Virtual  | Connect namespaces/containers |
| docker0   | Bridge   | Docker default network        |

```bash
ip link show
ip addr show eth0
```

Related notes: [002-ip-command](./002-ip-command.md)

### Bridge

- Connects multiple interfaces (physical or virtual) into one Layer 2 segment
- Acts like a virtual switch; forwards frames between attached ports
- Common use: VMs, containers sharing a network (e.g. `docker0`, `br0`)
- A bridge is a virtual Layer 2 switch connecting multiple interfaces
- `docker0` is a bridge created by Docker for container networking

```text
eth0 ──┐
       ├── bridge (br0) ── Layer 2 segment
veth1 ─┘
```

```bash
ip link add name br0 type bridge
ip link set eth0 master br0
ip link set br0 up
```

Related notes: [007-Network-namespace](./007-Network-namespace.md)

### veth (Virtual Ethernet Pair)
Related notes: [007-Network-namespace](./007-Network-namespace.md), [002-ip-command](./002-ip-command.md)
- A pair of virtual interfaces; traffic sent on one appears on the other
- Used to connect network namespaces (container to host, or container to bridge)
- Always created in pairs
- veth pairs are always created together; traffic in one end exits the other

---

# Practical Command Set (Core)

```bash
# List all interfaces with state
ip link show

# Show all addresses
ip addr show

# Bring interface up / down
ip link set eth0 up
ip link set eth0 down

# Create bridge
ip link add name br0 type bridge

# Create veth pair
ip link add veth0 type veth peer name veth1

# Attach interface to bridge
ip link set veth0 master br0
```

Use `ip link` for interface state, `ip addr` for addresses.


# Troubleshooting Guide

```text
Interface not working?
  │
  ├─ Exists? ──── ip link show ──── Missing? → check driver/hardware
  │
  ├─ State UP? ──── ip link show <iface> ──── DOWN? → ip link set <iface> up
  │
  ├─ IP assigned? ──── ip addr show <iface> ──── No IP? → ip addr add ... dev <iface>
  │
  ├─ Bridge member? ──── bridge link show ──── Wrong master? → ip link set <iface> master <bridge>
  │
  └─ veth peer reachable? ──── ip link show ──── Peer in wrong namespace? → check ip netns
```
