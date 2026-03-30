# Network Policies

# Overview
- **Why it exists** — By default, Kubernetes applies zero network isolation: every pod can reach every other pod across all namespaces on any port. A compromised pod can freely probe databases, internal services, and other workloads. NetworkPolicies let you lock down which pods can talk to which.
- **What it is** — A namespace-scoped Kubernetes resource that acts as a firewall for pod traffic. A CNI plugin (Calico, Cilium, Weave) reads the policies and enforces them using iptables or eBPF — the kube-proxy does not participate.
- **One-liner** — NetworkPolicy = namespace firewall rules that restrict pod-to-pod and pod-to-external traffic, enforced by the CNI plugin.

# Architecture

```text
┌──── Node ─────────────────────────────────────────┐
│                                                    │
│  ┌─── Pod A (frontend) ─┐  ┌─── Pod B (backend) ─┐│
│  │     container         │  │     container        ││
│  └──────────┬────────────┘  └──────────┬───────────┘│
│             │ veth                     │ veth        │
│             ▼                         ▼             │
│  ┌──────────────────────────────────────────────┐   │
│  │        CNI plugin (Calico / Cilium)          │   │
│  │                                              │   │
│  │  NetworkPolicy rules evaluated HERE:         │   │
│  │  iptables / eBPF filters traffic             │   │
│  │  before it reaches the destination pod       │   │
│  └──────────────────────────────────────────────┘   │
│                       │                             │
└───────────────────────┼─────────────────────────────┘
                        ▼  cross-node traffic (overlay / BGP)
```

kube-proxy handles Service IP routing. NetworkPolicy handles pod-to-pod firewall — they are independent.

# Mental Model

```text
No NetworkPolicy exists
        │
        ▼
All pods can talk to all pods (default ALLOW everything)
        │
        ▼
Admin creates a NetworkPolicy with a podSelector
        │
        ▼
Selected pods: ONLY traffic matching the policy rules is allowed
              (everything else is implicitly denied for those pods)
Non-selected pods: still default ALLOW (unaffected)
        │
        ▼
Multiple policies on the same pod: UNION of all rules (additive)
A second policy never removes what a first policy allowed
```

The safest baseline: start with a default-deny-all policy for the namespace, then explicitly allow only the traffic that should flow. Build up permissions rather than trying to block specific paths.

# Core Building Blocks

### Policy Structure

- **Why it exists** — NetworkPolicy resources need a consistent schema so the CNI plugin can parse and enforce them reliably across any cluster.
- **What it is** — The YAML structure of a NetworkPolicy object, covering `podSelector`, `policyTypes`, `ingress`, and `egress` fields.
- **One-liner** — The full skeleton of a NetworkPolicy manifest with all four top-level spec fields annotated.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
spec:
  podSelector:         # which pods this policy applies TO
    matchLabels:
      app: backend
  policyTypes:
  - Ingress            # declare that this policy governs ingress
  - Egress             # declare that this policy governs egress
  ingress:
  - from:              # allow FROM these sources
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:                # allow TO these destinations
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
```

| Field | Meaning |
|-------|---------|
| `podSelector` | Which pods this policy applies to. Empty `{}` = all pods in namespace. |
| `policyTypes` | Whether this policy affects `Ingress`, `Egress`, or both. Must be declared explicitly. |
| `ingress` | List of allowed inbound traffic rules. Omit the list entirely to deny all ingress. |
| `egress` | List of allowed outbound traffic rules. Omit the list entirely to deny all egress. |

---

### podSelector — Targeting Pods

- **Why it exists** — Policies are label-driven; the selector determines which pods are governed by this policy.
- **What it is** — A `matchLabels` or `matchExpressions` selector exactly like those used in Services and Deployments.
- **One-liner** — "This policy applies to pods with these labels."

```yaml
podSelector:
  matchLabels:
    app: backend
    tier: api

# Empty selector = applies to ALL pods in the namespace
podSelector: {}
```

---

### Ingress Rules (Incoming Traffic)

- **Why it exists** — Controls which sources are allowed to send traffic to the selected pods.
- **What it is** — A list of `from` selectors. Each entry can use three selector types (alone or combined).

```yaml
ingress:
- from:
  # Allow from pods with matching labels in the SAME namespace
  - podSelector:
      matchLabels:
        app: frontend

  # Allow from all pods in namespaces with matching labels
  - namespaceSelector:
      matchLabels:
        environment: staging

  # Allow from an external CIDR range
  - ipBlock:
      cidr: 203.0.113.0/24
      except:
      - 203.0.113.5/32     # exclude one IP within the range
  ports:
  - protocol: TCP
    port: 8080
```

Selector combination rules within a single `from` entry:
- Multiple selectors in one list item = **AND** (pod must match all selectors).
- Separate list items = **OR** (traffic allowed if any item matches).

---

### Egress Rules (Outgoing Traffic)

- **Why it exists** — Controls which destinations the selected pods can reach. Critical for preventing data exfiltration.
- **What it is** — A list of `to` selectors. Same selector types as ingress (`podSelector`, `namespaceSelector`, `ipBlock`).

```yaml
egress:
# Always allow DNS so pods can resolve service names
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
  ports:
  - protocol: UDP
    port: 53
  - protocol: TCP
    port: 53

# Allow outbound to the database pod
- to:
  - podSelector:
      matchLabels:
        app: database
  ports:
  - protocol: TCP
    port: 5432
```

---

### Default-Deny Pattern

Apply these first in a namespace, then layer on explicit allow policies.

```yaml
# Deny ALL ingress to every pod in the namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}        # applies to ALL pods
  policyTypes:
  - Ingress              # no ingress list = deny everything
---
# Deny ALL egress from every pod in the namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress               # no egress list = deny everything
```

---

### Allow Specific Namespace

```yaml
# Allow all pods in the "monitoring" namespace to scrape pods in "production"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: production
spec:
  podSelector: {}          # applies to all pods in production
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

---

### CNI Plugin Support

| CNI Plugin | NetworkPolicy enforcement |
|------------|---------------------------|
| Calico | Full (ingress + egress) |
| Cilium | Full + extended (L7 rules, DNS-aware egress) |
| Weave Net | Full |
| Flannel | **None** — policies are created but silently ignored |
| Amazon VPC CNI | Requires Network Policy addon (1.25+) |

---

### Common Commands

```bash
# List all NetworkPolicies in a namespace
kubectl get networkpolicy -n production

# Describe a policy (shows selectors and rules clearly)
kubectl describe networkpolicy default-deny-ingress -n production

# Apply a policy
kubectl apply -f deny-all.yaml -n production

# Delete a policy (traffic returns to default allow for affected pods)
kubectl delete networkpolicy default-deny-ingress -n production
```
