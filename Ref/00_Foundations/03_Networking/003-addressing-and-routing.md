# Addressing and Routing

- IP addresses uniquely identify devices on a network; IPv4 uses 32 bits, IPv6 uses 128 bits.
- Subnets partition address space using CIDR notation; routing tables determine how packets are forwarded between networks.
- NAT translates between private and public IP addresses, allowing many devices to share a single public IP.

# Architecture

```text
       Private Network                              Internet
+----------------------------+                 +-----------------+
|                            |                 |                 |
|  Host A                    |                 |   Remote Server |
|  192.168.1.10/24           |                 |   93.184.216.34 |
|       |                    |                 |        ^        |
|       v                    |                 |        |        |
|  +----------+   +-------+ |   NAT (SNAT)    |        |        |
|  | Switch   |-->|Gateway|-------------------->  Internet       |
|  +----------+   |Router | |  203.0.113.1     |  routing        |
|       ^         |.1     | |                  |                 |
|       |         +-------+ |                  +-----------------+
|  Host B                   |
|  192.168.1.20/24          |
+----------------------------+

Gateway = default route for hosts on 192.168.1.0/24
NAT translates 192.168.1.x --> 203.0.113.1 (public IP)
```

# Mental Model

```text
Packet forwarding decision:

  Host sends packet to destination IP
      |
      v
  Is destination in the same subnet?
      |                    |
     yes                  no
      |                    |
      v                    v
  Send directly        Send to default gateway
  (ARP for MAC)        (gateway routes it further)
                           |
                           v
                       Router checks routing table
                           |
                           v
                       Forward to next hop or deliver
```

```bash
# check your IP, subnet, and default gateway
ip addr show eth0
ip route show
# output example:
#   default via 192.168.1.1 dev eth0
#   192.168.1.0/24 dev eth0 scope link
```

# Core Building Blocks

### IP (Internet Protocol)

- IP identifies devices on a network and enables routing between networks.
- IPv4: 32-bit address, written as 4 octets (e.g., `192.168.1.1`). Approximately 4.3 billion addresses.
- IPv6: 128-bit address, written in hexadecimal groups (e.g., `2001:db8::1`). Virtually unlimited address space.
- IP is connectionless and best-effort -- it does not guarantee delivery (that is TCP's job).
- Each packet is routed independently based on its destination IP.
- IPv4 = 32-bit (4 octets, ~4.3 billion addresses); IPv6 = 128-bit (8 hex groups, virtually unlimited).

Related notes: [001-network-models](./001-network-models.md), [005-transport-layer](./005-transport-layer.md)

### Subnets and CIDR Notation

- A subnet is a logical division of an IP network into smaller segments.
- Subnet mask (or CIDR prefix) defines which bits identify the network vs the host.
- CIDR notation examples:
  - `/24` = 24 network bits, 8 host bits = 256 addresses (e.g., `192.168.1.0/24` = 192.168.1.0-255)
  - `/16` = 16 network bits, 16 host bits = 65,536 addresses
  - `/32` = single host address
  - `/0` = all addresses (default route)
- Hosts in the same subnet communicate directly; hosts in different subnets need a router.
- CIDR `/24` = 256 addresses; `/16` = 65,536; `/32` = single host; `/0` = default route.
- Hosts in the same subnet communicate directly via ARP; different subnets need a router.

Related notes: [000-core](./000-core.md)

### Routing

- Routing is the process of finding a path to forward packets to the destination network.
- Routers maintain routing tables with entries: destination network, next hop, interface.
- Default route (`0.0.0.0/0`): used when no more specific route matches -- typically points to the internet gateway.
- Static routes are manually configured; dynamic routes are learned via protocols (OSPF, BGP, etc.).
- Routing table: destination + next hop + interface. Default route = `0.0.0.0/0`.

Related notes: [011-vpn-technologies](./011-vpn-technologies.md)

### Gateway

- The default gateway is the router that connects a local network to other networks (including the internet).
- When a host sends a packet to an IP outside its subnet, it forwards the packet to the gateway.
- The gateway then routes the packet toward the destination using its own routing table.
- Default gateway connects local subnet to the rest of the network.

Related notes: [001-network-models](./001-network-models.md)

### ICMP (Internet Control Message Protocol)

- ICMP works alongside IP for error reporting and network diagnostics.
- It does not carry application data like TCP or UDP — it signals problems and provides information.
- ICMP messages have a type and code that identify the specific message.

Common ICMP types:

| Type | Code | Name | Used by / Meaning |
|------|------|------|-------------------|
| 0 | 0 | Echo Reply | Response to ping |
| 3 | 0 | Destination Unreachable - Net | No route to network |
| 3 | 1 | Destination Unreachable - Host | Host is down or unreachable |
| 3 | 3 | Destination Unreachable - Port | No service listening on that port (UDP) |
| 3 | 4 | Fragmentation Needed | Packet too big, DF flag set (used by PMTUD) |
| 5 | 0 | Redirect | Router tells sender to use a better route |
| 8 | 0 | Echo Request | Sent by ping |
| 11 | 0 | Time Exceeded | TTL reached 0 — used by traceroute |

- `ping` sends Echo Request (type 8), expects Echo Reply (type 0).
- `traceroute` sends packets with incrementing TTL; each router that decrements TTL to 0 sends back Time Exceeded (type 11), revealing the path hop by hop.
- Blocking ICMP entirely breaks PMTUD and makes network debugging harder — allow at least type 3 and type 11.

```bash
# ping: sends ICMP Echo Request
ping -c 3 192.168.1.1

# traceroute: uses ICMP Time Exceeded to map the path
traceroute 8.8.8.8
```

Related notes: [000-core](./000-core.md), [002-link-layer-and-ethernet](./002-link-layer-and-ethernet.md)

### NAT (Network Address Translation)
```text
Outbound (SNAT):
  192.168.1.10:51514  -->  [Router/NAT]  -->  203.0.113.1:51514  -->  Internet

Inbound (DNAT):
  Internet  -->  203.0.113.1:443  -->  [Router/NAT]  -->  192.168.1.50:443
```

Related notes: [010-proxy-and-load-balancing](./010-proxy-and-load-balancing.md)
- NAT translates private IPs to a public IP (and back) at the network boundary.
- Allows many devices on a private network to share one public IP address.
- Types:
  - **SNAT** (Source NAT): outbound traffic; private source IP is replaced with public IP
  - **DNAT** (Destination NAT): inbound traffic; public IP:port is mapped to a private IP:port
- NAT maintains a translation table to map connections back to the correct internal host.
- SNAT = outbound (private to public); DNAT = inbound (public to private).
- NAT translation table maps internal connections to external addresses for return traffic.
