# kube-apiserver

### Overview

**Why it exists** — Every Kubernetes component (scheduler, controllers, kubelet, kubectl, CI pipelines) needs to read and modify cluster state. Without a single entry point, components would conflict and bypass security controls.
**What it is** — The API server is the single front door for all cluster operations. Nothing bypasses it — not the scheduler, not the controller manager, not kubelet. It validates requests, authenticates callers, authorizes actions via RBAC, then persists objects to etcd. It exposes a REST API over HTTPS on port 6443.
**One-liner** — The API server is the cluster's gatekeeper: every read, write, and watch goes through it.

### Architecture

```text
                    ┌───────────────────────────────────┐
kubectl / clients ──►                                   │
CI/CD pipelines  ──►         kube-apiserver             │
other components ──►         port 6443 (HTTPS)          │
                    │                                   │
                    │  1. Authenticate (certs, tokens)  │
                    │  2. Authorize (RBAC)               │
                    │  3. Admission control              │
                    │  4. Validate object schema         │
                    │  5. Read/write etcd               │
                    │                                   │
                    └──────────────────┬────────────────┘
                                       │
                                       ▼
                                     etcd
                           (only path to cluster state)
```

### Mental Model

```text
kubectl apply -f deploy.yaml
        │
        ▼
HTTPS POST /apis/apps/v1/namespaces/default/deployments
        │
        ▼
Authentication: Is this caller who they claim to be?
  → cert-based (kubeconfig), Bearer token, ServiceAccount JWT
        │
        ▼
Authorization: Is this caller allowed to do this?
  → RBAC: check Role/ClusterRole bindings
        │
        ▼
Admission control: Should this request be allowed/mutated?
  → MutatingWebhookConfiguration (e.g. inject sidecar)
  → ValidatingWebhookConfiguration (e.g. policy checks)
        │
        ▼
Validation: Does the object schema match the API spec?
        │
        ▼
Persist to etcd → return 200/201 to caller
        │
        ▼
Controllers and scheduler watch changes via API server
```

### Core Building Blocks

### Authentication

**Why it exists** — The API server must verify the identity of every caller before deciding what they can do.
**What it is** — Supports multiple authentication mechanisms in parallel. Kubernetes does not have a built-in user database; identity is established via certificates, tokens, or external providers.
**One-liner** — Authentication answers "who are you?" before any other check.

| Mechanism | Used by | How |
|-----------|---------|-----|
| Client certificate (x509) | kubectl, kubeadm nodes | Cert signed by cluster CA in kubeconfig |
| Bearer token | ServiceAccounts, CI | JWT signed by API server |
| OIDC | SSO/enterprise users | External IdP (Google, Okta) |

### Authorization (RBAC)

**Why it exists** — Different users and components should only access the resources they need.
**What it is** — Role-Based Access Control. The API server checks whether the authenticated identity has a Role or ClusterRole binding that permits the requested verb (get, list, create, delete, etc.) on the requested resource (pods, deployments, secrets, etc.).
**One-liner** — RBAC answers "are you allowed to do this?" after authentication.

```bash
# Check what you're allowed to do
kubectl auth can-i create pods
kubectl auth can-i delete deployments --namespace production
kubectl auth can-i '*' '*'   # cluster-admin check
```

### Admission Control

**Why it exists** — Some policies cannot be expressed as pure RBAC (e.g. "inject a sidecar", "require resource limits").
**What it is** — Webhooks that run after authentication/authorization but before object persistence. Mutating webhooks can modify the object (e.g. inject labels, set defaults). Validating webhooks can reject requests based on custom rules.
**One-liner** — Admission controllers are the plugin layer that mutates or rejects objects after RBAC passes.

### REST API on Port 6443

**Why it exists** — Everything interacts with the cluster through HTTP — makes the API language-agnostic and introspectable.
**What it is** — All Kubernetes objects are REST resources. `kubectl` is just a typed HTTP client. You can interact with the API directly using `curl` or any HTTP library.
**One-liner** — Port 6443 is the HTTPS endpoint where every cluster interaction begins.

```bash
# Health check (no auth needed for /healthz)
curl -k https://<control-plane-ip>:6443/healthz

# List pods using raw API (with token)
# Since K8s 1.24, SA tokens are no longer auto-created as Secrets.
# Modern approach: generate a bound, short-lived token on demand:
TOKEN=$(kubectl create token <sa-name>)
curl -k -H "Authorization: Bearer $TOKEN" \
  https://<api-server>:6443/api/v1/namespaces/default/pods

# Pre-1.24 only (auto-created Secret still exists):
# TOKEN=$(kubectl -n default get secret <sa-secret> -o jsonpath='{.data.token}' | base64 -d)

# Check API server pod on control plane
kubectl get pod -n kube-system -l component=kube-apiserver

# Check API server flags
kubectl describe pod -n kube-system kube-apiserver-<node>
```

### Watches (Event-Driven Architecture)

**Why it exists** — Polling the API server constantly would be expensive; components need to react to changes immediately.
**What it is** — Clients (scheduler, controllers, kubelet) open long-lived HTTP watch connections. The API server streams change events (ADDED, MODIFIED, DELETED) as etcd data changes. This is how the entire reconciliation loop works efficiently.
**One-liner** — Watches are the mechanism that makes Kubernetes event-driven rather than poll-based.

### Troubleshooting

### kubectl returns "connection refused" or times out

1. Verify API server is running: `kubectl get pods -n kube-system -l component=kube-apiserver`.
2. On control plane: `systemctl status kube-apiserver` (if running as a service) or `crictl ps | grep apiserver`.
3. Check port 6443: `ss -tlnp | grep 6443` on control plane node.
4. Check kubeconfig: `kubectl config view` — verify server URL is correct.

### "Forbidden" errors from kubectl

1. Check RBAC: `kubectl auth can-i <verb> <resource>`.
2. Inspect bindings: `kubectl get rolebindings,clusterrolebindings -A | grep <username>`.
3. Check ServiceAccount if running in-cluster: `kubectl describe serviceaccount <name> -n <ns>`.

### API server slow or returning 429 (Too Many Requests)

1. Check API priority and fairness: `kubectl get flowschemas` and `kubectl get prioritylevelconfigurations`.
2. Reduce unnecessary watch connections or LIST requests from controllers.
3. Check etcd latency — slow etcd causes slow API server responses.
