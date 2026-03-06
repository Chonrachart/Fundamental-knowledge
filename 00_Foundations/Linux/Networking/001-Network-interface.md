physical vs virtual interfaces
lo
eth0
bridge
veth
NIC / virtual interface

---

# Physical vs Virtual Interfaces

- **Physical interface**: tied to hardware (NIC); e.g. `eth0`, `enp0s3`, `wlan0`.
- **Virtual interface**: software-only; no physical device; e.g. `lo`, `docker0`, `veth` pairs.

| Type     | Example   | Purpose                          |
| :------- | :-------- | :------------------------------- |
| Physical | eth0      | Real NIC                         |
| Virtual  | lo        | Loopback                         |
| Virtual  | bridge    | Connect multiple interfaces      |
| Virtual  | veth      | Connect namespaces/containers    |

# lo (Loopback)

- Loopback interface; always present.
- Address: `127.0.0.1` (IPv4), `::1` (IPv6).
- Traffic never leaves the host; used for local services and testing.
- Example: `curl http://127.0.0.1` talks to a local server.

```bash
ip addr show lo
# or
ifconfig lo
```

# eth0 / Physical NIC

- `eth0`, `enp0s3`, `ens33`, etc. are typical names for Ethernet interfaces.
- Naming: `en` = Ethernet, `p0s3` = PCI bus/slot; `wlan0` = wireless.
- Each has MAC address, can have one or more IP addresses.

```bash
ip link show
ip addr show eth0
```

# Bridge

- A bridge connects multiple interfaces (physical or virtual) into one Layer 2 segment.
- Acts like a virtual switch; forwards frames between ports.
- Common use: VMs, containers sharing a network (e.g. `docker0`, `br0`).

```
eth0 ──┐
       ├── bridge (br0) ── Layer 2 segment
veth1 ─┘
```

```bash
ip link add name br0 type bridge
ip link set eth0 master br0
ip link set br0 up
```

# veth (Virtual Ethernet Pair)

- veth is a pair of virtual interfaces; traffic sent on one appears on the other.
- Used to connect network namespaces (e.g. container to host or bridge).

```
Namespace A          Namespace B
   vethA ←──────────→ vethB
```

```bash
ip link add veth0 type veth peer name veth1
ip link set veth1 netns <namespace>
```

# NIC / Virtual Interface Summary

| Interface | Type    | Typical use                    |
| :-------- | :------ | :----------------------------- |
| eth0      | Physical| Main network                   |
| lo        | Virtual | Loopback                       |
| bridge    | Virtual | Connect multiple interfaces    |
| veth      | Virtual | Connect namespaces/containers  |
| docker0   | Bridge  | Docker default network         |