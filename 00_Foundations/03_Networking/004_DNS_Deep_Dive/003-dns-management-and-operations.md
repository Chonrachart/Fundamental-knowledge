# DNS Management and Operations

- DNS operations encompass zone management, TTL strategy, cloud DNS services, certificate automation, and DNSSEC.
- TTL is the single most important operational lever -- it controls propagation speed, query volume, and migration risk.
- DNS migrations require a disciplined process: lower TTL, change records, verify, raise TTL.

# Architecture

```text
DNS Operations Landscape:

+-----------------------------------------------------------------------+
|                         Zone Management                               |
|  +------------------+  +-------------------+  +--------------------+  |
|  | Zone Files       |  | Zone Transfers    |  | Cloud DNS          |  |
|  | (BIND, NSD)      |  | AXFR (full)       |  | (Route53, Cloud   |  |
|  | SOA, serial,     |  | IXFR (incremental)|  |  DNS, Azure DNS)  |  |
|  | records          |  | primary->secondary|  | API-managed zones  |  |
|  +------------------+  +-------------------+  +--------------------+  |
+-----------------------------------------------------------------------+
           |                      |                       |
           v                      v                       v
+-----------------------------------------------------------------------+
|                        Operational Tasks                              |
|  +-----------+  +-----------+  +-----------+  +--------------------+  |
|  | TTL       |  | Migration |  | DNSSEC    |  | Certificate        |  |
|  | Strategy  |  | Planning  |  | Signing   |  | Automation         |  |
|  |           |  |           |  |           |  | (DNS-01 / ACME)    |  |
|  +-----------+  +-----------+  +-----------+  +--------------------+  |
+-----------------------------------------------------------------------+
           |                      |                       |
           v                      v                       v
+-----------------------------------------------------------------------+
|                       Troubleshooting                                 |
|  dig +trace  |  propagation check  |  cache flush  |  DNSSEC debug   |
+-----------------------------------------------------------------------+
```

# Mental Model

```text
DNS Migration Process:

  [1] Current state: app.example.com -> 10.0.1.100 (TTL 86400 = 24h)
       |
       v
  [2] Lower TTL well in advance (wait for old TTL to expire)
       app.example.com  300  A  10.0.1.100    # TTL now 5 min
       Wait 24 hours (old TTL) for all caches to pick up new TTL
       |
       v
  [3] Change the record to new IP
       app.example.com  300  A  10.0.2.200    # new server
       |
       v
  [4] Verify from multiple locations
       dig @8.8.8.8 app.example.com
       dig @1.1.1.1 app.example.com
       # check from different geographic regions
       |
       v
  [5] Monitor: keep old server running for stragglers
       Wait at least 2x the lowered TTL
       |
       v
  [6] Raise TTL back to production value
       app.example.com  86400  A  10.0.2.200  # TTL back to 24h
       |
       v
  [7] Decommission old server
```

```bash
# check current TTL for a record
dig +nocmd +noall +answer app.example.com
```

# Core Building Blocks

### Zone Management

- A DNS zone is a portion of the DNS namespace managed by a specific organization or administrator.
- Zone files are the traditional format for storing DNS records (used by BIND, NSD, Knot).
- Zone transfers replicate zone data from primary to secondary nameservers.

```text
Zone file format:

$ORIGIN example.com.
$TTL 86400

@   IN  SOA  ns1.example.com. admin.example.com. (
        2024031601  ; serial
        3600        ; refresh
        900         ; retry
        604800      ; expire
        86400       ; minimum TTL
)

; Nameservers
        IN  NS   ns1.example.com.
        IN  NS   ns2.example.com.

; A records
        IN  A    93.184.216.34
www     IN  CNAME  example.com.

; Mail
        IN  MX   10  mail.example.com.
mail    IN  A    93.184.216.40
```

- **AXFR** (full zone transfer): secondary pulls the entire zone from primary.
- **IXFR** (incremental zone transfer): secondary pulls only changes since last serial.
- Zone transfers should be restricted by IP (allow-transfer ACL) to prevent zone enumeration.

```bash
# test zone transfer (if allowed)
dig @ns1.example.com example.com AXFR

# check SOA serial
dig +short example.com SOA
```

Related notes: [001-record-types-in-depth](./001-record-types-in-depth.md)

### TTL Strategy

- TTL (Time To Live) controls how long resolvers cache a DNS record before re-querying.
- TTL is a tradeoff: high TTL = fewer queries + slower propagation; low TTL = more queries + faster propagation.
- TTL decisions should be intentional, not default.

