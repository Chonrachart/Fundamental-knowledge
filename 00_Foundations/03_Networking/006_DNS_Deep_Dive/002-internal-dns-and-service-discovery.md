# Internal DNS and Service Discovery

- Internal DNS enables service-to-service communication within private networks without relying on public DNS.
- Linux resolver configuration (/etc/resolv.conf, nsswitch.conf, systemd-resolved) controls how applications find nameservers and search domains.
- Kubernetes (CoreDNS), Consul, and split-horizon DNS are the primary patterns for internal service discovery in modern infrastructure.

# Architecture

```text
+---------------------------------------------------+
|                    Application                     |
|              getaddrinfo("my-service")             |
+-------------------------+-------------------------+
                          |
                          v
+---------------------------------------------------+
|              Name Service Switch                   |
|         /etc/nsswitch.conf                         |
|     hosts: files dns myhostname                    |
+--------+------------------+-----------------------+
         |                  |
         v                  v
+----------------+  +------------------+
| /etc/hosts     |  | DNS Resolver     |
| (static)       |  | /etc/resolv.conf |
+----------------+  +--------+---------+
                             |
              +--------------+--------------+
              |              |              |
              v              v              v
      +-----------+  +-----------+  +-----------+
      | Corporate |  | CoreDNS   |  | Consul    |
      | Resolver  |  | (K8s)     |  | DNS       |
      | (BIND,    |  | .cluster  |  | .consul   |
      |  Unbound) |  | .local    |  |           |
      +-----------+  +-----------+  +-----------+
```

# Mental Model

```text
How a Linux process resolves a name:

  [1] App calls getaddrinfo("redis-master")
       |
       v
  [2] glibc checks /etc/nsswitch.conf --> "hosts: files dns"
       |
       v
  [3] Check /etc/hosts first (files)
       +-- found --> return IP, done
       +-- not found --> continue
       |
       v
  [4] Check DNS (/etc/resolv.conf)
       - nameserver 10.96.0.10       (where to ask)
       - search default.svc.cluster.local svc.cluster.local cluster.local
       - options ndots:5
       |
       v
  [5] ndots check: does "redis-master" have >= 5 dots?
       +-- no (0 dots) --> append search domains first
       |    try: redis-master.default.svc.cluster.local
       |    try: redis-master.svc.cluster.local
       |    try: redis-master.cluster.local
       |    try: redis-master (absolute)
       +-- yes --> query as absolute name first
       |
       v
  [6] First successful response is returned to the application
```

```bash
# see what resolver config your system is using
cat /etc/resolv.conf
cat /etc/nsswitch.conf
```

# Core Building Blocks

### /etc/resolv.conf

- Configures the stub resolver: which nameservers to use, which search domains to append.
- Key directives: `nameserver`, `search`, `options`.
- In Kubernetes, this file is auto-generated per pod based on the pod's `dnsPolicy`.

```text
# typical /etc/resolv.conf
nameserver 10.96.0.10                    # CoreDNS service IP
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```

- `nameserver` -- up to 3 DNS servers (tried in order on failure).
- `search` -- domains appended to short names (up to 6, 256 chars total).
- `ndots:N` -- if the query name has fewer than N dots, search domains are tried first.
  - Kubernetes default is `ndots:5`, meaning almost all names get search domain expansion.
  - This generates extra DNS queries; for external names, use trailing dot (`google.com.`) or FQDN.

Related notes: [000-core](./000-core.md)

### /etc/hosts

- Static name-to-IP mapping, checked before DNS (by default).
- Order is controlled by `/etc/nsswitch.conf`: `hosts: files dns` means /etc/hosts first, then DNS.
- Useful for local overrides, development, and bootstrapping before DNS is available.

```text
# /etc/hosts
127.0.0.1       localhost
::1             localhost
10.0.1.50       db-primary.internal  db-primary
10.0.1.51       db-replica.internal  db-replica
```

- Changes take effect immediately (no cache to flush).
- Does not scale -- use DNS for anything beyond a handful of static entries.
- Kubernetes injects entries via `hostAliases` in pod spec.

Related notes: [000-core](./000-core.md)

### systemd-resolved

- Modern Linux DNS resolver daemon that replaces direct /etc/resolv.conf management.
- Provides caching, DNSSEC validation, and split DNS (per-link DNS configuration).
- /etc/resolv.conf typically becomes a symlink pointing to systemd-resolved's stub listener (127.0.0.53).

```bash
# check systemd-resolved status and per-interface DNS config
resolvectl status

# query a name through systemd-resolved
resolvectl query example.com

# show current DNS server and search domains per interface
resolvectl dns
resolvectl domain

# flush the systemd-resolved cache
resolvectl flush-caches

# show cache statistics
resolvectl statistics
```

- Split DNS: different DNS servers for different domains per network interface.
  - Corporate VPN interface: `*.corp.internal` -> corporate DNS.
  - Default interface: everything else -> public DNS.
- Configuration: `/etc/systemd/resolved.conf` or per-link via NetworkManager/systemd-networkd.

Related notes: [000-core](./000-core.md)

### CoreDNS (Kubernetes DNS)

- CoreDNS is the default DNS server in Kubernetes, deployed as a Deployment in kube-system.
- Resolves Kubernetes service and pod names to cluster IPs.
- Configuration is in a ConfigMap called `coredns` containing the Corefile.

```text
Corefile example:

.:53 {
    errors
    health {
        lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
        ttl 30
    }
    prometheus :9153
    forward . /etc/resolv.conf {
        max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
```

- Key plugins:
  - `kubernetes` -- resolves cluster DNS names (services, pods).
  - `forward` -- forwards non-cluster queries to upstream DNS.
  - `cache` -- caches responses (critical for performance).
  - `health` / `ready` -- liveness and readiness probes.
  - `prometheus` -- exposes metrics for monitoring.

