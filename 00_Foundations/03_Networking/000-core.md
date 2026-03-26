# Networking

- A network allows devices to communicate and share resources by sending data in small units (packets) from source to destination.
- Communication follows a layered model (OSI or TCP/IP); each layer adds headers (encapsulation) going down and removes them going up.
- IP addresses identify hosts, ports identify services, and protocols define the rules for data exchange.

# Architecture

```text
+----------------------------------------------------------+
|                      Application                         |
|              HTTP, DNS, SMTP, SSH, TLS                   |
+----------------------------------------------------------+
                          |
+----------------------------------------------------------+
|                      Transport                           |
|               TCP (reliable) / UDP (fast)                |
|                   Port numbers                           |
+----------------------------------------------------------+
                          |
+----------------------------------------------------------+
|                      Network                             |
|              IP addressing, routing, ICMP                |
+----------------------------------------------------------+
                          |
+----------------------------------------------------------+
|                       Link                               |
|            Ethernet, Wi-Fi, MAC, ARP                     |
+----------------------------------------------------------+
                          |
+----------------------------------------------------------+
|                      Physical                            |
|             Cables, fiber, radio signals                 |
+----------------------------------------------------------+
```

# Mental Model

```text
Outgoing (sender):
  Application data
      |  + TCP/UDP header
      v
  Segment / Datagram
      |  + IP header
      v
  Packet
      |  + Frame header/trailer
      v
  Frame
      |  converted to signals
      v
  Bits on the wire

Incoming (receiver):
  Bits on the wire  -->  Frame  -->  Packet  -->  Segment  -->  Application data
  (each layer strips its header)
```

```bash
# trace the path a packet takes from your machine to a destination
traceroute 8.8.8.8
```

## How the Internet Works

```text
How a web server becomes reachable from the internet:

  Internet User types example.com
       │
       ▼
  Public DNS resolves example.com → 203.0.113.50 (your public IP)
       │
       ▼
  ISP / Internet routes packet to your public IP
  (BGP determines the path between networks)
       │
       ▼
  Router/Firewall (NAT + port forwarding)
  - Public IP 203.0.113.50:443 → Private IP 192.168.1.10:443
  - Firewall rules: allow 443, block everything else
       │
       ▼
  Your web server (192.168.1.10) on private network
       │
       ▼
  Reverse proxy (nginx) → Application

What keeps something internal (not reachable from the internet):
  - No public DNS record — nobody can resolve the hostname
  - No NAT/port forwarding rule — router drops inbound traffic
  - Firewall blocks inbound — even if NAT is configured, firewall denies it
  - Private IP only (10.x, 172.16-31.x, 192.168.x) — not routable on internet

How to expose a service:
  1. Get a public IP (from ISP or cloud provider)
  2. Register a DNS record pointing your domain to that public IP
  3. Configure NAT/port forwarding (home) or assign public IP directly (cloud)
  4. Open firewall ports for the service (e.g., 443 for HTTPS)
  5. Run the service and verify with: curl https://yourdomain.com
```

# Core Building Blocks

### Layered Models

- OSI (7 layers) is a conceptual reference; TCP/IP (4 layers) is the practical model used by the internet.
- Each layer has a defined responsibility and communicates only with its adjacent layers.
- Encapsulation wraps data with headers going down; de-encapsulation strips them going up.

Related notes: [001-network-models](./001-network-models.md)

### Link Layer and Ethernet

- Ethernet delivers frames between devices on the same local network using MAC addresses.
- ARP resolves IP addresses to MAC addresses so devices on the same LAN can communicate.
- VLANs logically segment a switch into isolated broadcast domains.

Related notes: [002-link-layer-and-ethernet](./002-link-layer-and-ethernet.md)

### Addressing and Routing

- IP addresses (IPv4 32-bit, IPv6 128-bit) identify hosts on a network.
- Subnets and CIDR notation partition address space; routing tables determine packet forwarding.
- NAT translates private IPs to public IPs, allowing many devices to share one public address.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### DHCP

- DHCP automatically assigns IP addresses and configuration (gateway, DNS) to devices joining a network.
- Uses a 4-step broadcast handshake: Discover → Offer → Request → Acknowledge (DORA).

Related notes: [004-dhcp](./004-dhcp.md)

### Transport Protocols

- TCP provides reliable, ordered, connection-oriented delivery (3-way handshake).
- UDP provides fast, connectionless, best-effort delivery with lower overhead.
- Ports (0-65535) identify services; sockets (IP + Port + Protocol) are communication endpoints.