```text
TTL Guidelines:

+---------------------+----------+------------------------------------------+
| Scenario            | TTL      | Reasoning                                |
+---------------------+----------+------------------------------------------+
| Stable production   | 3600-    | Low query volume, records rarely change  |
| records             | 86400    |                                          |
+---------------------+----------+------------------------------------------+
| Before migration    | 60-300   | Need fast propagation when change happens|
+---------------------+----------+------------------------------------------+
| Load-balanced /     | 60-300   | Need clients to pick up changes quickly  |
| failover records    |          |                                          |
+---------------------+----------+------------------------------------------+
| ACME DNS-01         | 60       | Challenge records need fast propagation  |
| challenge records   |          |                                          |
+---------------------+----------+------------------------------------------+
| NS and SOA records  | 86400-   | Delegation changes are rare              |
|                     | 172800   |                                          |
+---------------------+----------+------------------------------------------+
```

- Always lower TTL **before** a planned change, not at the same time.
- Wait at least the old TTL duration after lowering before making the actual change.
- Some resolvers ignore very low TTLs (below 30s) or enforce minimum caching.

Related notes: [000-core](./000-core.md)

### Cloud DNS Services

- Managed DNS services eliminate the need to run your own nameservers.
- All major clouds provide authoritative DNS with API/IaC management and advanced routing.

```text
AWS Route53:
  - Hosted zones (public and private)
  - Routing policies: simple, weighted, latency, geolocation, failover, multivalue
  - Health checks: integrated with routing (auto-failover)
  - Alias records: Route53-specific, works at zone apex (points to ALB, CloudFront, S3, etc.)
  - Cost: per hosted zone + per million queries

GCP Cloud DNS:
  - Managed zones (public and private)
  - Routing policies: weighted round-robin, geolocation
  - DNSSEC support (managed signing)
  - Integration with GKE and Cloud CDN

Azure DNS:
  - DNS zones (public and private)
  - Alias record sets (similar to Route53 aliases)
  - Integration with Azure Traffic Manager for routing policies
  - Private DNS zones for VNet name resolution
```

```bash
# Route53: list hosted zones
aws route53 list-hosted-zones

# Route53: list records in a zone
aws route53 list-resource-record-sets --hosted-zone-id Z1234567890

# Route53: create/update a record (change batch)
aws route53 change-resource-record-sets --hosted-zone-id Z1234567890 \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "app.example.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "10.0.2.200"}]
      }
    }]
  }'

# GCP: list managed zones
gcloud dns managed-zones list

# GCP: list records
gcloud dns record-sets list --zone=my-zone
```

Related notes: [000-core](./000-core.md)

### Let's Encrypt and DNS-01 Challenge

- DNS-01 is an ACME challenge type where you prove domain ownership by creating a TXT record.
- Required for wildcard certificates (*.example.com) -- HTTP-01 cannot do wildcards.
- Automation requires DNS API access (Route53, Cloud DNS, Cloudflare, etc.).

```text
DNS-01 Challenge Flow:

  [1] Request certificate for *.example.com from Let's Encrypt
       |
       v
  [2] ACME server says: "create TXT record at
       _acme-challenge.example.com with value abc123xyz"
       |
       v
  [3] Certbot/cert-manager creates the TXT record via DNS API
       _acme-challenge.example.com.  60  IN  TXT  "abc123xyz"
       |
       v
  [4] ACME server queries the TXT record and verifies
       |
       v
  [5] Certificate issued; TXT record can be cleaned up
```

```bash
# certbot with Route53 DNS-01
certbot certonly \
  --dns-route53 \
  -d "*.example.com" \
  -d "example.com"

# certbot with Cloudflare DNS-01
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
  -d "*.example.com"

# verify the challenge record was created
dig +short _acme-challenge.example.com TXT
```

- Kubernetes cert-manager automates this end-to-end with DNS01 solver configuration.
- Keep TTL low (60s) on `_acme-challenge` records for fast propagation during challenges.

Related notes: [001-record-types-in-depth](./001-record-types-in-depth.md)

### DNSSEC

- DNSSEC adds cryptographic signatures to DNS records, enabling resolvers to verify authenticity.
- Prevents DNS spoofing and cache poisoning by establishing a chain of trust from root to domain.
- Operationally complex: requires key management, signing, and careful rollover procedures.

```text
DNSSEC Chain of Trust:

  Root Zone (.)
    |  signs .com DS record
    v
  TLD (.com)
    |  signs example.com DS record
    v
  example.com (authoritative)
    |  signs all records with zone signing key (ZSK)
    v
  Resolver validates signatures up the chain

Key types:
  KSK (Key Signing Key) -- signs the DNSKEY RRset, published as DS in parent
  ZSK (Zone Signing Key) -- signs all other records in the zone
```

