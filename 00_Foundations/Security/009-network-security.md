# Network Security

- Network security encompasses the policies, practices, and tools that protect network infrastructure and data in transit from unauthorized access, misuse, and attacks
- It operates across multiple layers — from perimeter firewalls to application-level WAFs — following a defense-in-depth strategy
- Modern approaches combine traditional perimeter controls with zero-trust principles: verify every request, enforce least privilege, and assume breach

## Architecture

```text
  ┌─────────────────────────────────────────────────────────────────┐
  │                    Defense in Depth Layers                      │
  │                                                                 │
  │  ┌───────────────────────────────────────────────────────────┐  │
  │  │  PERIMETER        Internet ──► DDoS mitigation ──► CDN    │  │
  │  │                   WAF, Edge firewall                      │  │
  │  ├───────────────────────────────────────────────────────────┤  │
  │  │  NETWORK          Firewalls, IDS/IPS, VLANs, ACLs         │  │
  │  │                   DMZ, segmentation, VPN                  │  │
  │  ├───────────────────────────────────────────────────────────┤  │
  │  │  HOST             OS hardening, SELinux/AppArmor          │  │
  │  │                   Host firewall, antivirus, patching      │  │
  │  ├───────────────────────────────────────────────────────────┤  │
  │  │  APPLICATION      Auth, input validation, WAF rules       │  │
  │  │                   Secure coding, OWASP top 10             │  │
  │  ├───────────────────────────────────────────────────────────┤  │
  │  │  DATA             Encryption at rest/in transit, DLP      │  │
  │  │                   Backup, access control, classification  │  │
  │  └───────────────────────────────────────────────────────────┘  │
  └─────────────────────────────────────────────────────────────────┘
```

## Mental Model

```text
  Segment         Control          Detect           Respond
  the network     access           threats          to incidents
  ─────────────► ──────────────► ──────────────► ──────────────►

  1. VLANs,       2. Firewall      3. IDS/IPS       4. SIEM
     subnets,        rules,           Snort,           correlation,
     DMZ,            ACLs,            Suricata,        alerting,
     micro-seg       zero trust       log analysis     forensics
```

Example: basic network segmentation with a DMZ.

```text
  Internet
      │
  ┌───┴───┐
  │  FW1  │  ─── outer firewall (allow HTTP/S, deny all else)
  └───┬───┘
      │
  ┌───┴──────────┐
  │     DMZ      │  ─── web servers, reverse proxy, WAF
  │  10.0.1.0/24 │
  └───┬──────────┘
      │
  ┌───┴───┐
  │  FW2  │  ─── inner firewall (allow only app ports from DMZ)
  └───┬───┘
      │
  ┌───┴──────────┐
  │  Internal    │  ─── app servers, databases
  │  10.0.2.0/24 │
  └──────────────┘
```

## Core Building Blocks

### Defense in Depth

- Multiple overlapping security controls so that failure of one layer does not compromise the system
- No single technology is sufficient — combine perimeter, network, host, application, and data controls
- Layers should be independent: a firewall bypass should not also bypass host controls
- Includes both preventive (firewall, ACLs) and detective (IDS, SIEM, audit logs) controls
- Also includes administrative controls: policies, training, incident response plans

Related notes: [008-linux-security-hardening](./008-linux-security-hardening.md)

### Zero Trust

- **Core principle**: "Never trust, always verify" — no implicit trust based on network location
- Replaces the traditional perimeter model where internal = trusted
- **Three pillars**:
  - **Verify explicitly** — authenticate and authorize every request using all available data (identity, location, device, service)
  - **Least privilege access** — just-in-time and just-enough access; minimize blast radius
  - **Assume breach** — segment access, use end-to-end encryption, continuously monitor

```text
  Traditional Perimeter             Zero Trust
  ─────────────────────             ──────────────────────
  ┌──────────────────┐              Every request:
  │ Trusted Internal │              ┌──────────────────┐
  │   (flat network) │              │ Identity check   │
  │   free movement  │              │ Device check     │
  │                  │              │ Context check    │
  └──────┬───────────┘              │ Policy engine    │
  ───────┴────────                  │ Micro-segment    │
  Untrusted External                └──────────────────┘
```

- **Micro-segmentation** — granular network segments (per workload or per service); enforce policy at each boundary
- Implementation tools: service mesh (Istio), identity-aware proxy (BeyondCorp), software-defined perimeter (SDP)

