# IPsec and VPN

- IPsec (Internet Protocol Security) is a Layer 3 protocol suite that secures IP traffic with encryption, integrity verification, and peer authentication.
- VPN (Virtual Private Network) creates a secure tunnel over an untrusted network; IPsec is one of the primary technologies used to build VPNs.
- IPsec operates in two modes: transport mode (host-to-host, protects payload) and tunnel mode (site-to-site, encapsulates entire packet).

# Architecture

```text
Transport Mode (host-to-host):
  +--------+                              +--------+
  | Host A | ====== IPsec (payload) =====>| Host B |
  +--------+                              +--------+
  Original IP header preserved
  Only IP payload is encrypted/authenticated

Tunnel Mode (site-to-site VPN):
  +--------+     +---------+                    +---------+     +--------+
  | Host A | --> | Gateway | ==== IPsec ======> | Gateway | --> | Host B |
  +--------+     | (VPN)   |  tunnel over       | (VPN)   |     +--------+
  10.1.0.0/24    +---------+  internet           +---------+  10.2.0.0/24
                 Public IP                       Public IP
  Entire original packet wrapped in new IP header + ESP
```

# Mental Model

```text
Site-to-site VPN setup:
  |
  v
1. IKE Phase 1 (establish secure channel)
   - Peers authenticate (pre-shared key or certificate)
   - Negotiate encryption algorithm, hash, DH group
   - Establish IKE Security Association (SA)
  |
  v
2. IKE Phase 2 (establish IPsec tunnel)
   - Negotiate IPsec transform set (ESP/AH, encryption, hash)
   - Establish IPsec Security Associations (one per direction)
   - Define interesting traffic (what to encrypt)
  |
  v
3. Data transfer
   - Matching traffic is encrypted and encapsulated (ESP)
   - Sent through the tunnel
   - Receiver verifies integrity and decrypts
  |
  v
4. SA lifetime expires --> renegotiate (rekey)
```

Example: checking IPsec status on Linux with strongSwan:

```bash
# Check IKE SA status
ipsec statusall

# Output example:
# Connections:
#   site-to-site: 203.0.113.1...198.51.100.1 IKEv2
# Security Associations:
#   site-to-site[1]: ESTABLISHED 2 hours ago, 203.0.113.1[C=US]...198.51.100.1[C=US]
#   site-to-site{1}: INSTALLED, TUNNEL, ESP in UDP, 10.1.0.0/24 === 10.2.0.0/24
```

# Core Building Blocks

### What IPsec Does

- **Encrypts** packet data so eavesdroppers cannot read it
- **Verifies integrity** so packets are not modified in transit
- **Authenticates peers** before sending protected traffic
- Works at Layer 3 (network layer), transparent to applications above

Related notes: [006-TLS-and-SSL-cert-chain](./006-TLS-and-SSL-cert-chain.md)

### AH (Authentication Header)

- Provides integrity and authentication of the entire packet (including IP header).
- Does **not** encrypt the payload.
- Less common in practice; mostly replaced by ESP.
- Protocol number: 51

Related notes: [006-TLS-and-SSL-cert-chain](./006-TLS-and-SSL-cert-chain.md)

### ESP (Encapsulating Security Payload)

- Provides encryption **and** can also provide integrity/authentication.
- Most modern IPsec deployments use ESP exclusively.
- Protocol number: 50
- Supports both transport and tunnel modes.

Related notes: [006-TLS-and-SSL-cert-chain](./006-TLS-and-SSL-cert-chain.md)

### IKE (Internet Key Exchange)

- Negotiates security parameters and exchanges keys between peers.
- IKEv1 has two phases; IKEv2 simplifies the process.
- IKEv2 is the modern standard:
  - Fewer round trips
  - Built-in NAT traversal
  - MOBIKE support for mobile clients
- Uses UDP port 500 (or 4500 with NAT traversal).

Related notes: [006-TLS-and-SSL-cert-chain](./006-TLS-and-SSL-cert-chain.md)

### Transport Mode

