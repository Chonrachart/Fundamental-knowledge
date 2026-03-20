# RBAC and Service Accounts

- RBAC (Role-Based Access Control) controls who can do what in a cluster using Roles, ClusterRoles, and Bindings.
- A ServiceAccount is a pod-level identity; pods authenticate to the API server using the ServiceAccount's token.
- Principle of least privilege: grant only the permissions each workload or user actually needs.

# Mental Model

```text
User / ServiceAccount  ──authenticates──▶  API Server
        │
        ▼
RoleBinding / ClusterRoleBinding
  "subject X has role Y"
        │
        ▼
Role / ClusterRole
  "role Y can [verbs] on [resources]"
        │
        ▼
API Server checks: does this subject have
a binding to a role that allows this verb
on this resource in this namespace?
        │
        ▼
Allow or Deny (403 Forbidden)
```

Example:
```bash
# Create a Role that can read pods in "dev" namespace
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n dev

# Bind it to a ServiceAccount
kubectl create rolebinding pod-reader-binding \
  --role=pod-reader --serviceaccount=dev:my-app -n dev

# Verify
kubectl auth can-i get pods -n dev --as=system:serviceaccount:dev:my-app
```

# Core Building Blocks

### Role and ClusterRole

- **Role**: Namespaced; grants permissions within one namespace.
- **ClusterRole**: Cluster-wide; grants permissions across all namespaces or on cluster-scoped resources (nodes, PVs).
- Rules: list of `apiGroups`, `resources`, `verbs`.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

| Verb | Meaning |
|------|---------|
| get | Read a specific resource |
| list | List all resources |
| watch | Stream changes |
| create | Create new resources |
| update | Modify existing resources |
| patch | Partial update |
| delete | Delete resources |

### RoleBinding and ClusterRoleBinding

- **RoleBinding**: Binds a Role (or ClusterRole) to subjects in one namespace.
- **ClusterRoleBinding**: Binds a ClusterRole to subjects cluster-wide.
- Subjects: User, Group, or ServiceAccount.

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
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

### ServiceAccount

- Every namespace has a `default` ServiceAccount; pods use it unless specified otherwise.
- Custom ServiceAccount: create and assign to pod via `spec.serviceAccountName`.
- **automountServiceAccountToken: false**: Disable token mount when pod doesn't need API access.

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
spec:
  serviceAccountName: my-app
  automountServiceAccountToken: true
```

### Best Practices

- Never use `cluster-admin` for application ServiceAccounts.
- Set `automountServiceAccountToken: false` on the default ServiceAccount and on pods that don't need API access.
- Use separate ServiceAccounts per application; don't share the default.
- Prefer Role + RoleBinding (namespaced) over ClusterRole + ClusterRoleBinding when possible.

Related notes: [001-kubernetes-overview](./001-kubernetes-overview.md), [005-configmaps-secrets](./005-configmaps-secrets.md)

---

# Troubleshooting Guide

### Pod gets 403 Forbidden from API server
1. Check ServiceAccount: `kubectl get pod <name> -o jsonpath='{.spec.serviceAccountName}'`.
2. Check bindings: `kubectl get rolebindings,clusterrolebindings -A | grep <sa-name>`.
3. Test permissions: `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa>`.
4. Missing binding: create RoleBinding or ClusterRoleBinding for the ServiceAccount.

### User cannot access resources in namespace
1. Check user identity: `kubectl auth whoami` (v1.27+) or check kubeconfig context.
2. List roles and bindings: `kubectl get rolebindings -n <namespace>`.
3. Test: `kubectl auth can-i list pods -n <namespace> --as=<user>`.
4. Create appropriate RoleBinding if missing.

### ServiceAccount token not mounted
1. Check `automountServiceAccountToken` on both the ServiceAccount and Pod spec.
2. If false on SA, override with `automountServiceAccountToken: true` on the pod (or vice versa).
3. Check: `kubectl exec <pod> -- ls /var/run/secrets/kubernetes.io/serviceaccount/`.

# Quick Facts (Revision)

- RBAC has four objects: Role, ClusterRole, RoleBinding, ClusterRoleBinding.
- Role is namespaced; ClusterRole is cluster-wide.
- RoleBinding can reference a ClusterRole but scopes it to the binding's namespace.
- Every pod gets the `default` ServiceAccount unless `serviceAccountName` is set.
- `kubectl auth can-i` tests permissions without actually performing the action.
- `automountServiceAccountToken: false` is a security best practice for pods that don't call the API.
- API groups: `""` is core (pods, services), `apps` is deployments, `rbac.authorization.k8s.io` is RBAC.
