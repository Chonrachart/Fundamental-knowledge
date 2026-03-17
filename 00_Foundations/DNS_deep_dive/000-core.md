# DNS Deep Dive

- DNS is the distributed naming system that maps domain names to IP addresses, underpinning virtually every network service.
- Resolution follows a hierarchical chain: stub resolver -> recursive resolver -> root -> TLD -> authoritative nameserver, with caching at every layer.
- Operational DNS knowledge -- record types, TTL strategy, internal service discovery, DNSSEC -- is critical for reliable infrastructure.

> For DNS fundamentals, see [Networking/004-DNS](../Networking/004-DNS.md)

# Architecture

```text
+------------+     +-------------------+     +----------------+
|   Client   |---->|  Stub Resolver    |---->| Recursive      |
| (browser,  |     | (/etc/resolv.conf |     | Resolver       |
|  curl, app)|     |  systemd-resolved)|     | (ISP, 8.8.8.8, |
+------------+     +-------------------+     |  corporate)    |
                                             +--------+-------+
                                                      |
                        +-----------------------------+-----------------------------+
                        |                             |                             |
                        v                             v                             v
               +----------------+          +-------------------+         +---------------------+
               | Root Servers   |          | TLD Servers       |         | Authoritative       |
               | (., 13 groups) |--------->| (.com, .org, .io) |-------->| Nameservers         |
               +----------------+          +-------------------+         | (ns1.example.com)   |
                                                                         +----------+----------+
                                                                                    |
                                                                                    v
                                                                         +---------------------+
                                                                         | DNS Response        |
                                                                         | (A: 93.184.216.34)  |
                                                                         | + TTL for caching   |
                                                                         +---------------------+
```

# Mental Model

```text
Full resolution path (cold cache):

  [1] Application calls getaddrinfo("www.example.com")
       |
       v
  [2] Stub resolver checks /etc/hosts, then /etc/resolv.conf for nameserver
       |
       v
  [3] Recursive resolver checks its cache -- miss
       |
       v
  [4] Query root server (.)      --> "go ask .com TLD at 192.5.6.30"
       |
       v
  [5] Query .com TLD server      --> "go ask ns1.example.com at 198.51.100.1"
       |
       v
  [6] Query authoritative server --> "www.example.com = 93.184.216.34, TTL 3600"
       |
       v
  [7] Recursive resolver caches answer (TTL 3600s), returns to client
       |
       v
  [8] Client connects to 93.184.216.34
```

```bash
# trace the full resolution path step by step
dig +trace www.example.com
```

# Core Building Blocks

### Record Types

- DNS has many record types beyond A/AAAA: CNAME, MX, TXT, NS, SOA, SRV, PTR, CAA.
- Each record type serves a specific operational purpose -- mail routing, service discovery, security.
- Understanding record constraints (CNAME restrictions, MX targets, TXT uses) prevents common misconfigurations.

Related notes: [001-record-types-in-depth](./001-record-types-in-depth.md)

### Internal DNS and Service Discovery

- Production environments use internal DNS for service-to-service communication.
- Kubernetes DNS (CoreDNS), Consul, systemd-resolved, and split-horizon DNS enable internal resolution.
- Configuration files (/etc/resolv.conf, /etc/hosts, nsswitch.conf) control resolver behavior on Linux.

Related notes: [002-internal-dns-and-service-discovery](./002-internal-dns-and-service-discovery.md)

### DNS Management and Operations

- Zone management, TTL strategy, and migration planning are day-to-day DNS operations tasks.
- Cloud DNS services (Route53, Cloud DNS, Azure DNS) provide managed zones with routing policies.
- DNSSEC, DNS-01 challenges for certificates, and troubleshooting complete the operational toolkit.

Related notes: [003-dns-management-and-operations](./003-dns-management-and-operations.md)

---

# Practical Command Set (Core)

```bash
# full DNS query with all details
dig example.com

# query a specific record type
dig example.com MX
dig example.com TXT
dig example.com NS

# trace full resolution path (root -> TLD -> authoritative)
dig +trace example.com

# short answer only
dig +short example.com

# query a specific nameserver
dig @8.8.8.8 example.com

# reverse DNS lookup
dig -x 93.184.216.34

# simple lookup (less verbose than dig)
host example.com
host -t MX example.com

# nslookup (interactive-style, works on all platforms)
nslookup example.com
nslookup -type=NS example.com

# drill (DNSSEC-aware alternative to dig)
drill example.com
drill -T example.com    # trace
drill -S example.com    # DNSSEC chain
```

# Troubleshooting Guide

```text
Problem: DNS resolution not working
    |
    v
[1] Can you resolve anything at all?
    dig google.com
    |
    +-- yes --> problem is domain-specific, go to [3]
    +-- no  --> resolver issue, go to [2]
    |
    v
[2] Check resolver configuration
    cat /etc/resolv.conf
    resolvectl status          # systemd-resolved
    |
    +-- no nameserver listed   --> fix resolv.conf
    +-- nameserver unreachable --> ping the nameserver IP
    |
    v
[3] Query the domain directly against different servers
    dig @8.8.8.8 example.com         # public resolver
    dig @ns1.example.com example.com  # authoritative
    |
    +-- public works, authoritative fails --> authoritative server issue
    +-- both fail                         --> record does not exist or propagation delay
    |
    v
[4] Trace the resolution path
    dig +trace example.com
    |
    +-- stops at TLD   --> NS delegation broken
    +-- stops at auth  --> zone file issue
    |
    v
[5] Check for caching / stale records
    dig example.com | grep TTL
    +-- high TTL + wrong answer --> wait for TTL expiry or flush cache
```

# Quick Facts (Revision)

- DNS uses UDP port 53 for queries (switches to TCP for responses > 512 bytes or zone transfers).
- There are 13 root server groups (a.root-servers.net through m.root-servers.net), distributed via anycast.
- TTL (Time To Live) controls how long a resolver caches a record -- lower TTL = faster propagation, more queries.
- Recursive resolvers do the heavy lifting; stub resolvers just forward to them.
- dig +trace shows the full resolution chain; dig +short gives just the answer.
- NXDOMAIN means the domain does not exist; SERVFAIL means the server failed to process the query.
- Negative caching: NXDOMAIN responses are also cached (SOA minimum TTL).
- DNS is eventually consistent -- changes propagate as caches expire, not instantly.

# Topic Map

- [001-record-types-in-depth](./001-record-types-in-depth.md) -- A, AAAA, CNAME, MX, TXT, NS, SOA, SRV, PTR, CAA
- [002-internal-dns-and-service-discovery](./002-internal-dns-and-service-discovery.md) -- resolv.conf, CoreDNS, Kubernetes DNS, Consul, split-horizon
- [003-dns-management-and-operations](./003-dns-management-and-operations.md) -- zone management, TTL strategy, Cloud DNS, DNSSEC, migration