- Protects only the IP payload; original IP header remains visible.
- Used for host-to-host communication (e.g., server-to-server encryption).
- Lower overhead than tunnel mode.

```text
[Original IP Header] [ESP Header] [Encrypted Payload] [ESP Trailer]
```

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### Tunnel Mode

- Encapsulates the entire original IP packet inside a new IP packet.
- Used for site-to-site VPN and remote access VPN.
- Hides the original source and destination IPs.

```text
[New IP Header] [ESP Header] [Original IP Header + Payload (encrypted)] [ESP Trailer]
```

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md), [007-proxy-and-load-balancing](./007-proxy-and-load-balancing.md)

### Common Use Cases

- **Site-to-site VPN** -- connect two office networks over the internet
- **Remote access VPN** -- individual user connects to company network
- **Server-to-server** -- protect traffic between servers over untrusted networks
- **Cloud connectivity** -- secure tunnels to cloud VPCs (AWS VPN, Azure VPN Gateway)

Related notes: [007-proxy-and-load-balancing](./007-proxy-and-load-balancing.md)

### IPsec vs TLS

| IPsec                                 | TLS                                    |
| :------------------------------------ | :------------------------------------- |
| Layer 3 (network)                     | Layer 4-7 (transport/application)      |
| Protects all IP traffic               | Protects specific application sessions |
| Requires kernel/OS support            | Application-level, no kernel changes   |
| Site-to-site, remote access VPN       | HTTPS, secure APIs, email              |
| Transparent to applications           | Application must use TLS libraries     |

Related notes: [006-TLS-and-SSL-cert-chain](./006-TLS-and-SSL-cert-chain.md)

---

# Practical Command Set (Core)

```bash
# strongSwan: check all IPsec connections and SAs
ipsec statusall

# Start/stop IPsec
ipsec start
ipsec stop
ipsec restart

# Bring up a specific connection
ipsec up site-to-site

# Bring down a specific connection
ipsec down site-to-site

# View kernel IPsec policies (xfrm)
ip xfrm state
ip xfrm policy

# Capture ESP packets for debugging
tcpdump -i eth0 esp

# Check IKE negotiation (UDP 500/4500)
tcpdump -i eth0 port 500 or port 4500

# View IPsec logs
journalctl -u strongswan -f
```


- IPsec works at Layer 3; it secures all IP traffic transparently to applications.
- VPN is the use case; IPsec is one technology that implements it.
- ESP (protocol 50) provides encryption + integrity; AH (protocol 51) provides integrity only.
- IKEv2 is the modern standard for key negotiation; uses UDP 500/4500.
- Transport mode: protects payload, keeps original IP header (host-to-host).
- Tunnel mode: encapsulates entire packet in new IP header (site-to-site VPN).
- IPsec secures network-layer traffic; TLS secures application-layer traffic -- they serve different purposes.
- If you only need secure web traffic, TLS is sufficient; for network-to-network encryption, use IPsec.
# Troubleshooting Guide

```text
IPsec tunnel not coming up?
  |
  +--> IKE Phase 1 failing?
  |       |
  |       +--> Pre-shared key mismatch? --> verify on both peers
  |       +--> Peer IP wrong? --> check remote gateway address
  |       +--> UDP 500/4500 blocked? --> check firewall rules
  |       +--> Proposal mismatch? --> align encryption/hash/DH group
  |
  +--> IKE Phase 2 failing?
  |       |
  |       +--> Transform set mismatch? --> align ESP algorithms
  |       +--> Traffic selectors mismatch? --> verify subnet definitions
  |
  +--> Tunnel up but no traffic?
  |       |
  |       +--> Check routing: ip route (traffic going into tunnel?)
  |       +--> Check xfrm policies: ip xfrm policy
  |       +--> NAT interfering? --> enable NAT-T (UDP 4500)
  |       +--> MTU issues? --> lower MTU or enable PMTUD
  |
  +--> Tunnel drops periodically?
          |
          +--> SA lifetime mismatch? --> align rekey timers
          +--> DPD (Dead Peer Detection) failing? --> check connectivity
```
