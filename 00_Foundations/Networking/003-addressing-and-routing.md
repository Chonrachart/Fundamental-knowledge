# IP (Internet Protocol)

- IP identifies devices on a network.
- IPv4: 32-bit address (e.g. `192.168.1.1`).
- IPv6: 128-bit address (e.g. `2001:db8::1`).
- IP is used for routing; packets are forwarded based on destination IP.

# Subnet

- A subnet is a logical division of an IP network.
- Subnet mask (or CIDR) defines which bits are network vs host.
- Example: `192.168.1.0/24` means 256 addresses (192.168.1.0–255).

### CIDR Notation

- `/24` = 24 bits for network, 8 for hosts (256 addresses)
- `/16` = 16 bits for network, 16 for hosts (65,536 addresses)

# Routing

- Routing is the process of finding a path to the destination network.
- Routers use routing tables to decide where to forward packets.
- Default route: used when no specific route matches.

# ICMP

- ICMP (Internet Control Message Protocol) works with IP for error reporting and network diagnostics.
- It does not carry application data like TCP or UDP.
- Common uses:
  - `ping` uses ICMP Echo Request / Echo Reply
  - `traceroute` often depends on ICMP Time Exceeded messages
  - destination unreachable tells sender that packet cannot be delivered
- ICMP is useful for checking reachability and troubleshooting routing problems.

```bash
ping 8.8.8.8
traceroute 8.8.8.8
```

# Gateway

- Gateway (default gateway) is the router that connects a local network to other networks.
- When a host sends to an IP outside its subnet, it sends the packet to the gateway.
- Gateway forwards the packet toward the destination.

# NAT (Network Address Translation)

- NAT translates private IPs to a public IP (and back) when traffic goes to the internet.
- Allows many devices to share one public IP.
- Types:
  - SNAT (Source NAT): outbound; private IP → public IP
  - DNAT (Destination NAT): inbound; public IP:port → private IP:port

```
Client (192.168.1.10) → Router (NAT) → Internet (public IP)
```
