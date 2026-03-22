# DNS Record Types In Depth

- DNS record types define what kind of data a domain name maps to -- IP addresses, mail servers, aliases, metadata, and more.
- Each record type has specific rules and constraints that, if violated, cause subtle breakages (CNAME at apex, MX pointing to CNAME).
- Choosing the correct record type is a daily operational decision for managing infrastructure, email, certificates, and service discovery.

# Architecture

```text
Zone file for example.com:

+-------------------------------------------------------------------+
| example.com.  SOA   ns1.example.com. admin.example.com. (         |
|                     2024031601 3600 900 604800 86400 )             |
+-------------------------------------------------------------------+
| example.com.  NS    ns1.example.com.                              |
| example.com.  NS    ns2.example.com.                              |
+-------------------------------------------------------------------+
| example.com.  A     93.184.216.34                                 |
| example.com.  AAAA  2606:2800:220:1:248:1893:25c8:1946            |
+-------------------------------------------------------------------+
| www            CNAME  example.com.                                 |
+-------------------------------------------------------------------+
| example.com.  MX    10 mail1.example.com.                         |
| example.com.  MX    20 mail2.example.com.                         |
+-------------------------------------------------------------------+
| example.com.  TXT   "v=spf1 include:_spf.google.com ~all"        |
+-------------------------------------------------------------------+
| example.com.  CAA   0 issue "letsencrypt.org"                     |
+-------------------------------------------------------------------+
| _sip._tcp      SRV   10 60 5060 sip.example.com.                 |
+-------------------------------------------------------------------+
| 34.216.184.93.in-addr.arpa.  PTR  example.com.                    |
+-------------------------------------------------------------------+
```

# Mental Model

```text
"Which record type do I need?"

  Want to point a name to an IP?
    |
    +-- IPv4 --> A record
    +-- IPv6 --> AAAA record
    |
  Want to alias one name to another?
    |
    +-- Not zone apex --> CNAME
    +-- Zone apex     --> use A/AAAA (or ALIAS/ANAME if provider supports)
    |
  Want to route email?
    |
    +-- MX record (with priority)
    |
  Want to prove domain ownership or configure email security?
    |
    +-- TXT record (SPF, DKIM, DMARC, verification)
    |
  Want to delegate a subdomain?
    |
    +-- NS record (+ glue A records if in same zone)
    |
  Want to enable service discovery?
    |
    +-- SRV record (_service._proto.name)
    |
  Want reverse lookup (IP -> name)?
    |
    +-- PTR record
    |
  Want to restrict which CAs issue certs?
    |
    +-- CAA record
```

```bash
# query specific record types
dig example.com A
dig example.com AAAA
dig example.com MX
dig example.com TXT
dig example.com NS
dig example.com SOA
dig example.com CAA
dig _sip._tcp.example.com SRV
dig -x 93.184.216.34    # PTR (reverse)
```

# Core Building Blocks

### A and AAAA Records

- A record maps a name to an IPv4 address; AAAA maps to an IPv6 address.
- Multiple A records on the same name enable DNS round-robin load distribution.
- Most fundamental record type -- nearly every domain has at least one A record.

```text
example.com.   300  IN  A     93.184.216.34
example.com.   300  IN  A     93.184.216.35     # round-robin
example.com.   300  IN  AAAA  2606:2800:220:1:248:1893:25c8:1946
```

- Round-robin is not true load balancing -- no health checks, no session persistence.
- Clients may cache and reuse a single IP; behavior varies by resolver and application.

Related notes: [000-core](./000-core.md)

### CNAME (Canonical Name)

- CNAME creates an alias: one name points to another name (not an IP).
- A CNAME **cannot coexist** with any other record type at the same name (RFC 1034).
- A CNAME **cannot be used at the zone apex** (e.g., example.com) -- only on subdomains.

```text
www.example.com.    300  IN  CNAME  example.com.
# OK: www is a subdomain

example.com.        300  IN  CNAME  other.com.
# WRONG: zone apex cannot be CNAME (breaks NS, SOA, MX at apex)
```

- Cloud providers offer proprietary alternatives for apex aliasing: Route53 ALIAS, Cloudflare CNAME flattening, GCP synthetic records.
- CNAME chains (A -> CNAME -> CNAME -> A) add latency; keep chains short.

Related notes: [003-dns-management-and-operations](./003-dns-management-and-operations.md)

### MX (Mail Exchange)

