# DNS and CoreDNS

## Overview
**Why it exists** — Pod IPs and even Service ClusterIPs can change; hardcoding IPs is fragile. CoreDNS provides in-cluster service discovery by name, so code only needs to know a stable DNS name.
**What it is** — CoreDNS is a flexible DNS server deployed as a Deployment in `kube-system`. It watches Kubernetes Services and Pods and serves DNS records for them. Every pod is automatically configured to use CoreDNS as its resolver.
**One-liner** — CoreDNS is the in-cluster DNS server that lets pods find Services by name instead of IP.

## Architecture (ASCII)

```text
Pod (any namespace)
  │
  │  resolv.conf: nameserver 10.96.0.10   ← CoreDNS Service IP
  │
  ▼
DNS query: "web.default.svc.cluster.local"
  │
  ▼
CoreDNS pod (kube-system)
  │
  ├── Kubernetes plugin: watches API server for Services/Pods
  │
  ▼
Returns A record: 10.96.45.23   ← ClusterIP of "web" Service
  │
  ▼
Pod connects to 10.96.45.23
```

## Mental Model

Every pod's `/etc/resolv.conf` has three things:
1. `nameserver <CoreDNS-ClusterIP>` — where to send DNS queries
2. `search <namespace>.svc.cluster.local svc.cluster.local cluster.local` — suffix list for short names
3. `options ndots:5` — a name with fewer than 5 dots triggers a search before a final lookup

This means a pod in the `default` namespace can reach the `web` service with any of these names:
- `web` (short — search domains expand it)
- `web.default`
- `web.default.svc`
- `web.default.svc.cluster.local` (FQDN)

Names from other namespaces need at least `<svc>.<namespace>` to be unambiguous.

## Core Building Blocks

### DNS Name Formats

| Resource | Format | Example |
|----------|--------|---------|
| Service | `<svc>.<namespace>.svc.cluster.local` | `web.default.svc.cluster.local` |
| Headless pod (via StatefulSet) | `<pod>.<svc>.<namespace>.svc.cluster.local` | `mysql-0.mysql.default.svc.cluster.local` |
| Pod (by IP, dashes) | `<ip-dashes>.<namespace>.pod.cluster.local` | `10-244-1-5.default.pod.cluster.local` |

```bash
# Resolve a service by short name from inside a pod (same namespace)
kubectl exec -it <pod> -- nslookup web

# Resolve cross-namespace
kubectl exec -it <pod> -- nslookup web.other-namespace

# Resolve the full FQDN
kubectl exec -it <pod> -- nslookup web.default.svc.cluster.local

# Check what's in resolv.conf inside a pod
kubectl exec -it <pod> -- cat /etc/resolv.conf
```

### CoreDNS Deployment
**Why it exists** — Must run as a highly-available service so pod DNS never fails.
**What it is** — CoreDNS runs as a Deployment (typically 2 replicas) in `kube-system`, fronted by a Service with a stable ClusterIP that kubeadm hard-codes into kubelet's `--cluster-dns` flag.
**One-liner** — The DNS server pods behind the `kube-dns` Service in `kube-system`.

```bash
# Check CoreDNS pods
kubectl -n kube-system get pods -l k8s-app=kube-dns

# Check CoreDNS Service (this IP appears in pod resolv.conf)
kubectl -n kube-system get svc kube-dns

# Check CoreDNS logs for query errors
kubectl -n kube-system logs -l k8s-app=kube-dns
```

### CoreDNS ConfigMap
**Why it exists** — CoreDNS behavior (forwarding, rewriting, custom zones) is driven by its Corefile config; the ConfigMap makes it editable without rebuilding the image.
**What it is** — A ConfigMap in `kube-system` named `coredns` containing the `Corefile`. Common customizations: forward to custom upstream resolvers, stub zones for split-horizon DNS, rewrite rules.
**One-liner** — The Corefile in this ConfigMap is what CoreDNS loads for its full configuration.

```bash
# View CoreDNS config
kubectl -n kube-system get configmap coredns -o yaml

# Edit CoreDNS config (changes take effect after pods restart)
kubectl -n kube-system edit configmap coredns

# Force CoreDNS to reload after ConfigMap change
kubectl -n kube-system rollout restart deployment coredns
```

Example Corefile (default kubeadm):
```
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

### Search Domains and ndots
**Why it exists** — Short names (`web` instead of `web.default.svc.cluster.local`) reduce boilerplate in config; search domains make short names resolve correctly.
**What it is** — The `search` line in `/etc/resolv.conf` lists suffixes to append when a name doesn't have enough dots. `ndots:5` means any name with fewer than 5 dots is tried with search domains first before being sent as-is.
**One-liner** — Search domains are why `curl web` works inside the same namespace without a full FQDN.

```bash
# Verify search domains in a pod
kubectl exec <pod> -- cat /etc/resolv.conf
# Expected output:
# nameserver 10.96.0.10
# search default.svc.cluster.local svc.cluster.local cluster.local
# options ndots:5
```

## Troubleshooting

### DNS resolution fails inside pod
1. Check CoreDNS pods are running: `kubectl -n kube-system get pods -l k8s-app=kube-dns`.
2. Check pod's resolv.conf: `kubectl exec <pod> -- cat /etc/resolv.conf` — nameserver should be CoreDNS ClusterIP.
3. Run a test: `kubectl exec <pod> -- nslookup kubernetes.default` — this always exists if CoreDNS works.
4. Check CoreDNS logs: `kubectl -n kube-system logs -l k8s-app=kube-dns`.

### Pod resolves service in same namespace but not another namespace
1. Use the two-part name: `<svc>.<namespace>` or full FQDN.
2. Check the target Service exists: `kubectl get svc -n <other-namespace>`.

### Slow DNS / high latency on first request
1. ndots:5 causes multiple search domain lookups before the absolute lookup — this is expected for external names.
2. Mitigation: append a trailing dot to FQDNs (`google.com.`) to skip search domains, or reduce `ndots` in pod's `dnsConfig`.

```yaml
# Pod spec: custom DNS options to reduce search overhead
spec:
  dnsConfig:
    options:
    - name: ndots
      value: "2"
```
