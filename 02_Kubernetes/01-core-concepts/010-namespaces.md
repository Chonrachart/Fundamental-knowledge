# Namespaces

# Overview

- **Why it exists** — In a shared cluster, different teams and environments (dev, staging, prod) need isolation: their own resource quotas, their own access controls, and the ability to reuse names without collision.
- **What it is** — A virtual cluster within a Kubernetes cluster. Namespaces partition resources (pods, services, configmaps, etc.) into isolated groups. Most Kubernetes objects are namespace-scoped; a few (nodes, PersistentVolumes, ClusterRoles) are cluster-scoped and not confined to any namespace.
- **One-liner** — Namespaces are virtual clusters for team and environment isolation within a single Kubernetes cluster.

# Architecture

```text
Kubernetes Cluster
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │   default    │  │  production  │  │ team-backend  │  │
│  │              │  │              │  │               │  │
│  │  pod: app    │  │  pod: app    │  │  pod: api     │  │
│  │  svc: web    │  │  svc: web    │  │  svc: api     │  │
│  │  cm: config  │  │  cm: config  │  │  cm: config   │  │
│  └──────────────┘  └──────────────┘  └───────────────┘  │
│                                                          │
│  Cluster-scoped (no namespace):                          │
│    Nodes, PersistentVolumes, ClusterRoles, Namespaces    │
│                                                          │
└──────────────────────────────────────────────────────────┘

Same name, different namespace = different objects:
  web (default) ≠ web (production)
```

# Mental Model

```text
Think of namespaces like folders in a filesystem:
  /default/pods/myapp
  /production/pods/myapp
  /staging/pods/myapp

Each namespace has:
  - Its own set of objects (pods, services, secrets, etc.)
  - Its own ResourceQuota (optional CPU/memory limits)
  - Its own RBAC scope (roles apply within namespace)
  - Its own DNS subdomain (svc.namespace.svc.cluster.local)

Objects in the same namespace can reference each other by short name.
Objects in different namespaces need the full DNS name or cross-namespace references.
```

# Core Building Blocks

### Default Namespaces

- **Why it exists** — Kubernetes pre-creates namespaces for its own operation and provides a default workspace for user objects.
- **What it is** — Four namespaces exist in every cluster out of the box:

| Namespace | Purpose |
|-----------|---------|
| `default` | Where objects go if no namespace is specified; user workloads |
| `kube-system` | Kubernetes internal components: CoreDNS, kube-proxy, metrics-server, etc. |
| `kube-public` | World-readable (even unauthenticated); contains `cluster-info` ConfigMap |
| `kube-node-lease` | Stores Node Lease objects used by kubelet for heartbeats (Node controller) |

- **One-liner** — Never run user workloads in `kube-system`; it belongs to Kubernetes internals.

```bash
# View all namespaces
kubectl get namespaces
kubectl get ns    # short form

# View objects in a namespace
kubectl get pods -n kube-system
kubectl get all -n kube-system

# Create a namespace
kubectl create namespace team-backend
# Or declaratively:
# kubectl apply -f ns.yaml
```

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-backend
```

### Targeting a Namespace

- **Why it exists** — By default kubectl operates on the `default` namespace; you need explicit flags or config to work in other namespaces.
- **What it is** — Two ways to target a namespace: per-command flag (`-n`) or set a persistent default in kubeconfig context.

```bash
# Per-command: use -n flag
kubectl get pods -n production
kubectl apply -f deployment.yaml -n production
kubectl delete pod myapp -n staging

# Set default namespace for current context (persists across commands)
kubectl config set-context --current --namespace=production

# Verify current namespace
kubectl config view --minify | grep namespace

# See objects across ALL namespaces
kubectl get pods -A
kubectl get pods --all-namespaces
```

### ResourceQuota

- **Why it exists** — Without limits, one team can consume all cluster resources and starve others.
- **What it is** — A namespace-scoped object that caps total resource consumption in that namespace. When a ResourceQuota is present, every pod must specify resource requests and limits (otherwise the quota check rejects the pod). You can quota CPU, memory, pod count, service count, PVC count, etc.

- **One-liner** — ResourceQuota enforces resource budget per namespace so teams don't crowd each other out.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-backend
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    services: "10"
```

```bash
# Check quota usage in a namespace
kubectl describe resourcequota -n team-backend
kubectl get resourcequota -n team-backend
```

### LimitRange

- **Why it exists** — ResourceQuota sets namespace totals, but individual pods with no resource spec can still grab anything up to the total. LimitRange sets per-pod defaults and maximums.
- **What it is** — Namespace-scoped policy that sets default requests/limits for containers that don't specify them, and enforces min/max bounds. Complements ResourceQuota.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: team-backend
spec:
  limits:
  - type: Container
    default:
      cpu: "200m"
      memory: "256Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
    max:
      cpu: "2"
      memory: "2Gi"
```

# Troubleshooting

### Objects not found — "No resources found in default namespace"

1. You're probably in the wrong namespace: `kubectl config view --minify | grep namespace`.
2. Use `-n <namespace>` or `-A` to search all namespaces: `kubectl get pods -A | grep <name>`.
3. Set the correct default: `kubectl config set-context --current --namespace=<ns>`.

### Pod rejected — "exceeded quota"

1. `kubectl describe resourcequota -n <namespace>` — check Used vs Hard limits.
2. Pod must specify resource requests when ResourceQuota is active.
3. Add `resources.requests.cpu` and `resources.requests.memory` to pod spec.

### Cannot create namespace-scoped resources — "Forbidden"

1. Check RBAC: `kubectl auth can-i create pods -n <namespace>`.
2. Role bindings may be scoped to a different namespace.
3. Check your service account or kubeconfig user has a RoleBinding in the target namespace.