- MX records direct email to mail servers for a domain.
- Priority value: **lower number = higher priority** (10 is preferred over 20).
- MX targets **must point to A/AAAA records**, never to a CNAME (RFC 2181).

```text
example.com.  300  IN  MX  10  mail1.example.com.
example.com.  300  IN  MX  20  mail2.example.com.
example.com.  300  IN  MX  30  mail3.example.com.
```

- If priority-10 server is down, sending servers try priority-20, then priority-30.
- Same priority = random selection (load distribution among equal-priority servers).

Related notes: [000-core](./000-core.md)

### TXT Records

- TXT records store arbitrary text data associated with a domain name.
- Primary uses: email authentication (SPF, DKIM, DMARC), domain verification, and metadata.

```text
# SPF -- which servers can send email for this domain
example.com.  IN  TXT  "v=spf1 include:_spf.google.com ~all"

# DKIM -- public key for email signature verification
selector._domainkey.example.com.  IN  TXT  "v=DKIM1; k=rsa; p=MIGf..."

# DMARC -- policy for handling SPF/DKIM failures
_dmarc.example.com.  IN  TXT  "v=DMARC1; p=reject; rua=mailto:dmarc@example.com"

# Domain verification (Google, Let's Encrypt, etc.)
example.com.  IN  TXT  "google-site-verification=abc123..."
_acme-challenge.example.com.  IN  TXT  "xyz789..."
```

- Multiple TXT records can exist for the same name.
- TXT records are limited to 255 bytes per string; longer values use multiple strings concatenated.

Related notes: [003-dns-management-and-operations](./003-dns-management-and-operations.md)

### NS (Nameserver) Records

- NS records delegate authority for a zone to specific nameservers.
- Every zone must have at least two NS records for redundancy.
- Glue records: when the NS target is within the same zone, the parent zone must provide A records (glue) to avoid circular dependency.

```text
example.com.      IN  NS  ns1.example.com.
example.com.      IN  NS  ns2.example.com.

# Glue records (in the .com TLD zone):
ns1.example.com.  IN  A   198.51.100.1
ns2.example.com.  IN  A   198.51.100.2
```

- Subdomain delegation: create NS records for a subdomain to point to different nameservers.

```text
# Delegate dev.example.com to different nameservers
dev.example.com.  IN  NS  ns1.dev-infra.com.
dev.example.com.  IN  NS  ns2.dev-infra.com.
```

Related notes: [003-dns-management-and-operations](./003-dns-management-and-operations.md)

### SOA (Start of Authority)

- SOA record defines the zone's primary nameserver, admin contact, and timing parameters.
- Every zone has exactly one SOA record.
- Serial number must be incremented on every zone change (triggers zone transfers to secondaries).

```text
example.com.  IN  SOA  ns1.example.com. admin.example.com. (
    2024031601  ; serial  (convention: YYYYMMDDnn)
    3600        ; refresh (seconds between secondary checks)
    900         ; retry   (seconds between retry if refresh fails)
    604800      ; expire  (seconds before secondary stops serving)
    86400       ; minimum TTL (negative caching TTL)
)
```

- Serial format `YYYYMMDDnn` allows up to 100 changes per day (nn = 00-99).
- If serial is not incremented, secondary servers will not pull the updated zone.

Related notes: [003-dns-management-and-operations](./003-dns-management-and-operations.md)

### SRV (Service) Records

- SRV records enable service discovery by specifying host and port for a service.
- Format: `_service._proto.name TTL IN SRV priority weight port target`
- Used by Kubernetes, SIP, XMPP, LDAP, and other protocols that need dynamic service location.

```text
_sip._tcp.example.com.    IN  SRV  10 60 5060 sip1.example.com.
_sip._tcp.example.com.    IN  SRV  10 40 5060 sip2.example.com.
_http._tcp.example.com.   IN  SRV  0  0  80   web.example.com.
```

- Priority: lower = preferred (same as MX).
- Weight: for load distribution among same-priority records (higher weight = more traffic).
- Kubernetes uses SRV records for headless services to expose individual pod IPs and ports.

Related notes: [002-internal-dns-and-service-discovery](./002-internal-dns-and-service-discovery.md)

### PTR (Pointer) Records

- PTR records map IP addresses back to hostnames (reverse DNS).
- Stored in special zones: `in-addr.arpa` (IPv4) and `ip6.arpa` (IPv6).
- The IP address octets are reversed in the record name.