Related notes: [008-linux-security-hardening](./008-linux-security-hardening.md), [TLS and SSL cert chain](../Networking/006-TLS-and-SSL-cert-chain.md)

### Network Segmentation

- Divides the network into isolated zones to limit lateral movement after a breach
- **VLANs** — Layer 2 segmentation; logically separate broadcast domains on the same physical switch
- **Subnets** — Layer 3 segmentation; separate IP address ranges with routing between them
- **DMZ** — demilitarized zone between external (internet) and internal networks; hosts public-facing services

```text
  Traffic directions:

  North-South traffic          East-West traffic
  (client ↔ datacenter)       (server ↔ server within datacenter)
  ┌─────────┐                  ┌─────────┐     ┌─────────┐
  │ Client  │                  │ App     │ ◄──►│ DB      │
  └────┬────┘                  │ Server  │     │ Server  │
       │                       └─────────┘     └─────────┘
  ┌────┴────┐
  │ Server  │     North-south is traditionally firewalled;
  └─────────┘     east-west often lacks controls (zero trust fixes this)
```

- Firewall rules between segments control which traffic crosses boundaries
- Modern: microsegmentation with host-based firewalls, network policies (Kubernetes NetworkPolicy), or service mesh

Related notes: [firewall-iptables-nftable](../Linux/Networking/006-firewall-iptables-nftable.md)

### IDS/IPS

- **IDS (Intrusion Detection System)** — passively monitors traffic, generates alerts on suspicious patterns
- **IPS (Intrusion Prevention System)** — actively monitors and can block/drop malicious traffic inline

| Type | Placement | Function |
|------|-----------|----------|
| NIDS/NIPS | Network tap or inline | Monitors all network traffic on a segment |
| HIDS/HIPS | On the host | Monitors host logs, file changes, syscalls |

- **Detection methods**:
  - Signature-based — matches known attack patterns (fast, misses zero-days)
  - Anomaly-based — baselines normal behavior, alerts on deviations (catches unknowns, more false positives)
  - Stateful protocol analysis — understands protocol state machines

- **Common tools**:
  - **Snort** — open-source NIDS/NIPS, signature-based, inline or passive
  - **Suricata** — multi-threaded alternative to Snort, supports IDS/IPS and NSM
  - **OSSEC** — open-source HIDS, log analysis, file integrity, rootkit detection
  - **Wazuh** — fork of OSSEC with extended features, central management, SIEM integration

Related notes: [008-linux-security-hardening](./008-linux-security-hardening.md)

### WAF (Web Application Firewall)

- Operates at **Layer 7** (HTTP/HTTPS) — inspects request content, not just headers/IPs
- Protects against OWASP Top 10: SQL injection, XSS, CSRF, path traversal, etc.
- Deployed as reverse proxy (inline), cloud service, or server module

```text
  Client ──► CDN/Edge ──► WAF ──► Load Balancer ──► Web Server
                          │
                     ┌────┴────────────┐
                     │ Inspects:       │
                     │  - HTTP headers │
                     │  - Request body │
                     │  - URL params   │
                     │  - Cookies      │
                     │                 │
                     │ Actions:        │
                     │  - Allow        │
                     │  - Block        │
                     │  - Rate limit   │
                     │  - Log          │
                     └─────────────────┘
```

- **Common WAF solutions**:
  - **ModSecurity** — open-source, runs as Apache/Nginx module; OWASP Core Rule Set (CRS)
  - **AWS WAF** — managed, integrates with CloudFront, ALB, API Gateway
  - **Cloudflare WAF** — cloud-based, bundled with CDN and DDoS protection
- WAF modes: detection only (log) vs. prevention (block)
- Must be tuned to reduce false positives — generic rules may block legitimate traffic

Related notes: [TLS and SSL cert chain](../Networking/006-TLS-and-SSL-cert-chain.md)

### DDoS Mitigation

- **DDoS (Distributed Denial of Service)** — overwhelms a target with traffic from many sources
- Three categories:

| Type | Layer | Examples | Mitigation |
|------|-------|----------|------------|
| Volumetric | L3/L4 | UDP flood, ICMP flood, DNS amplification | CDN absorption, scrubbing centers |
| Protocol | L3/L4 | SYN flood, Ping of Death, Smurf | SYN cookies, rate limiting, firewall |
| Application | L7 | HTTP flood, Slowloris, API abuse | WAF, rate limiting, CAPTCHA |

