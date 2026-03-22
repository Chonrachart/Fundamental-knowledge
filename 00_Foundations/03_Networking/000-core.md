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

# Core Building Blocks

### Layered Models

- OSI (7 layers) is a conceptual reference; TCP/IP (4 layers) is the practical model used by the internet.
- Each layer has a defined responsibility and communicates only with its adjacent layers.
- Encapsulation wraps data with headers going down; de-encapsulation strips them going up.
- OSI has 7 layers (conceptual); TCP/IP has 4 layers (practical, used by the internet).
- Encapsulation adds headers going down the stack; de-encapsulation removes them going up.

Related notes: [001-network-models](./001-network-models.md)

### Transport Protocols

- TCP provides reliable, ordered, connection-oriented delivery (3-way handshake).
- UDP provides fast, connectionless, best-effort delivery with lower overhead.
- Ports (0-65535) identify services; sockets (IP + Port + Protocol) are communication endpoints.
- TCP = reliable, ordered, connection-oriented; UDP = fast, connectionless, best-effort.
- Ports: 0-1023 well-known, 1024-49151 registered, 49152-65535 ephemeral.
- A socket is IP + Port + Protocol -- it uniquely identifies a communication endpoint.

Related notes: [002-transport-layer](./002-transport-layer.md)

### Addressing and Routing

- IP addresses (IPv4 32-bit, IPv6 128-bit) identify hosts on a network.
- Subnets and CIDR notation partition address space; routing tables determine packet forwarding.
- NAT translates private IPs to public IPs, allowing many devices to share one public address.
- IPv4 = 32-bit (4.3 billion addresses); IPv6 = 128-bit (virtually unlimited).
- NAT lets multiple private IPs share one public IP (SNAT outbound, DNAT inbound).

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### DNS

- DNS resolves human-readable domain names to IP addresses.
- Hierarchical system: root servers, TLD servers, authoritative servers, resolvers.
- Record types include A, AAAA, CNAME, MX, NS, TXT, SOA.
- DNS resolves names to IPs; TLS encrypts the connection; HTTPS = HTTP + TLS.

Related notes: [004-DNS](./004-DNS.md)

### HTTP and HTTPS

- HTTP is a stateless request/response protocol for web communication over TCP.
- HTTPS wraps HTTP inside TLS for encryption, integrity, and authentication.
- Methods (GET, POST, PUT, DELETE), status codes (2xx, 3xx, 4xx, 5xx), and headers define the conversation.

Related notes: [005-http-https](./005-http-https.md)

### TLS and Certificates

- TLS provides encryption, integrity, and authentication for network communication.
- Certificate chain: server cert, intermediate CA, root CA -- each signed by the one above.
- TLS handshake negotiates cipher suite, exchanges keys, and establishes encrypted session.

Related notes: [006-TLS-and-SSL-cert-chain](./006-TLS-and-SSL-cert-chain.md)

### Proxy and Load Balancing

- Forward proxy acts on behalf of clients; reverse proxy acts on behalf of servers.
- Load balancers distribute traffic across backend servers for availability and performance.
- L4 load balancers route by IP/port; L7 load balancers route by HTTP content.

Related notes: [007-proxy-and-load-balancing](./007-proxy-and-load-balancing.md)

### IPsec and VPN
Related notes: [008-ipsec-vpn](./008-ipsec-vpn.md)
- VPN creates an encrypted tunnel over a public network for secure communication.
- IPsec operates at the network layer, providing encryption and authentication for IP packets.
- Two modes: transport (host-to-host) and tunnel (gateway-to-gateway).

---

# Practical Command Set (Core)

```bash
# check network interfaces and IP addresses
ip addr show

# test reachability
ping -c 4 8.8.8.8

# trace route to destination
traceroute 8.8.8.8

# DNS lookup
dig example.com
nslookup example.com

# show routing table
ip route show

# show active connections and listening ports
ss -tulnp

# capture packets (requires root)
tcpdump -i eth0 -n port 443
```


# Troubleshooting Guide

```text
Problem: cannot reach a service
    |
    v
[1] Physical/Link: is interface up? cable connected?
    ip link show
    |
    v
[2] Network: do you have an IP? can you ping gateway?
    ip addr show / ping <gateway>
    |
    v
[3] Routing: is there a route to destination?
    ip route show / traceroute <dest>
    |
    v
[4] DNS: does the name resolve?
    dig <domain> / nslookup <domain>
    |
    v
[5] Transport: is the port open? can you connect?
    ss -tulnp / nc -zv <host> <port>
    |
    v
[6] Application: is the service responding correctly?
    curl -v https://<host>
```

# Topic Map

- [001-network-models](./001-network-models.md) -- OSI, TCP/IP, encapsulation
- [002-transport-layer](./002-transport-layer.md) -- TCP, UDP, ports, sockets
- [003-addressing-and-routing](./003-addressing-and-routing.md) -- IP, subnet, routing, NAT
- [004-DNS](./004-DNS.md) -- DNS resolution, record types
- [005-http-https](./005-http-https.md) -- HTTP, HTTPS protocols
- [006-TLS-and-SSL-cert-chain](./006-TLS-and-SSL-cert-chain.md) -- TLS, SSL, certificates
- [007-proxy-and-load-balancing](./007-proxy-and-load-balancing.md) -- Proxy, load balancing
- [008-ipsec-vpn](./008-ipsec-vpn.md) -- IPsec, VPN
