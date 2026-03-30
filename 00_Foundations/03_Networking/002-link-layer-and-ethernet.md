# Link Layer and Ethernet

- The link layer (Layer 2) delivers frames between devices on the same local network segment.
- Ethernet is the dominant link-layer technology; it uses MAC addresses to identify devices and frames to carry data.
- ARP maps IP addresses to MAC addresses so devices on the same network can communicate.

# Architecture

```text
Ethernet Frame:
+----------+----------+----------+-----------+-----------+-----+
| Preamble | Dest MAC | Src MAC  | EtherType | Payload   | FCS |
| 8 bytes  | 6 bytes  | 6 bytes  | 2 bytes   | 46-1500 B | 4 B |
+----------+----------+----------+-----------+-----------+-----+
                                      |
                                      v
                              0x0800 = IPv4
                              0x0806 = ARP
                              0x86DD = IPv6
                              0x8100 = VLAN-tagged

Layer 2 Delivery:
  Host A (192.168.1.10)                          Host B (192.168.1.20)
  MAC: AA:BB:CC:11:22:33                         MAC: DD:EE:FF:44:55:66
       |                                              |
       +---------- Switch (MAC address table) --------+
       Switch learns: port 1 = AA:BB:CC:11:22:33
                      port 3 = DD:EE:FF:44:55:66
```

# Mental Model

```text
How does Host A send a packet to Host B on the same LAN?

1. Host A knows destination IP (192.168.1.20) but not the MAC address
      |
      v
2. Host A checks ARP cache -- is 192.168.1.20 already known?
      |
      +-- yes --> use cached MAC, skip to step 5
      |
      v
3. Host A broadcasts ARP Request (who has 192.168.1.20?)
   - Src MAC: AA:BB:CC:11:22:33   Dst MAC: FF:FF:FF:FF:FF:FF
   - Every device on the LAN receives this frame
      |
      v
4. Host B recognizes its IP, sends ARP Reply (unicast)
   - Src MAC: DD:EE:FF:44:55:66   Dst: AA:BB:CC:11:22:33
   - Host A caches this mapping
      |
      v
5. Host A builds Ethernet frame with Host B's MAC and sends the IP packet
```

```bash
# view ARP cache (IP-to-MAC mappings)
ip neigh show
# or legacy command
arp -a
```

# Core Building Blocks

### Ethernet and MAC Addresses

- MAC (Media Access Control) address: 48-bit hardware address, written as `AA:BB:CC:DD:EE:FF`.
- First 3 bytes = OUI (Organizationally Unique Identifier) — identifies the manufacturer.
- MAC addresses are burned into the NIC but can be overridden in software.
- Switches maintain a MAC address table: they learn which MAC is on which port by reading source MACs of incoming frames.
- Switches forward frames only to the correct port (unicast) or all ports (broadcast/unknown destination).

```bash
# show MAC address of your interfaces
ip link show
# example output: link/ether AA:BB:CC:11:22:33
```

Related notes: [001-network-models](./001-network-models.md)

### ARP (Address Resolution Protocol)

- ARP resolves IPv4 addresses to MAC addresses on the local network.
- ARP Request: broadcast — "Who has 192.168.1.20? Tell 192.168.1.10"
- ARP Reply: unicast — "192.168.1.20 is at DD:EE:FF:44:55:66"
- ARP cache stores recent mappings to avoid repeated broadcasts. Entries expire (typically 30-300 seconds).
- Gratuitous ARP: a host announces its own IP-to-MAC mapping (used after IP change or for failover).
- ARP spoofing: attacker sends fake ARP replies to redirect traffic — mitigated by static ARP entries or dynamic ARP inspection on switches.
- IPv6 does not use ARP; it uses NDP (Neighbor Discovery Protocol) with ICMPv6 instead.

```bash
# view ARP cache
ip neigh show

# add a static ARP entry (prevents spoofing for critical hosts)
ip neigh add 192.168.1.1 lladdr AA:BB:CC:11:22:33 dev eth0
```

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### VLANs (802.1Q)

- VLAN (Virtual LAN) logically segments one physical switch into multiple isolated broadcast domains.
- Without VLANs: all ports on a switch share one broadcast domain — every broadcast reaches every device.
- With VLANs: traffic in VLAN 10 cannot reach VLAN 20 without a router (Layer 3).
- VLAN tagging (802.1Q): inserts a 4-byte tag into the Ethernet frame with a VLAN ID (1-4094).
- **Access port**: connects to end devices, belongs to one VLAN (untagged).
- **Trunk port**: carries traffic for multiple VLANs between switches (tagged).
- Common use cases: separate departments, guest networks, management networks, IoT devices.

```text
Switch with VLANs:
  Port 1 (VLAN 10) ─── Office PC
  Port 2 (VLAN 10) ─── Office PC
  Port 3 (VLAN 20) ─── Server
  Port 4 (VLAN 20) ─── Server
  Port 24 (Trunk)  ─── To another switch (carries VLAN 10 + 20)
```

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### MTU and Fragmentation

- MTU (Maximum Transmission Unit): the largest frame payload a link can carry. Default for Ethernet: 1500 bytes.
- If a packet exceeds the MTU, it must be fragmented (split into smaller packets) or dropped.
- Path MTU Discovery (PMTUD): sender discovers the smallest MTU along the entire path by sending packets with the "Don't Fragment" (DF) flag set. If a router can't forward it, it sends back an ICMP "Fragmentation Needed" message.
- Jumbo frames: MTU up to 9000 bytes — used in data centers for better throughput. All devices on the path must support it.
- MTU mismatch causes "black holes": packets silently disappear when ICMP is blocked and PMTUD fails.

```bash
# check interface MTU
ip link show eth0 | grep mtu

# test path MTU to a destination
ping -M do -s 1472 192.168.1.1
# 1472 + 8 (ICMP header) + 20 (IP header) = 1500 (standard Ethernet MTU)
# if it fails, lower the size until it works
```

Related notes: [005-transport-layer](./005-transport-layer.md)

### Switch vs Hub vs Bridge

| Device  | Layer | Intelligence | Sends frames to |
|---------|-------|-------------|-----------------|
| Hub     | L1    | None        | All ports (broadcast) |
| Bridge  | L2    | Learns MACs | Correct port only |
| Switch  | L2    | Learns MACs | Correct port only (multi-port bridge) |

- Hub: obsolete — repeats every frame to every port, causing collisions.
- Bridge: connects two network segments, learns MACs, forwards selectively. Mostly replaced by switches.
- Switch: multi-port bridge — the standard device for LANs. Forwards frames based on MAC address table.

Related notes: [001-network-models](./001-network-models.md)