```text
# Forward: example.com -> 93.184.216.34
example.com.  IN  A  93.184.216.34

# Reverse: 93.184.216.34 -> example.com
34.216.184.93.in-addr.arpa.  IN  PTR  example.com.
```

- Critical for email deliverability: many mail servers reject email from IPs without valid PTR records.
- PTR records are managed by the IP address owner (usually the ISP or hosting provider), not the domain owner.

Related notes: [000-core](./000-core.md)

### CAA (Certificate Authority Authorization)

- CAA records specify which Certificate Authorities are allowed to issue certificates for a domain.
- CAs are required to check CAA records before issuing (RFC 8659).
- Prevents unauthorized certificate issuance (defense-in-depth alongside Certificate Transparency).

```text
example.com.  IN  CAA  0 issue     "letsencrypt.org"
example.com.  IN  CAA  0 issuewild "letsencrypt.org"
example.com.  IN  CAA  0 iodef     "mailto:security@example.com"
```

- `issue` -- which CAs can issue regular certificates.
- `issuewild` -- which CAs can issue wildcard certificates.
- `iodef` -- where to report policy violations.
- If no CAA records exist, any CA can issue certificates for the domain.

Related notes: [003-dns-management-and-operations](./003-dns-management-and-operations.md)

### Record Type Decision Table

```text
+----------+-------------------------+--------------------------------------+
| Type     | Use When                | Key Constraints                      |
+----------+-------------------------+--------------------------------------+
| A        | Name -> IPv4 address    | Multiple allowed (round-robin)       |
| AAAA     | Name -> IPv6 address    | Same as A but for IPv6               |
| CNAME    | Alias to another name   | Not at apex, no other records        |
| MX       | Mail routing            | Target must be A/AAAA, not CNAME     |
| TXT      | Email auth, verification| 255 byte string limit, concat ok     |
| NS       | Zone delegation         | Need glue if NS in same zone         |
| SOA      | Zone authority          | Exactly one per zone                 |
| SRV      | Service discovery       | _service._proto.name format          |
| PTR      | Reverse DNS (IP->name)  | Managed by IP owner, not domain owner|
| CAA      | Restrict CA issuance    | No CAA = any CA allowed              |
+----------+-------------------------+--------------------------------------+
```

---

# Practical Command Set (Core)

```bash
# query all common record types for a domain
for type in A AAAA CNAME MX TXT NS SOA CAA; do
  echo "--- $type ---"
  dig +short example.com $type
done

# check MX records and verify targets resolve
dig +short example.com MX
dig +short mail1.example.com A

# check SPF record
dig +short example.com TXT | grep spf

# check DMARC policy
dig +short _dmarc.example.com TXT

# check DKIM record
dig +short selector._domainkey.example.com TXT

# reverse DNS lookup
dig -x 93.184.216.34

# check CAA records
dig example.com CAA

# check SRV records
dig _http._tcp.example.com SRV
```


- A = IPv4, AAAA = IPv6; multiple A records = DNS round-robin (no health checks).
- CNAME cannot coexist with other records at the same name and cannot be at zone apex.
- MX priority: lower number = higher priority; targets must be A/AAAA, never CNAME.
- TXT records store SPF, DKIM, DMARC, domain verification, and arbitrary metadata.
- SOA serial must be incremented on every zone change or secondaries will not update.
- PTR records (reverse DNS) are managed by the IP owner, critical for email deliverability.
- CAA records restrict which CAs can issue certificates; no CAA = any CA allowed.
- SRV records use `_service._proto.name` format; used by Kubernetes for service discovery.
# Troubleshooting Guide

```text
Problem: email not being delivered
    |
    v
[1] Check MX records exist
    dig +short example.com MX
    |
    +-- no MX records --> add MX records
    |
    v
[2] Verify MX targets resolve to A/AAAA (not CNAME)
    dig +short mail1.example.com A
    |
    +-- CNAME returned --> MX must point to A/AAAA directly
    |
    v
[3] Check SPF record
    dig +short example.com TXT | grep spf
    |
    +-- missing or wrong --> fix SPF to include sending servers
    |
    v
[4] Check reverse DNS (PTR) for sending IP
    dig -x <sending-ip>
    |
    +-- no PTR or mismatched --> contact IP owner to set PTR
    |
    v
[5] Check DMARC policy
    dig +short _dmarc.example.com TXT
    |
    +-- p=reject with failing checks --> align SPF/DKIM or relax policy
```
