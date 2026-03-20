# Network Policies

- NetworkPolicy is a namespace-level firewall that controls pod-to-pod and pod-to-external traffic using label selectors.
- Without any NetworkPolicy, all pods can communicate freely — adding a policy implicitly denies non-matching traffic.
- Requires a CNI plugin that supports NetworkPolicy (Calico, Cilium, Weave); Flannel does NOT enforce them.

# Mental Model

```text
No NetworkPolicy exists
        │
        ▼
All pods can talk to all pods (default allow)
        │
        ▼
Admin creates NetworkPolicy selecting pods via podSelector
        │
        ▼
Selected pods: only traffic matching the policy rules is allowed
Non-selected pods: still default allow (unless they have their own policy)
        │
        ▼
Multiple policies on same pod: UNION of all rules (additive, never restrictive)
```

Example:
```bash
# Apply default deny for all pods in namespace
kubectl apply -f deny-all.yaml -n production

# Then allow specific traffic
kubectl apply -f allow-frontend-to-backend.yaml -n production

# Verify
kubectl describe networkpolicy -n production
```

# Core Building Blocks

### Policy Structure

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

- **podSelector**: Which pods this policy applies to (empty = all pods in namespace).
- **policyTypes**: `Ingress`, `Egress`, or both.
- **ingress/egress**: Rules defining allowed traffic sources/destinations.

### Ingress Rules (Incoming Traffic)

- **podSelector**: Allow from pods with matching labels (same namespace).
- **namespaceSelector**: Allow from pods in namespaces with matching labels.
- **ipBlock**: Allow from CIDR range (e.g. `10.0.0.0/8`); can exclude with `except`.
- Combine selectors in one `from` entry = AND; separate `from` entries = OR.

### Egress Rules (Outgoing Traffic)

- Same selectors as ingress: podSelector, namespaceSelector, ipBlock.
- Common pattern: allow DNS egress (port 53) to kube-system, then restrict other outbound.

```yaml
egress:
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
  ports:
  - protocol: UDP
    port: 53
- to:
  - podSelector:
      matchLabels:
        app: database
  ports:
  - protocol: TCP
    port: 5432
```

### Default Deny Policies

```yaml
# Deny all ingress in namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
  - Ingress

# Deny all egress in namespace
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

### CNI Support

| CNI Plugin | NetworkPolicy Support |
|------------|----------------------|
| Calico | Full (ingress + egress) |
| Cilium | Full + extended (L7, DNS-aware) |
| Weave Net | Full |
| Flannel | None — policies are ignored |

Related notes: [004-services-ingress](./004-services-ingress.md), [002-pods-labels](./002-pods-labels.md)

---

# Troubleshooting Guide

### Pod cannot reach another pod after adding NetworkPolicy
1. Check if default deny is in place: `kubectl get networkpolicy -n <namespace>`.
2. Check labels: policy `podSelector` must match the target pod's labels exactly.
3. Check ingress rules: source pod must match a `from` selector in the target's policy.
4. Check ports: policy must allow the specific port and protocol.

### DNS resolution fails after adding egress policy
1. Egress deny blocks DNS (port 53 UDP) to kube-system.
2. Add egress rule allowing UDP 53 to kube-system namespace.
3. Test: `kubectl exec <pod> -- nslookup kubernetes.default`.

### NetworkPolicy has no effect
1. Check CNI plugin: `kubectl get pods -n kube-system | grep -E 'calico|cilium|weave'`.
2. Flannel does NOT enforce NetworkPolicy — policies exist but are ignored.
3. Verify policy is in the correct namespace.

# Quick Facts (Revision)

- No NetworkPolicy = all traffic allowed; first policy on a pod implicitly denies non-matching traffic.
- Multiple policies on the same pod are additive (union of rules), never restrictive.
- `podSelector: {}` (empty) selects ALL pods in the namespace.
- Ingress and egress are independent; you can restrict one without the other.
- Always allow DNS egress (UDP 53) when adding egress policies, or pods can't resolve service names.
- NetworkPolicy is namespaced; it cannot control traffic to/from other namespaces without namespaceSelector.
- Flannel does not support NetworkPolicy; use Calico or Cilium for enforcement.