- **Mitigation strategies**:
  - **CDN / Anycast** — distribute traffic across global PoPs; absorb volumetric attacks (Cloudflare, AWS CloudFront)
  - **Scrubbing centers** — route traffic through cleaning facilities that filter malicious packets
  - **Rate limiting** — cap requests per IP/session at the load balancer or application level
  - **SYN cookies** — `net.ipv4.tcp_syncookies=1` handles SYN floods without exhausting connection table
  - **Blackhole routing** — last resort; drop all traffic to the target IP

```bash
# Basic rate limiting with iptables
sudo iptables -A INPUT -p tcp --dport 80 \
  -m connlimit --connlimit-above 50 -j DROP

# SYN flood protection (sysctl)
sudo sysctl -w net.ipv4.tcp_syncookies=1
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=4096
```

Related notes: [firewall-iptables-nftable](../Linux/Networking/006-firewall-iptables-nftable.md)

### Security Monitoring and SIEM

- **SIEM (Security Information and Event Management)** — collects, correlates, and analyzes logs from across the infrastructure
- Combines SIM (log storage/compliance) with SEM (real-time event monitoring/alerting)
- Core functions:
  - **Log aggregation** — centralize logs from servers, firewalls, IDS, applications
  - **Correlation** — detect attack patterns across multiple log sources (e.g., failed SSH + port scan + privilege escalation)
  - **Alerting** — notify SOC/on-call when correlation rules trigger
  - **Dashboards** — visualize security posture, trends, top threats
  - **Forensics** — search historical logs for incident investigation

```text
  Sources                     SIEM Pipeline                   Output
  ──────────────────         ─────────────────               ────────────
  Firewall logs    ──┐       ┌──────────────┐               Alerts
  IDS/IPS alerts   ──┼──────►│  Collect     │               Dashboards
  Auth logs        ──┤       │  Parse       │──────────►    Reports
  App logs         ──┤       │  Correlate   │               Forensics
  Cloud events     ──┘       │  Store       │               Compliance
                             └──────────────┘
```

- **Common SIEM / monitoring tools**:
  - **ELK Stack** (Elasticsearch + Logstash + Kibana) — open-source log aggregation and visualization
  - **Splunk** — commercial SIEM with powerful search (SPL) and dashboards
  - **Wazuh** — open-source security platform (HIDS + SIEM); integrates with ELK
  - **Graylog** — open-source log management with alerting

Related notes: [008-linux-security-hardening](./008-linux-security-hardening.md)

---

## Troubleshooting Flow (Quick)

```text
  Network security issue?
    │
    ├─ Suspected intrusion
    │    └─► check IDS alerts: snort/suricata logs
    │         └─► correlate with SIEM (timeline, source IP, target)
    │              └─► check host: ausearch, file integrity (AIDE)
    │                   └─► contain: isolate host, block IP at firewall
    │
    ├─ DDoS / high traffic
    │    └─► identify type: check traffic pattern (volumetric vs app-layer)
    │         ├─► volumetric → enable CDN/scrubbing, blackhole if needed
    │         └─► app-layer → WAF rules, rate limiting, CAPTCHA
    │
    ├─ Legitimate traffic blocked by WAF
    │    └─► check WAF logs for the blocking rule ID
    │         └─► whitelist the request pattern or tune the rule
    │              └─► test in detection-only mode before re-enabling
    │
    ├─ Lateral movement detected (east-west)
    │    └─► review network segmentation: are VLANs/firewalls in place?
    │         └─► check for flat network → implement microsegmentation
    │              └─► audit firewall rules between segments
    │
    └─ SIEM alert: correlation rule triggered
         └─► investigate source events across all log sources
              └─► determine true positive vs false positive
                   ├─► true positive → follow incident response plan
                   └─► false positive → tune correlation rule
```

## Quick Facts (Revision)

- Defense in depth layers: perimeter, network, host, application, data — each operates independently
- Zero trust: never trust, always verify; three pillars are verify explicitly, least privilege, assume breach
- North-south traffic crosses the perimeter; east-west traffic moves laterally inside the network
- IDS monitors and alerts; IPS monitors and blocks — both can be network-based or host-based
- WAF operates at Layer 7 and inspects HTTP content; protects against OWASP Top 10 attacks
- DDoS attacks target three layers: volumetric (L3/L4), protocol (L3/L4), application (L7)
- SIEM correlates logs from multiple sources to detect attack patterns that single-source monitoring misses
- Microsegmentation enforces security policy per-workload, not per-network-segment — essential for zero trust
