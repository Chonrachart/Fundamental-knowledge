# Network Namespaces

- A network namespace provides a fully isolated network stack: interfaces, routing tables, firewall rules, and sockets
- Each namespace has its own view of the network; processes inside see only that namespace's state
- Used by containers (Docker, Podman, LXC), VPNs, and complex multi-tenant network setups

# Architecture

```text
  Host
  +-------------------------------------------------------+
  |  Default namespace                                     |
  |  +----------+  +----------+  +---------+              |
  |  | eth0     |  | br0      |  | lo      |              |
  |  +----+-----+  +----+-----+  +---------+              |
  |       |             |                                  |
  |       |        +----+----+                             |
  |       |        |         |                             |
  |    +--+---+ +--+---+  +-+----+                         |
  |    |veth-a| |veth-b|  |veth-c|   (host ends)           |
  +----+--+---+-+--+---+--+--+---+-------------------------+
          |        |          |
          |        |          |        (moved into namespaces)
     +----+---+ +--+---+ +---+----+
     | ns-red | |ns-blue| |ns-green|
     | veth-a | |veth-b | |veth-c  |
     | 10.0.. | |10.0.. | |10.0..  |
     +--------+ +-------+ +--------+
       Each namespace has own:
       - interfaces, routing, iptables, /proc/net, sockets
```

# Mental Model

```text
1. Create namespace            -->  ip netns add red
2. Create veth pair            -->  ip link add veth-red type veth peer name veth-red-br
3. Move one end into namespace -->  ip link set veth-red netns red
4. Assign IPs                  -->  ip netns exec red ip addr add 10.0.0.2/24 dev veth-red
5. Bring interfaces up         -->  ip netns exec red ip link set veth-red up
6. Connect host end to bridge  -->  ip link set veth-red-br master br0
7. Test connectivity           -->  ip netns exec red ping 10.0.0.1
```

```bash
# Concrete example: connect two namespaces directly via veth pair
ip netns add red
ip netns add blue

ip link add veth-red type veth peer name veth-blue
ip link set veth-red netns red
ip link set veth-blue netns blue

ip netns exec red ip addr add 10.0.0.1/24 dev veth-red
ip netns exec red ip link set veth-red up
ip netns exec red ip link set lo up

ip netns exec blue ip addr add 10.0.0.2/24 dev veth-blue
ip netns exec blue ip link set veth-blue up
ip netns exec blue ip link set lo up

ip netns exec red ping 10.0.0.2
```

# Core Building Blocks

### What a Namespace Contains

- Each network namespace has its own isolated set of:
  - Network interfaces (including its own `lo`)
  - Routing table
  - Firewall rules (iptables/nftables)
  - `/proc/net` entries
  - Socket tables
- Processes in one namespace cannot see interfaces or sockets in another

Related notes: [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md), [003-Route-table](./003-Route-table.md)

### Creating and Managing Namespaces

```bash
# Create namespaces
ip netns add red
ip netns add blue

# List namespaces
ip netns list

# Run a command inside a namespace
ip netns exec red ip addr show
ip netns exec red ping 8.8.8.8

# Delete namespace (must have no running processes)
ip netns del red
```

Related notes: [002-ip-command](./002-ip-command.md)

### veth Pairs — Connecting Namespaces

- veth (virtual Ethernet) pairs act as a pipe: traffic in one end comes out the other
- One end stays in the host (or a bridge); the other is moved into the namespace

```bash
# Create veth pair
ip link add veth-red type veth peer name veth-blue

# Move one end into namespace
ip link set veth-blue netns blue

# Assign IPs and bring up
ip addr add 10.0.0.1/24 dev veth-red
ip link set veth-red up

ip netns exec blue ip addr add 10.0.0.2/24 dev veth-blue
ip netns exec blue ip link set veth-blue up

# Test
ip netns exec blue ping 10.0.0.1
```

Related notes: [001-Network-interface](./001-Network-interface.md)

### Connecting to External Network

- **Bridge method**: attach namespace veth to a bridge that includes the physical interface
- **NAT method**: namespace uses host as default gateway; host performs SNAT/MASQUERADE for outbound

```bash
# Bridge method
ip link add name br0 type bridge
ip link set br0 up
ip link set eth0 master br0

# Connect namespace to bridge via veth
ip link add veth-red type veth peer name veth-red-br
ip link set veth-red-br master br0
ip link set veth-red-br up
ip link set veth-red netns red

# Inside namespace: assign IP and set default route via bridge IP
ip netns exec red ip addr add 10.0.0.2/24 dev veth-red
ip netns exec red ip link set veth-red up
ip netns exec red ip route add default via 10.0.0.1
```

Related notes: [003-Route-table](./003-Route-table.md), [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md)

### How Containers Use Namespaces

- Docker/Podman create a network namespace per container
- A veth pair connects the container namespace to `docker0` (or custom bridge)
- The host performs NAT so containers can reach external networks

```text
Container (namespace)  <-->  veth  <-->  docker0 (bridge)  <-->  eth0  <-->  Internet
```

Related notes: [006-firewall-iptables-nftable](./006-firewall-iptables-nftable.md)

### Inspecting Namespaces

```bash
# Check which namespace a process belongs to
ls -l /proc/<pid>/ns/net

# Enter the namespace of a running process
nsenter -t <pid> -n ip addr show

# List all interfaces in a namespace
ip netns exec red ip link show
```

Related notes: [002-ip-command](./002-ip-command.md)

---

# Troubleshooting Flow (Quick)

```text
Cannot reach from namespace?
  |
  +-> Is the veth pair created and both ends up?
  |     ip link show / ip netns exec <ns> ip link show
  |
  +-> Are IPs assigned on both ends?
  |     ip netns exec <ns> ip addr show
  |
  +-> Is loopback up in the namespace?
  |     ip netns exec <ns> ip link set lo up
  |
  +-> Can you ping the peer IP?
  |     Yes --> routing or firewall issue beyond the pair
  |     No  --> veth config problem
  |
  +-> Is default route set in the namespace?
  |     ip netns exec <ns> ip route show
  |
  +-> Is NAT/MASQUERADE configured on the host?
  |     iptables -t nat -L -n -v
  |
  +-> Is ip_forward enabled?
        sysctl net.ipv4.ip_forward
```

# Quick Facts (Revision)

- `ip netns add <name>` creates a namespace; `ip netns exec <name> <cmd>` runs commands inside it
- Each namespace has its own interfaces, routes, firewall rules, and socket tables
- veth pairs are the standard way to connect namespaces -- traffic in one end exits the other
- To reach external networks, attach the veth host-end to a bridge or use NAT
- Docker creates one network namespace per container, connected via veth to `docker0` bridge
- `nsenter -t <pid> -n` enters the network namespace of a running process
- `/proc/<pid>/ns/net` identifies which namespace a process belongs to
- Deleting a namespace requires no processes running inside it
