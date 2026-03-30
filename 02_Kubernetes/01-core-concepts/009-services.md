# Services

# Overview

- **Why it exists** — Pods are ephemeral and get new IP addresses every time they restart or are rescheduled. Clients cannot reliably connect to a moving target. A Service provides a stable DNS name and virtual IP that never changes, regardless of which pods are behind it.
- **What it is** — A stable network endpoint that load-balances traffic to a set of pods matching a label selector. The Service gets a ClusterIP (virtual IP) and a DNS name; kube-proxy maintains iptables rules on every node that redirect traffic from the ClusterIP to actual pod IPs. When pods come and go, kube-proxy updates the rules automatically.
- **One-liner** — A Service is a stable, named entry point that routes traffic to healthy pods via label selectors.

# Architecture

```text
ClusterIP (internal only)     NodePort (external via node)    LoadBalancer (cloud LB)
┌──────────────────────┐      ┌────────────────────────┐      ┌────────────────────────┐
│  Pod A               │      │  External client       │      │  Internet client       │
│    └──► ClusterIP ──►│      │    │                   │      │    │                  │
│         10.96.1.5    │      │    ▼                   │      │    ▼                  │
│         port 80      │      │  Node:30080            │      │  Cloud LB (public IP) │
│    load balances to: │      │    │                   │      │    │                  │
│    pod1:8080         │      │    ▼                   │      │    ▼                  │
│    pod2:8080         │      │  ClusterIP → pods      │      │  NodePort → ClusterIP │
└──────────────────────┘      └────────────────────────┘      └────────────────────────┘

Label Selector matching:
  Service selector: app=web
         │
         ├── pod1 (labels: app=web, version=v1) ✓ matched
         ├── pod2 (labels: app=web, version=v1) ✓ matched
         └── pod3 (labels: app=db)              ✗ not matched
```

# Mental Model

```text
DNS lookup: curl http://web-svc.default.svc.cluster.local/api
        │
        ▼
CoreDNS resolves to ClusterIP (e.g. 10.96.1.5)
        │
        ▼
kube-proxy iptables rule on this node intercepts packet
        │
        ▼
Randomly selects one of the healthy pod IPs from Endpoints
  (pods must pass readiness probe to be in Endpoints)
        │
        ▼
Packet forwarded to pod (e.g. 10.244.1.7:8080)
        │
        ▼
Response returns to caller
```

# Core Building Blocks

### Label Selector

- **Why it exists** — Services need to dynamically track which pods are currently running and healthy without being manually updated.
- **What it is** — A map of key-value pairs in `spec.selector`. Kubernetes watches for pods whose labels match all entries in the selector. The Endpoint controller maintains the Endpoints object with the IPs of matching, Ready pods. When pods are scaled, restarted, or fail readiness, Endpoints updates automatically.
- **One-liner** — The label selector is the glue between a Service and its backend pods.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  selector:
    app: web        # match pods with this label
  ports:
  - port: 80        # port the Service exposes
    targetPort: 8080  # port the container listens on
  type: ClusterIP
```

### Service Types

- **Why it exists** — Different workloads have different exposure requirements: some need only cluster-internal access, others need to be reachable from outside the cluster or from the internet.
- **What it is** — Four distinct Service variants (`ClusterIP`, `NodePort`, `LoadBalancer`, `ExternalName`) that control the scope and mechanism of traffic routing. Each higher-level type builds on the one before it.
- **One-liner** — Service types define who can reach a Service and how, from cluster-internal only up to full internet-facing load balancing.

| Type | Reachable from | Use case |
|------|---------------|----------|
| `ClusterIP` | Within cluster only | Internal microservice communication |
| `NodePort` | Outside cluster via `<nodeIP>:<nodePort>` | Dev/testing, simple external access |
| `LoadBalancer` | Internet (cloud) via external IP | Production external access on cloud |
| `ExternalName` | Within cluster | Alias to external DNS name |

- NodePort range: 30000–32767 (auto-assigned or specified)
- `LoadBalancer` builds on `NodePort` which builds on `ClusterIP` — each type is a superset
- `targetPort` is the container port; `port` is the Service port; they can differ

```yaml
# NodePort example
spec:
  type: NodePort
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080   # optional; auto-assigned if omitted

# LoadBalancer example (cloud)
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
```

### DNS Name Format

- **Why it exists** — Pods need to discover Services without knowing IP addresses; DNS provides a stable naming convention.
- **What it is** — CoreDNS (runs in `kube-system`) automatically creates DNS records for every Service. The full DNS name follows a predictable pattern. Shorter forms work within the same namespace.

```text
Full name:   <service-name>.<namespace>.svc.cluster.local
From same namespace: <service-name>
From different namespace: <service-name>.<namespace>
From outside cluster: not resolvable (use NodePort or LoadBalancer)
```

```bash
# Inside a pod — test DNS resolution
kubectl exec -it <pod> -- nslookup web-svc
kubectl exec -it <pod> -- curl http://web-svc/api
kubectl exec -it <pod> -- curl http://web-svc.production.svc.cluster.local/api

# Check CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

### Endpoints

- **Why it exists** — kube-proxy needs a list of current healthy pod IPs to write iptables rules.
- **What it is** — An automatically maintained object that tracks the IPs and ports of pods matching a Service's selector AND passing their readiness probe. kube-proxy watches Endpoints and updates node networking rules accordingly. You can inspect Endpoints to debug routing issues.
- **One-liner** — Endpoints is the live list of pod IPs that back a Service right now.

```bash
# Check which pods are backing a Service
kubectl get endpoints web-svc
kubectl describe endpoints web-svc

# If Endpoints is empty, traffic will fail — check:
kubectl get pods -l app=web   # are matching pods running?
kubectl describe pod <name>   # is readiness probe passing?
```

### Headless Services

- **Why it exists** — Some applications (StatefulSets, service discovery tools) need to get all pod IPs directly rather than through a virtual IP load balancer.
- **What it is** — A Service with `clusterIP: None`. No virtual IP is created. Instead, DNS returns individual A records for each matching pod IP. Used by StatefulSets so each pod gets a stable DNS name (`pod-0.svc.ns.svc.cluster.local`).
- **One-liner** — A headless Service returns raw pod IPs via DNS instead of routing through a virtual IP.

```yaml
spec:
  clusterIP: None   # headless
  selector:
    app: mysql
  ports:
  - port: 3306
```
