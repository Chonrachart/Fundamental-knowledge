# RBAC (Role-Based Access Control)

# Overview
- **Why it exists** — By default, any authenticated identity in a Kubernetes cluster can attempt any operation. RBAC enforces least-privilege: pods and users receive only the permissions they actually need. A compromised pod that has no API permissions cannot escalate to delete namespaces or read secrets from other workloads.
- **What it is** — An authorization mechanism built into the API server. It uses four object types — Role, ClusterRole, RoleBinding, ClusterRoleBinding — to define what actions (verbs) a subject (user, group, or ServiceAccount) can perform on which resources.
- **One-liner** — RBAC maps "who" to "what they can do" using Roles and Bindings, enforcing least-privilege for every identity in the cluster.

# Architecture

```text
Request arrives at API Server
    │
    ▼
1. Authentication  ── who are you?
   (client cert CN, bearer token, OIDC)
    │
    ▼
2. Authorization   ── are you allowed?
   RBAC engine:
     subject ──► RoleBinding/ClusterRoleBinding
                       │
                       ▼
                 Role/ClusterRole
                       │
                       ▼
               rules: [apiGroups, resources, verbs]
    │
    ▼
3. Admission Control ── mutate/validate
    │
    ▼
4. Persist to etcd (accepted)
```

# Mental Model

```text
User / ServiceAccount  ──authenticates──►  API Server
        │
        ▼
RoleBinding / ClusterRoleBinding
  "subject X has role Y (in namespace Z)"
        │
        ▼
Role / ClusterRole
  "role Y can [get, list, watch] on [pods, secrets]"
        │
        ▼
API Server: does this subject have a binding
            to a role that allows this verb
            on this resource in this namespace?
        │
    ┌───┴───┐
  Allow    Deny (403 Forbidden)
```

Key distinction:
- **Role + RoleBinding** — scoped to one namespace. Use for most application permissions.
- **ClusterRole + ClusterRoleBinding** — cluster-wide. Use for nodes, PersistentVolumes, or cross-namespace access.
- A RoleBinding can reference a ClusterRole — this scopes the ClusterRole's permissions down to the binding's namespace.

# Core Building Blocks

### Role (namespace-scoped)
- **Why it exists** — Grants permissions within a single namespace without touching the rest of the cluster.
- **What it is** — A namespaced object that holds a list of `rules`. Each rule specifies `apiGroups`, `resources`, and `verbs`.
- **One-liner** — "In namespace X, you may do [verbs] on [resources]."

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: pod-reader
rules:
- apiGroups: [""]           # "" = core API group (pods, services, configmaps, secrets)
  resources: ["pods", "pods/log"]
  verbs: ["get", "list", "watch"]
```

```bash
# Imperative shortcut
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  -n dev
```

### ClusterRole (cluster-wide)
- **Why it exists** — Some resources are cluster-scoped (nodes, PersistentVolumes, namespaces) and cannot be accessed with a namespaced Role.
- **What it is** — Same structure as Role but without a namespace field. Can also be used as a template referenced by RoleBindings in specific namespaces.
- **One-liner** — "Anywhere in the cluster, you may do [verbs] on [resources]."

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch"]
```

```bash
kubectl create clusterrole node-reader \
  --verb=get,list,watch \
  --resource=nodes
```

### Verb reference

| Verb | HTTP method | Meaning |
|------|-------------|---------|
| get | GET (single) | Read a specific resource |
| list | GET (collection) | List all resources of a type |
| watch | GET (streaming) | Stream change events |
| create | POST | Create a new resource |
| update | PUT | Replace an existing resource |
| patch | PATCH | Partially modify a resource |
| delete | DELETE | Remove a resource |
| deletecollection | DELETE (collection) | Delete all matching resources |

### API group reference

| apiGroups value | Covers |
|-----------------|--------|
| `""` | Core: pods, services, configmaps, secrets, namespaces, nodes |
| `apps` | Deployments, ReplicaSets, StatefulSets, DaemonSets |
| `batch` | Jobs, CronJobs |
| `rbac.authorization.k8s.io` | Roles, ClusterRoles, Bindings |
| `networking.k8s.io` | Ingresses, NetworkPolicies |

---

### RoleBinding
- **Why it exists** — A Role alone grants nothing; a binding connects the role to a subject.
- **What it is** — Namespaced object that binds a Role (or ClusterRole) to one or more subjects within one namespace.
- **One-liner** — "Subject X has Role Y in namespace Z."

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pod-reader-binding
  namespace: dev
subjects:
- kind: ServiceAccount
  name: my-app
  namespace: dev
# - kind: User
#   name: alice
#   apiGroup: rbac.authorization.k8s.io
# - kind: Group
#   name: dev-team
#   apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role          # or ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

```bash
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader \
  --serviceaccount=dev:my-app \
  -n dev
```

### ClusterRoleBinding
- **Why it exists** — Grants cluster-wide access; needed for cluster-scoped resources or for cluster-admin access.
- **What it is** — Same as RoleBinding but binds a ClusterRole and applies across the entire cluster.
- **One-liner** — "Subject X has ClusterRole Y everywhere."

```bash
kubectl create clusterrolebinding node-reader-binding \
  --clusterrole=node-reader \
  --serviceaccount=monitoring:prometheus
```

---

### ServiceAccounts as Pod Identity
- **Why it exists** — Pods need to call the Kubernetes API (e.g. to list pods, update ConfigMaps). ServiceAccounts provide a namespaced identity for that.
- **What it is** — A namespaced resource. Every namespace has a `default` SA. The kubelet mounts a short-lived token for the SA into every pod at `/var/run/secrets/kubernetes.io/serviceaccount/token`.
- **One-liner** — The identity a pod uses when talking to the API server.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: dev
---
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  namespace: dev
spec:
  serviceAccountName: my-app          # use custom SA instead of default
  automountServiceAccountToken: false # disable token if pod doesn't call API
  containers:
  - name: app
    image: my-app:1.0
```

---

### Common Permission Patterns

| Pattern | Role type | Key permissions | Use case |
|---------|-----------|-----------------|----------|
| Read-only viewer | Role | `get,list,watch` on `pods,services,deployments` | Dev team visibility |
| Namespace admin | Role | All verbs on all resources in namespace | Team owns a namespace |
| Pod executor | Role | `get` on `pods`, `create` on `pods/exec` | CI/CD exec into pods |
| Secret reader | Role | `get,list` on `secrets` | App reads own secrets |
| Cross-namespace reader | ClusterRole + RoleBinding per NS | `get,list,watch` on selected resources | Monitoring agents |
| Cluster-admin (avoid) | ClusterRoleBinding | `*` on `*` | Break-glass only |

---

### Checking Permissions

```bash
# Can the current user do X?
kubectl auth can-i get pods -n dev

# Can a specific ServiceAccount do X?
kubectl auth can-i get pods -n dev \
  --as=system:serviceaccount:dev:my-app

# Can a user do X?
kubectl auth can-i delete deployments --as=alice -n prod

# List all permissions for current user
kubectl auth can-i --list -n dev

# Who am I?
kubectl auth whoami          # requires Kubernetes v1.27+
```
