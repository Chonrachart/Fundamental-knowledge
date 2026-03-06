overview what is network
it happen through layer
Networking overview
Network stack overview
Packet flow overview
Topic map (link ไปไฟล์อื่น)
Concept relationships

---

# What is a Network

- A network allows devices to communicate and share resources.
- Data is sent in small units (packets) from source to destination.
- Communication happens through layers; each layer adds headers and passes data down or up.

# Networking Overview

- Networking follows a layered model (OSI or TCP/IP).
- Each layer has a specific role; lower layers handle physical transmission, higher layers handle application data.
- Encapsulation: data is wrapped with headers at each layer as it travels down the stack.

# Network Stack Overview

```
Application  →  HTTP, DNS, etc.
     ↓
Transport    →  TCP, UDP (ports)
     ↓
Network      →  IP (addressing, routing)
     ↓
Link         →  Ethernet, MAC
     ↓
Physical     →  Cables, signals
```

# Packet Flow Overview

- Outgoing: Application → Socket → Transport → IP → Link → Physical → Wire
- Incoming: Wire → Physical → Link → IP → Transport → Socket → Application
- Each layer adds (outgoing) or removes (incoming) its header.

# Topic Map

- [001-network-models](./001-network-models.md) — OSI, TCP/IP, encapsulation
- [002-transport-layer](./002-transport-layer.md) — TCP, UDP, ports, sockets
- [003-addressing-and-routing](./003-addressing-and-routing.md) — IP, subnet, routing, NAT
- [04-DNS](./04-DNS.md) — DNS resolution
- [005-http-https](./005-http-https.md) — HTTP, HTTPS
- [06-TLS-and-SSL-cert-chain](./06-TLS-and-SSL-cert-chain.md) — TLS, certificates
- [007-proxy-and-load-balancing](./007-proxy-and-load-balancing.md) — Proxy, load balancing

# Concept Relationships

- IP addresses identify hosts; ports identify services.
- TCP provides reliable delivery; UDP provides fast, connectionless delivery.
- DNS resolves names to IPs; HTTP/HTTPS use TCP for web traffic.
- TLS secures HTTP; proxies and load balancers sit in front of servers.