Related notes: [001-record-types-in-depth](./001-record-types-in-depth.md)

### Kubernetes DNS Naming

- Kubernetes assigns DNS names to services, pods, and headless services automatically.
- The naming convention follows a strict hierarchy: `<name>.<namespace>.<type>.<zone>`.

```text
Service DNS:
  my-service.default.svc.cluster.local
  |          |       |   |
  |          |       |   +-- cluster domain
  |          |       +------ type (svc = service)
  |          +-------------- namespace
  +------------------------- service name

Pod DNS:
  10-244-1-5.default.pod.cluster.local
  |          |       |   |
  |          |       |   +-- cluster domain
  |          |       +------ type (pod)
  |          +-------------- namespace
  +------------------------- IP with dots replaced by dashes

Headless Service (clusterIP: None):
  my-pod.my-headless.default.svc.cluster.local
  |      |           |       |   |
  |      |           |       |   +-- cluster domain
  |      |           |       +------ type
  |      |           +-------------- namespace
  |      +-------------------------- headless service name
  +--------------------------------- pod hostname
```

- ClusterIP service: DNS resolves to the virtual cluster IP.
- Headless service (clusterIP: None): DNS resolves to individual pod IPs (A records for each pod).
- ExternalName service: creates a CNAME pointing to an external DNS name.

```bash
# from inside a pod -- resolve a service
dig my-service.default.svc.cluster.local

# short form works due to search domains
dig my-service            # same namespace
dig my-service.other-ns   # different namespace

# headless service returns individual pod IPs
dig my-headless.default.svc.cluster.local

# check ExternalName CNAME
dig my-external.default.svc.cluster.local
```

- Pod `dnsPolicy` options:
  - `ClusterFirst` (default) -- use CoreDNS, fall back to upstream.
  - `Default` -- use the node's DNS config.
  - `None` -- provide DNS config entirely via `dnsConfig` in pod spec.

Related notes: [001-record-types-in-depth](./001-record-types-in-depth.md)

### Consul DNS

- HashiCorp Consul provides service discovery via DNS interface on port 8600.
- Services registered with Consul are queryable under the `.consul` domain.
- Consul can act as a forwarding DNS or integrate with existing DNS via conditional forwarding.

```text
Consul DNS naming:

  <service>.service.consul          # any healthy instance
  <service>.service.<dc>.consul     # specific datacenter
  <tag>.<service>.service.consul    # filtered by tag
  <node>.node.consul                # node lookup
```

```bash
# query Consul DNS directly
dig @127.0.0.1 -p 8600 redis.service.consul

# query with datacenter
dig @127.0.0.1 -p 8600 redis.service.dc1.consul

# query with tag
dig @127.0.0.1 -p 8600 primary.redis.service.consul

# SRV record (includes port)
dig @127.0.0.1 -p 8600 redis.service.consul SRV
```

- Consul DNS returns only healthy instances (built-in health checking).
- Integration: configure BIND/Unbound/CoreDNS/systemd-resolved to forward `.consul` queries to Consul.

Related notes: [000-core](./000-core.md)

### Split-Horizon DNS
Related notes: [003-dns-management-and-operations](./003-dns-management-and-operations.md)
- Split-horizon (split-brain) DNS returns different answers for the same domain based on the source of the query.
- Internal clients get private IPs; external clients get public IPs.
- Common pattern for organizations hosting services accessible both internally and externally.
- Implementation methods:
  - BIND views: different zone data served based on source IP ACL.
  - Separate DNS servers: internal DNS server for internal zones, public DNS for external.
  - Cloud DNS: Route53 private hosted zones, GCP Cloud DNS private zones.
- Risk: misconfiguration can leak internal IPs externally or break internal resolution.

---

- /etc/nsswitch.conf `hosts: files dns` means /etc/hosts is checked before DNS.
- /etc/resolv.conf supports up to 3 nameservers and 6 search domains.
- `ndots:5` (Kubernetes default) means names with fewer than 5 dots get search domain expansion first.
- CoreDNS is the default Kubernetes DNS server; config lives in the `coredns` ConfigMap.
- Kubernetes service DNS: `<service>.<namespace>.svc.cluster.local`.
- Headless services (clusterIP: None) return individual pod IPs instead of a virtual IP.
- Consul DNS serves only healthy instances and is queryable on port 8600.
- Split-horizon DNS returns different answers based on query source -- internal vs external clients.
# Troubleshooting Guide

```text
Problem: service name not resolving inside Kubernetes
    |
    v
[1] Check /etc/resolv.conf in the pod
    cat /etc/resolv.conf
    |
    +-- nameserver not pointing to CoreDNS IP --> check dnsPolicy
    +-- search domains missing --> check dnsConfig
    |
    v
[2] Can the pod reach CoreDNS?
    dig @10.96.0.10 kubernetes.default.svc.cluster.local
    |
    +-- timeout --> CoreDNS pods down or network policy blocking
    |
    v
[3] Is the service/endpoint correct?
    kubectl get svc <name> -n <namespace>
    kubectl get endpoints <name> -n <namespace>
    |
    +-- no endpoints --> pods not ready or selector mismatch
    |
    v
[4] Check CoreDNS logs for errors
    kubectl -n kube-system logs -l k8s-app=kube-dns
    |
    +-- SERVFAIL / loop detected --> check Corefile, upstream config
    |
    v
[5] ndots issue? Try FQDN with trailing dot
    dig my-service.default.svc.cluster.local.
    +-- works with FQDN but not short name --> ndots or search domain issue
```
