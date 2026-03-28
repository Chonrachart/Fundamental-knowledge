# Network Namespaces

### Overview
- **Why it exists** — Linux needs a way to give each pod complete network isolation without separate VMs; network namespaces provide that by letting each pod own its own IP, routing table, and interfaces.
- **What it is** — A Linux kernel primitive that creates a fully isolated network stack. Each pod gets one network namespace at creation time; processes inside see only the interfaces and routes in that namespace.
- **One-liner** — A network namespace is the kernel feature that makes every pod look like a separate machine on the network.

### Architecture (ASCII)

```text
Node (root netns)
┌──────────────────────────────────────────────────────┐
│                                                      │
│  bridge: cbr0 / cni0 (10.244.0.1)                   │
│      │              │              │                  │
│   veth0a         veth1a         veth2a               │
│      │              │              │                  │
│ ─────┼──────────────┼──────────────┼──── (veth pairs)│
│      │              │              │                  │
│   veth0b         veth1b         veth2b               │
│  ┌───┴───┐      ┌───┴───┐      ┌───┴───┐            │
│  │ Pod A │      │ Pod B │      │ Pod C │            │
│  │netns  │      │netns  │      │netns  │            │
│  │eth0   │      │eth0   │      │eth0   │            │
│  │10.x.1 │      │10.x.2 │      │10.x.3 │            │
│  └───────┘      └───────┘      └───────┘            │
└──────────────────────────────────────────────────────┘
```

Each pod's `eth0` is one end of a **veth pair**; the other end lives in the root namespace and plugs into the bridge. The bridge routes between pods on the same node; the CNI handles cross-node routing.

### Mental Model

Pods are like separate machines on the same LAN. Each has:
- Its own IP address (assigned by CNI from the pod CIDR)
- Its own routing table and ARP cache
- Its own `lo` loopback and `eth0` interface

They can reach each other directly by IP — no NAT needed — because the veth pair + bridge setup acts like a virtual Ethernet switch inside the node. Cross-node traffic is handled by the CNI plugin (BGP, VXLAN, etc.).

Think of it as: the node is a physical switch rack, each pod is a server plugged into it, and the veth pairs are the patch cables.

### Core Building Blocks

### Network Namespace
- **Why it exists** — Prevents pods from seeing or interfering with each other's network state.
- **What it is** — A kernel object containing its own set of network interfaces, IP addresses, routing tables, iptables rules, and sockets. Processes inside a namespace can only see resources in that namespace.
- **One-liner** — The kernel fence that gives each pod its own private network stack.

```bash
# List all network namespaces on a node (run on the node itself)
ip netns list

# Inspect interfaces inside a specific namespace
ip netns exec <ns-name> ip addr

# Show routes inside a namespace
ip netns exec <ns-name> ip route

# Example: namespaces are usually named by the pause container ID
# On a kubeadm node they appear as: cni-<uuid>
```

### veth Pair
- **Why it exists** — A namespace is isolated; you need a virtual "cable" to connect it to the outside.
- **What it is** — A pair of virtual Ethernet interfaces linked at the kernel level. Traffic in one end comes out the other, crossing the namespace boundary.
- **One-liner** — Virtual patch cable connecting a pod's netns to the node's bridge.

```bash
# On the node, see all veth interfaces
ip link show type veth

# Each veth has a peer index; use ethtool to find the pair
ethtool -S veth123  # shows peer_ifindex
```

### Bridge (cni0 / cbr0)
- **Why it exists** — Provides a single Layer-2 switch inside the node that all veth ends connect to, enabling pod-to-pod traffic on the same node without leaving the kernel.
- **What it is** — A software bridge interface. Every veth end from every pod on the node is enslaved to it. The bridge has the node-side pod-CIDR gateway IP.
- **One-liner** — The virtual switch inside the node that connects all pods.

```bash
# Show bridge and its attached interfaces
bridge link show

# Show bridge IP (gateway for pods on this node)
ip addr show cni0
```

### Pause Container
- **Why it exists** — All containers in a pod must share one network namespace; the pause container holds the namespace alive for the lifetime of the pod even if app containers restart.
- **What it is** — A minimal container (does nothing but sleep) whose sole job is owning the pod's network namespace. All other containers in the pod join it via `--network=container:<pause-id>`.
- **One-liner** — The namespace anchor that keeps the pod's network alive between container restarts.

```bash
# See pause containers on a node
crictl ps | grep pause

# Inspect a pod's network namespace path
crictl inspect <pause-container-id> | grep netns
```

### Troubleshooting

### Pod has no IP / networking not working
1. Check CNI plugin is running: `kubectl get pods -n kube-system` — look for calico/flannel/cilium pods.
2. Check CNI config: `ls /etc/cni/net.d/` on the node.
3. Check kubelet logs for CNI errors: `journalctl -u kubelet | grep -i cni`.

### Pod can't reach another pod on the same node
1. Check veth pair is up: `ip link show type veth` on the node — look for `state DOWN`.
2. Check bridge forwarding: `bridge fwd show`.
3. Check pod's default route: `kubectl exec <pod> -- ip route`.

### Pod can't reach pods on other nodes
1. This is a CNI routing issue — check CNI plugin logs.
2. Check node-to-node routes: `ip route show` on each node.
3. For VXLAN-based CNIs, check VXLAN interface is up: `ip link show vxlan`.
