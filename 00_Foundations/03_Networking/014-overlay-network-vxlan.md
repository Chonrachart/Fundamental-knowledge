# Overlay Networks and VXLAN

- An overlay network creates a virtual Layer 2 network on top of an existing Layer 3 (IP-routed) infrastructure, making remote hosts appear to share the same LAN segment.
- Overlay networks exist to extend L2 broadcast domains across L3 boundaries without requiring changes to the physical underlay topology.
- VXLAN (Virtual eXtensible LAN) is the dominant overlay standard, defined in RFC 7348, using UDP encapsulation to tunnel Ethernet frames across routed IP networks.

# Architecture

```text
VXLAN Encapsulation (50 bytes overhead):
+----------------+----------------+--------------+----------------+-------------------+
| Outer Ethernet | Outer IP       | Outer UDP    | VXLAN Header   | Original L2 Frame |
| 14 bytes       | 20 bytes       | 8 bytes      | 8 bytes        | (inner payload)   |
+----------------+----------------+--------------+----------------+-------------------+
| Dst/Src MAC of | Src: local     | Src: ephemeral|  Flags         | Original Ethernet |
| underlay next  | VTEP IP        | Dst: 4789    |  VNI (24-bit)  | frame as sent by  |
| hop routers    | Dst: remote    |              |  Reserved      | the VM/host       |
|                | VTEP IP        |              |                |                   |
+----------------+----------------+--------------+----------------+-------------------+

Two VTEPs connected across an IP underlay:

  Host A                                                          Host B
  10.0.100.10                                                     10.0.200.20
     |                                                               |
+---------+                                                     +---------+
| VTEP 1  |  Underlay IP: 192.168.1.1                          | VTEP 2  |  Underlay IP: 192.168.2.1
+---------+                                                     +---------+
     |                                                               |
     +------- IP Routed Underlay Network (L3 fabric) ---------------+
              192.168.0.0/16 — standard IP routing
              (spine-leaf, routed core, etc.)

  VTEP 1 encapsulates Host A's frames in UDP/IP destined for VTEP 2.
  VTEP 2 decapsulates and delivers the original frame to Host B.
  Both hosts believe they are on the same L2 segment (VNI 5001).
```

# Mental Model

```text
Step-by-step packet flow — Host A sends a frame to Host B:

1. Host A sends an Ethernet frame (dst MAC = Host B's MAC)
      |
      v
2. Local VTEP 1 intercepts the frame
   - Looks up destination MAC in its MAC-to-VTEP mapping table
   - Finds: Host B's MAC --> VTEP 2 (192.168.2.1)
      |
      v
3. VTEP 1 encapsulates the original frame:
   - Prepends 8-byte VXLAN header (VNI = 5001)
   - Wraps in UDP (dst port 4789)
   - Wraps in outer IP (src: 192.168.1.1, dst: 192.168.2.1)
   - Adds outer Ethernet header for next-hop router
      |
      v
4. Outer IP packet routes across the underlay
   - Standard L3 routing — underlay routers see only the outer IP header
   - No awareness of the inner frame or overlay
      |
      v
5. VTEP 2 receives the UDP packet on port 4789
   - Identifies it as VXLAN by the port and header flags
   - Reads VNI (5001) to determine the correct virtual segment
      |
      v
6. VTEP 2 strips outer Ethernet + IP + UDP + VXLAN headers
   - Recovers the original L2 frame exactly as Host A sent it
      |
      v
7. VTEP 2 delivers the original frame to Host B
   - Host B sees a normal Ethernet frame — no knowledge of encapsulation
```

# Core Building Blocks

### Why Overlay Networks

- VLANs use a 12-bit VLAN ID, limiting segments to 4096 max — far too few for multi-tenant datacenters with thousands of tenants.
- Modern datacenters need isolated L2 domains for each tenant, application tier, or workload group across racks, rows, and even buildings.
- Overlay networks extend L2 domains across L3 routed boundaries — hosts in different subnets and physical locations can share the same virtual LAN.
- Logical topology is decoupled from physical topology: you can move, add, or remove workloads without recabling or reconfiguring the physical network.
- The underlay can be optimized purely for IP routing (ECMP, spine-leaf), while overlays handle multi-tenancy and segmentation.

Related notes: [002-link-layer-and-ethernet](./002-link-layer-and-ethernet.md), [003-addressing-and-routing](./003-addressing-and-routing.md)

### VXLAN Fundamentals

- VXLAN = Virtual eXtensible LAN, defined in RFC 7348 (2014).
- Uses a 24-bit VNI (VXLAN Network Identifier), supporting ~16 million isolated segments (vs. 4096 for VLANs).
- Encapsulates full Ethernet frames inside UDP packets with destination port 4789 (IANA-assigned).
- Encapsulation overhead is 50 bytes total:
  - 14 bytes — outer Ethernet header
  - 20 bytes — outer IP header
  - 8 bytes — outer UDP header
  - 8 bytes — VXLAN header (flags + VNI + reserved)