- Managed DNSSEC (Route53, Cloud DNS) handles key generation, signing, and rotation automatically.
- Self-managed DNSSEC: must handle key generation, zone signing, DS record updates, and key rollovers.
- Risk: misconfigured DNSSEC (expired signatures, missing DS records) causes resolution failure -- worse than no DNSSEC.

```bash
# check if a domain has DNSSEC
dig +dnssec example.com

# validate DNSSEC chain
drill -S example.com
# or
delv example.com

# check DS record at parent
dig +short example.com DS
```

Related notes: [000-core](./000-core.md)

### DNS Migration

- DNS migrations require careful planning because DNS is cached and propagation is not instant.
- The migration process is the same whether changing IPs, providers, or nameservers.

```text
Migration Checklist:

  [ ] Inventory all DNS records (export zone)
  [ ] Lower TTLs on affected records (wait old TTL duration)
  [ ] Prepare new records at destination
  [ ] Make the switch (change records or NS delegation)
  [ ] Verify from multiple resolvers and locations
  [ ] Monitor error rates and logs
  [ ] Keep old infrastructure running during transition
  [ ] Raise TTLs back to production values
  [ ] Decommission old infrastructure after full propagation
```

- NS migration (changing DNS providers) is higher risk: both old and new providers must serve correct records during the transition.
- Tools for checking propagation: `dig @<specific-resolver>`, online tools (whatsmydns.net), monitoring.

Related notes: [000-core](./000-core.md)

### Troubleshooting DNS
Related notes: [002-internal-dns-and-service-discovery](./002-internal-dns-and-service-discovery.md)
- DNS issues manifest as resolution failures, slow lookups, stale records, or SERVFAIL responses.
- `dig +trace` is the single most useful command for DNS debugging.
- Common issues:
  - **NXDOMAIN**: record does not exist (check spelling, zone, delegation).
  - **SERVFAIL**: server failed to answer (DNSSEC failure, upstream unreachable, misconfigured zone).
  - **Stale records**: old TTL has not expired yet (wait or flush cache).
  - **Split-horizon mismatch**: querying from wrong network gets wrong answer.

---

# Practical Command Set (Core)

```bash
# trace resolution path
dig +trace example.com

# check record with full details (TTL, flags, authority)
dig example.com

# query against specific resolvers
dig @8.8.8.8 example.com
dig @1.1.1.1 example.com

# check SOA serial (verify zone update)
dig +short example.com SOA

# test zone transfer
dig @ns1.example.com example.com AXFR

# check DNSSEC
dig +dnssec example.com
drill -S example.com

# Route53: update a record
aws route53 change-resource-record-sets --hosted-zone-id ZXXXXX \
  --change-batch file://change-batch.json

# certbot DNS-01 wildcard
certbot certonly --dns-route53 -d "*.example.com" -d "example.com"

# check propagation from multiple angles
for ns in 8.8.8.8 1.1.1.1 9.9.9.9; do
  echo "=== $ns ==="
  dig @$ns +short example.com
done
```


- SOA serial must increment on every zone change; convention is YYYYMMDDnn.
- AXFR = full zone transfer; IXFR = incremental; restrict both by source IP.
- Lower TTL before migration, wait for old TTL to expire, then make the change.
- Route53 Alias records work at zone apex and do not charge per query for AWS resources.
- DNS-01 challenge is required for wildcard certificates; needs DNS API access for automation.
- DNSSEC adds authentication but not encryption; misconfigured DNSSEC is worse than no DNSSEC.
- `dig +trace` is the most important DNS troubleshooting command.
- DNS propagation is not instant -- it is bounded by TTL values across all caching layers.
# Troubleshooting Guide

```text
Problem: DNS record change not taking effect
    |
    v
[1] Was the zone updated correctly?
    dig @<authoritative-ns> example.com
    |
    +-- old answer --> zone not updated, check SOA serial, check zone file/API
    +-- new answer --> change is live at authoritative, continue
    |
    v
[2] Is it a caching issue?
    dig example.com (note TTL -- is it decrementing?)
    |
    +-- high TTL remaining --> wait for TTL expiry
    +-- try: flush local cache (resolvectl flush-caches)
    |
    v
[3] Is it a specific resolver caching the old record?
    dig @8.8.8.8 example.com
    dig @1.1.1.1 example.com
    |
    +-- some resolvers show old, some show new --> propagation in progress, wait
    +-- all public resolvers show new, local does not --> local resolver/cache issue
    |
    v
[4] DNSSEC issue?
    dig +dnssec +cd example.com
    |
    +-- works with +cd --> DNSSEC signatures invalid, check signing
    |
    v
[5] NS delegation issue? (if changing providers)
    dig +trace example.com
    |
    +-- delegation still points to old NS --> update NS at registrar
```
