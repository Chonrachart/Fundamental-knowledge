# Firewall Concepts

- A firewall controls network traffic by allowing or denying packets based on defined rules.
- Stateless firewalls inspect each packet independently; stateful firewalls track connections and allow related return traffic automatically.
- Firewalls are placed at network boundaries (perimeter), on individual hosts, and between internal zones (DMZ).

# Architecture

```text
                         Internet (untrusted)
                              |
                              v
                    +-------------------+
                    | Perimeter Firewall|  <-- First line of defense
                    | (allow 80,443)    |      Blocks everything except
                    +-------------------+      explicitly allowed ports
                         |          |
              +----------+          +----------+
              v                                v
    +------------------+            +------------------+
    |       DMZ        |            |  Internal LAN    |
    | (public servers) |            | (trusted zone)   |
    |                  |            |                  |
    | Web server       |            | Workstations     |
    | Mail server      |            | Internal apps    |
    +------------------+            +------------------+
              |                                |
              +--- Internal Firewall ----------+
                   (DMZ cannot reach LAN
                    unless explicitly allowed)

    Host-based Firewall (on each server):
    +--------------------------------------------+
    | Server                                     |
    |  iptables/nftables/Windows Firewall        |
    |  - Allow port 443 from any                 |
    |  - Allow port 22 from management subnet    |
    |  - Deny everything else                    |
    +--------------------------------------------+
```

# Mental Model

```text
How a firewall evaluates a packet:

  Packet arrives (src: 203.0.113.50, dst: 10.0.1.5, port: 443, TCP SYN)
       |
       v
  Stateless check: match against rules top-to-bottom
  Rule 1: allow TCP dst port 443 from any       → MATCH → allow
  Rule 2: allow TCP dst port 22 from 10.0.0.0/8
  Rule 3: deny all                               (default deny)
       |
       v
  Stateful check (if stateful firewall):
  - Is this a NEW connection? → check rules as above
  - Is this part of an ESTABLISHED connection? → allow automatically
  - Is this RELATED (e.g., ICMP error for an active connection)? → allow
       |
       v
  Packet forwarded or dropped

  Key insight: stateful firewalls only need "allow outbound" rules.
  Return traffic for established connections is allowed automatically.
  This is why you don't need explicit "allow inbound" for responses.
```

```bash
# example: iptables stateful rule set
# allow established/related connections (return traffic)
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# allow new SSH connections
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
# deny everything else
iptables -A INPUT -j DROP
```

# Core Building Blocks

### Stateless Filtering

- Evaluates each packet independently — no memory of previous packets.
- Matches on: source/destination IP, source/destination port, protocol (TCP/UDP/ICMP).
- Fast and simple, but requires rules for both directions (outbound request AND inbound response).
- Used in: simple routers, ACLs (Access Control Lists) on network devices, AWS NACLs.
- Limitation: cannot distinguish a legitimate response from an unsolicited inbound packet.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### Stateful Filtering

- Tracks connection state using a state table (also called conntrack table).
- Connection states:
  - **NEW**: first packet of a connection (e.g., TCP SYN)
  - **ESTABLISHED**: part of an active, recognized connection
  - **RELATED**: associated with an existing connection (e.g., ICMP error about an active session)
  - **INVALID**: does not match any known connection — usually dropped
- Only outbound rules needed — return traffic for established connections is allowed automatically.
- Used in: iptables/nftables (Linux), Windows Firewall, AWS Security Groups, most modern firewalls.
- Trade-off: uses memory to track connections; can be overwhelmed by connection floods (DDoS).

For Linux implementation details, see: `01_Linux/Networking/006-firewall-iptables-nftable.md`

Related notes: [005-transport-layer](./005-transport-layer.md)

### Firewall Zones

- Zones group network interfaces by trust level and define what traffic can flow between them.
- Common zones:
  - **Trusted / Internal (LAN)**: corporate workstations, internal servers — high trust
  - **Untrusted / External (WAN)**: the internet — zero trust
  - **DMZ (Demilitarized Zone)**: public-facing servers — limited trust
- Inter-zone policies: traffic between zones requires explicit rules (e.g., "internet → DMZ: allow 443, deny all else").
- Intra-zone: traffic within the same zone is usually allowed by default.

Related notes: [010-proxy-and-load-balancing](./010-proxy-and-load-balancing.md)

### DMZ Pattern

- Public-facing servers (web, mail, DNS) are placed in a DMZ — a separate network between the internet and the internal LAN.
- Why: if a public server is compromised, the attacker is isolated in the DMZ and cannot directly reach internal systems.
- **Single-firewall DMZ**: one firewall with three interfaces (internet, DMZ, LAN). Simpler but single point of failure.
- **Two-firewall DMZ**: outer firewall protects internet→DMZ; inner firewall protects DMZ→LAN. More secure but more complex.

```text
Single-firewall DMZ:
  Internet ─── [Firewall] ─── DMZ (web server)
                    |
                    └──── Internal LAN

Two-firewall DMZ:
  Internet ─── [Outer FW] ─── DMZ ─── [Inner FW] ─── Internal LAN
```

- DMZ rules typically: allow internet → DMZ on specific ports (80, 443), deny DMZ → LAN (except specific APIs), allow LAN → DMZ freely.

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

### Cloud Security Groups

- Cloud providers (AWS, Azure, GCP) implement firewalls as Security Groups or Network Security Groups.
- Security Groups are **stateful** by default — allow a rule for inbound, and the response is automatically allowed.
- Applied at the instance/VM level (not at the subnet level like NACLs).
- Key difference from traditional firewalls: Security Groups only have allow rules — there is no explicit deny. Anything not allowed is denied by default.
- NACLs (Network ACLs) are the cloud equivalent of stateless firewalls at the subnet level.

| Feature | Security Group | NACL |
|---------|---------------|------|
| Level | Instance | Subnet |
| Stateful | Yes | No |
| Rules | Allow only | Allow + Deny |
| Evaluation | All rules | Top-to-bottom, first match |

Related notes: [003-addressing-and-routing](./003-addressing-and-routing.md)

---

# Troubleshooting Guide

### Traffic blocked unexpectedly
1. Identify where the block is: `traceroute` to see how far packets get.
2. Check host firewall: `iptables -L -n -v` or `nft list ruleset` — look for DROP/REJECT rules.
3. Check perimeter firewall rules and logs for denied traffic.
4. Test with firewall temporarily disabled (in a safe environment) to confirm it's the cause.

### Stateful vs stateless confusion
1. Symptom: outbound works but responses are blocked (common with stateless firewalls/NACLs).
2. Stateless requires explicit rules for return traffic (ephemeral ports 1024-65535).
3. Stateful handles this automatically — check if conntrack is enabled.

### Zone misconfiguration
1. Symptom: servers in DMZ can reach internal LAN (should be denied).
2. Check inter-zone policies: is there an unintended allow rule?
3. Verify interface-to-zone assignments: is the interface in the correct zone?
