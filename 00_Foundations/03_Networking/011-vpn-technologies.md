# VPN Technologies

- VPN (Virtual Private Network) creates a secure encrypted tunnel over an untrusted network.
- IPsec is a Layer 3 protocol suite with complex negotiation (IKE) — powerful but complex to configure.
- WireGuard is a modern, minimal VPN protocol with simpler design and stronger default cryptography.

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

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

### AH (Authentication Header)

- Provides integrity and authentication of the entire packet (including IP header).
- Does **not** encrypt the payload.
- Less common in practice; mostly replaced by ESP.
- Protocol number: 51

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

### ESP (Encapsulating Security Payload)

- Provides encryption **and** can also provide integrity/authentication.
- Most modern IPsec deployments use ESP exclusively.
- Protocol number: 50
- Supports both transport and tunnel modes.

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

### IKE (Internet Key Exchange)

- Negotiates security parameters and exchanges keys between peers.
- IKEv1 has two phases; IKEv2 simplifies the process.
- IKEv2 is the modern standard:
  - Fewer round trips
  - Built-in NAT traversal
  - MOBIKE support for mobile clients
- Uses UDP port 500 (or 4500 with NAT traversal).

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

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

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md), [010-proxy-and-load-balancing](./010-proxy-and-load-balancing.md)

### Common Use Cases

- **Site-to-site VPN** -- connect two office networks over the internet
- **Remote access VPN** -- individual user connects to company network
- **Server-to-server** -- protect traffic between servers over untrusted networks
- **Cloud connectivity** -- secure tunnels to cloud VPCs (AWS VPN, Azure VPN Gateway)

Related notes: [010-proxy-and-load-balancing](./010-proxy-and-load-balancing.md)

### IPsec vs TLS

| IPsec                                 | TLS                                    |
| :------------------------------------ | :------------------------------------- |
| Layer 3 (network)                     | Layer 4-7 (transport/application)      |
| Protects all IP traffic               | Protects specific application sessions |
| Requires kernel/OS support            | Application-level, no kernel changes   |
| Site-to-site, remote access VPN       | HTTPS, secure APIs, email              |
| Transparent to applications           | Application must use TLS libraries     |

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

### WireGuard

- Modern VPN protocol designed for simplicity — roughly 4,000 lines of code vs 400,000+ for IPsec/OpenVPN.
- Runs in the Linux kernel (also available on Windows, macOS, mobile).
- Uses UDP on a single configurable port (default 51820).
- Fixed modern cryptography (no cipher negotiation):
  - Key exchange: Curve25519
  - Encryption: ChaCha20
  - Authentication: Poly1305
  - Hashing: BLAKE2s
- **Cryptokey routing**: each peer has a public key and a list of allowed IPs. The public key determines which peer to send to; the allowed IPs determine which traffic to encrypt.

```text
WireGuard peer configuration:
  [Peer]
  PublicKey = <peer-public-key>
  AllowedIPs = 10.2.0.0/24        <-- traffic to this subnet goes through this peer
  Endpoint = 203.0.113.50:51820   <-- peer's public IP and port
```

- No connection state to manage — if a peer is silent, WireGuard sends no traffic (no keepalive overhead by default).
- Roaming: if a peer's IP changes (e.g., mobile switching networks), WireGuard updates the endpoint automatically on the next authenticated packet.

### WireGuard vs IPsec

| Property | WireGuard | IPsec |
|----------|-----------|-------|
| Code complexity | ~4,000 lines | ~400,000+ lines |
| Cipher negotiation | None (fixed modern set) | Complex (many algorithm choices) |
| Key exchange | Noise protocol (1-RTT) | IKE Phase 1 + Phase 2 (multiple RTT) |
| Configuration | Simple (public key + allowed IPs) | Complex (proposals, transforms, policies) |
| Performance | Fast (kernel-level, modern crypto) | Varies (depends on implementation) |
| UDP port | Single port (51820) | Multiple: UDP 500, 4500 |
| Stealth | Silent when idle | Periodic IKE keepalives |
| Use cases | Remote access, site-to-site, containers | Enterprise VPN, cloud gateways, legacy |

- WireGuard is preferred for new deployments where simplicity and performance matter.
- IPsec remains necessary for interoperability with existing enterprise equipment and cloud VPN gateways (AWS VPN, Azure VPN Gateway).

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

---

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