- This overhead means the effective MTU for inner traffic is reduced (e.g., 1500 - 50 = 1450 for standard underlay MTU).
- VXLAN is stateless — no connection setup between VTEPs, just encapsulate and send.

Related notes: [002-link-layer-and-ethernet](./002-link-layer-and-ethernet.md)

### VTEP (VXLAN Tunnel Endpoint)

- The VTEP is where encapsulation (ingress) and decapsulation (egress) happen — the boundary between overlay and underlay.
- Can be implemented in hardware (Top-of-Rack switches like Cisco Nexus, Arista) or software (Linux kernel, Open vSwitch).
- Each VTEP is identified by its IP address on the underlay network — this is the outer source/destination IP in encapsulated packets.
- VTEPs maintain a MAC-to-VTEP mapping table: "destination MAC X is reachable via VTEP at IP Y."
- MAC learning can be:
  - Data-plane learning — flood-and-learn, similar to traditional switches (uses multicast groups for BUM traffic).
  - Control-plane learning — a controller (e.g., EVPN with BGP) distributes MAC-to-VTEP mappings, avoiding floods.
- BUM traffic (Broadcast, Unknown unicast, Multicast) is typically handled via multicast groups on the underlay or ingress replication (head-end replication) to all VTEPs in the VNI.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### Underlay vs Overlay

- **Underlay** — the physical or routed IP network that carries encapsulated overlay traffic.
  - Typically a spine-leaf or routed L3 fabric.
  - Only needs IP reachability between VTEPs — no VLAN trunking or L2 stretching required.
  - Can use ECMP, OSPF, BGP, or any standard routing protocol.
  - Must support the encapsulated packet size (MTU considerations).
- **Overlay** — the virtual L2 network created on top of the underlay.
  - Provides isolated broadcast domains identified by VNI.
  - Hosts on the overlay communicate as if on the same LAN, unaware of the underlay.
  - Multiple overlays (different VNIs) can coexist on the same underlay without interference.
- Key separation: underlay engineers focus on IP routing and physical links; overlay engineers focus on tenant segmentation and virtual networking.

### VXLAN on Linux

- The Linux kernel has native VXLAN support (since kernel 3.7).
- Create a VXLAN interface (unicast mode — point-to-point):

```bash
# create VXLAN interface with VNI 100, remote VTEP at 192.168.2.1
ip link add vxlan0 type vxlan id 100 remote 192.168.2.1 dstport 4789 dev eth0

# bring the interface up
ip link set vxlan0 up

# assign an IP on the overlay network
ip addr add 10.0.100.1/24 dev vxlan0
```

- Create a VXLAN interface (multicast mode — multi-VTEP):

```bash
# use multicast group 239.1.1.1 for BUM traffic
ip link add vxlan0 type vxlan id 100 group 239.1.1.1 dstport 4789 dev eth0
```

- Inspect VXLAN interfaces:

```bash
# show VXLAN interface details (VNI, remote, port, etc.)
ip -d link show type vxlan

# show FDB (forwarding database) entries — MAC-to-VTEP mappings
bridge fdb show dev vxlan0
```

- FDB entries can be manually added for static MAC-to-VTEP mappings:

```bash
# tell this VTEP that MAC aa:bb:cc:dd:ee:ff is reachable via VTEP 192.168.2.1
bridge fdb add aa:bb:cc:dd:ee:ff dev vxlan0 dst 192.168.2.1
```

Related notes: [002-link-layer-and-ethernet](./002-link-layer-and-ethernet.md)

### Other Overlay Technologies

- **GRE (Generic Routing Encapsulation)**
  - Simple point-to-point tunneling protocol, encapsulates various L3 protocols inside IP.
  - No built-in multi-tenancy (no segment ID like VNI) — one tunnel per pair of endpoints per use case.
  - Lower overhead than VXLAN (4-byte GRE header) but lacks scalability for datacenter multi-tenancy.

- **Geneve (Generic Network Virtualization Encapsulation)**
  - Designed as the successor to VXLAN, defined in RFC 8926.
  - Uses flexible TLV (Type-Length-Value) option headers — extensible without protocol changes.
  - Same UDP encapsulation model (port 6081) but with variable-length metadata support.
  - Increasingly adopted by modern SDN platforms (e.g., OVN, AWS).

- **IPsec Tunnels**
  - Encrypted overlay tunnels providing confidentiality, integrity, and authentication.
  - Higher CPU overhead due to encryption/decryption — not ideal for high-throughput datacenter east-west traffic.
  - Commonly used for site-to-site VPN across untrusted networks rather than datacenter overlays.

- **NVGRE (Network Virtualization using GRE)**
  - Microsoft's alternative to VXLAN, uses GRE with a 24-bit Tenant Network Identifier (TNI).
  - Less widely adopted than VXLAN — limited vendor support outside Hyper-V environments.
  - Uses GRE header instead of UDP, which makes ECMP load balancing harder (no UDP source port for entropy).

Related notes: [011-vpn-technologies](./011-vpn-technologies.md)