Related notes: [005-transport-layer](./005-transport-layer.md)

### DNS

- DNS resolves human-readable domain names to IP addresses.
- Hierarchical system: root servers, TLD servers, authoritative servers, resolvers.
- Record types include A, AAAA, CNAME, MX, NS, TXT, SOA.

Related notes: [006-dns](./006-dns.md)

### Firewalls

- Firewalls control traffic by allowing or denying packets based on rules.
- Stateful firewalls track connections; stateless firewalls inspect each packet independently.
- DMZ zones isolate public-facing servers from internal networks.

Related notes: [007-firewall-concepts](./007-firewall-concepts.md)

### HTTP and HTTPS

- HTTP is a stateless request/response protocol for web communication over TCP.
- HTTPS wraps HTTP inside TLS for encryption, integrity, and authentication.
- HTTP/2 adds multiplexing; HTTP/3 uses QUIC (UDP-based) for faster connections.

Related notes: [008-http-https](./008-http-https.md)

### TLS and Certificates

- TLS provides encryption, integrity, and authentication for network communication.
- Certificate chain: server cert → intermediate CA → root CA, each signed by the one above.
- TLS handshake negotiates cipher suite, exchanges keys, and establishes encrypted session.

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

### Proxy and Load Balancing

- Forward proxy acts on behalf of clients; reverse proxy acts on behalf of servers.
- Load balancers distribute traffic across backend servers for availability and performance.
- L4 load balancers route by IP/port; L7 load balancers route by HTTP content.

Related notes: [010-proxy-and-load-balancing](./010-proxy-and-load-balancing.md)

### VPN Technologies

- VPN creates an encrypted tunnel over a public network for secure communication.
- IPsec operates at Layer 3 with complex IKE negotiation — established standard for enterprise.
- WireGuard is a modern, minimal alternative with simpler configuration and stronger defaults.

Related notes: [011-vpn-technologies](./011-vpn-technologies.md)

### Multicast and Broadcast

- Broadcast sends to all devices on a LAN (used by ARP, DHCP); confined to local segment.
- Multicast sends to a subscribed group (used by mDNS, OSPF, video streaming).
- STP prevents broadcast storms caused by network loops.

Related notes: [012-multicast-and-broadcast](./012-multicast-and-broadcast.md)

### Dynamic Routing

- Static routes are manually configured; dynamic routing protocols let routers learn routes automatically.
- OSPF (link-state) routes within an organization; BGP (path-vector) routes between organizations on the internet.

Related notes: [013-dynamic-routing](./013-dynamic-routing.md)

---

# Troubleshooting Guide

### Cannot reach a service
1. Check if interface is up: `ip link show`.
2. Check if you have an IP: `ip addr show`.
3. Check if there is a route to destination: `ip route show` / `traceroute <dest>`.
4. Check if DNS resolves: `dig <domain>` / `nslookup <domain>`.
5. Check if port is open: `ss -tulnp` / `nc -zv <host> <port>`.
6. Check if service responds: `curl -v https://<host>`.

# Topic Map

- [001-network-models](./001-network-models.md) — OSI, TCP/IP, encapsulation
- [002-link-layer-and-ethernet](./002-link-layer-and-ethernet.md) — Ethernet, MAC, ARP, VLAN, MTU
- [003-addressing-and-routing](./003-addressing-and-routing.md) — IP, subnet, routing, NAT, ICMP
- [004-dhcp](./004-dhcp.md) — DHCP, DORA process, leases
- [005-transport-layer](./005-transport-layer.md) — TCP, UDP, ports, sockets
- [006-dns](./006-dns.md) — DNS resolution, record types
- [007-firewall-concepts](./007-firewall-concepts.md) — Stateful/stateless, zones, DMZ
- [008-http-https](./008-http-https.md) — HTTP, HTTPS, HTTP/2, HTTP/3
- [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md) — TLS, SSL, certificates
- [010-proxy-and-load-balancing](./010-proxy-and-load-balancing.md) — Proxy, load balancing
- [011-vpn-technologies](./011-vpn-technologies.md) — IPsec, WireGuard, VPN
- [012-multicast-and-broadcast](./012-multicast-and-broadcast.md) — Broadcast, multicast, mDNS
- [013-dynamic-routing](./013-dynamic-routing.md) — OSPF, BGP, dynamic routing
