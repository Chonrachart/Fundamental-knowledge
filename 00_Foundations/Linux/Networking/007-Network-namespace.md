# Network Namespaces

- A network namespace provides an isolated network stack: interfaces, routing tables, firewall rules.
- Multiple namespaces can run on one host; each has its own view of the network.
- Used by containers (Docker, Podman, LXC), VPNs, and complex network setups.

---

# What is a Network Namespace

- Each namespace has:
  - Its own network interfaces (can have different interfaces than the host)
  - Its own routing table
  - Its own firewall rules (iptables/nftables)
  - Its own `/proc/net`, socket tables
- Processes in a namespace see only that namespace's network state.

# Creating and Using Namespaces

```bash
# Create namespace
ip netns add red
ip netns add blue

# List namespaces
ip netns list

# Run command inside namespace
ip netns exec red ip addr show
ip netns exec red ping 8.8.8.8

# Delete namespace (must have no processes)
ip netns del red
```

# Connecting Namespaces: veth Pairs

- veth pairs connect two namespaces (or namespace to host).
- Traffic sent on one end appears on the other.

```bash
# Create veth pair
ip link add veth-red type veth peer name veth-blue

# Move veth-blue into namespace blue
ip link set veth-blue netns blue

# Assign IPs and bring up
ip addr add 10.0.0.1/24 dev veth-red
ip link set veth-red up

ip netns exec blue ip addr add 10.0.0.2/24 dev veth-blue
ip netns exec blue ip link set veth-blue up

# Test connectivity
ip netns exec blue ping 10.0.0.1
```

# Connecting to External Network (Bridge)

- To reach the internet, connect namespace to a bridge that has the host's physical interface.
- Or use NAT: namespace uses host as gateway; host does SNAT for outbound traffic.

```bash
# Create bridge on host
ip link add name br0 type bridge
ip link set br0 up
ip link set eth0 master br0

# Connect namespace to bridge via veth
ip link add veth-red type veth peer name veth-red-br
ip link set veth-red-br master br0
ip link set veth-red netns red
# Assign IP in namespace, set default route via bridge IP
```

# How Containers Use Namespaces

- Docker/Podman create a network namespace per container.
- veth connects container to `docker0` or custom bridge.
- Host does NAT so container can reach internet.

```
Container (namespace)  ←→  veth  ←→  docker0 (bridge)  ←→  eth0  ←→  Internet
```

# Inspecting Namespaces

```bash
# Which namespace is a process in?
ls -l /proc/<pid>/ns/net

# Enter namespace of running process (nsenter)
nsenter -t <pid> -n ip addr show
```