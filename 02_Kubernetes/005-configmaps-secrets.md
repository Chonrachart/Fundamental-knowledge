# ConfigMaps and Secrets

- ConfigMaps store non-sensitive configuration as key-value pairs or file content; Secrets store sensitive data (base64-encoded in etcd by default).
- Both can be injected into pods as environment variables or mounted as files in volumes.
- Mounted ConfigMaps/Secrets auto-update (with delay), but env vars and subPath mounts require a pod restart.

# Mental Model

```text
ConfigMap / Secret created in namespace
        │
        ▼
Pod spec references it via:
  env/envFrom    → set at pod start, NOT live-updated
  volumeMount    → files appear in container filesystem
        │
        ▼
kubelet watches for changes:
  volume mount   → auto-syncs (~1 min delay)
  subPath mount  → NO auto-sync (restart required)
  env var        → NO auto-sync (restart required)
```

# Core Building Blocks

### ConfigMap

- Store non-sensitive config (key-value or file content); mount or inject as env.
- Namespaced; reference in pod spec.
- ConfigMaps and Secrets are namespaced; they must be in the same namespace as the pod that uses them.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  config.yaml: |
    log_level: info
  DB_HOST: db.default.svc.cluster.local
```

### Secret

- Store sensitive data (base64-encoded in `etcd` by default); use for TLS, passwords, tokens.
- Types: `Opaque` (generic), `kubernetes.io/dockerconfigjson` (registry), `kubernetes.io/tls`.
- Prefer external secret operators or CSI for production secrets; encrypt at rest.
- Secrets are base64-encoded, not encrypted — enable encryption at rest for real security.
- `Opaque` is the default Secret type for generic key-value data.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  password: <base64>
```

### Env from ConfigMap/Secret

- **env**: Single var from ConfigMap/Secret key.
- **envFrom**: All keys from ConfigMap/Secret as env vars (optional prefix).
- Environment variables from ConfigMap/Secret are set once at pod start and never live-update.
- `envFrom` injects all keys from a ConfigMap/Secret as env vars; use `prefix` to avoid name collisions.

```yaml
env:
- name: DB_HOST
  valueFrom:
    configMapKeyRef:
      name: app-config
      key: DB_HOST
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secret
      key: password
envFrom:
- configMapRef:
    name: app-config
```

### Volume Mount

- Mount ConfigMap or Secret as files in container; update on change (`kubelet` syncs).
- **subPath**: Mount one key as one file; useful when whole ConfigMap is one file.
- Volume-mounted ConfigMaps/Secrets auto-update with ~1 minute delay, except `subPath` mounts.

```yaml
volumeMounts:
- name: config-vol
  mountPath: /etc/config
  readOnly: true
volumes:
- name: config-vol
  configMap:
    name: app-config
```

### Best Practices

- Keep ConfigMaps/Secrets small; split by concern.
- Use `immutable: true` for ConfigMaps/Secrets that do not change (better performance).
- Do not put real secrets in Git; use tooling (`sealed-secrets`, `external-secrets`, Vault).
- `immutable: true` prevents changes and improves performance by stopping `kubelet` watches.

Related notes: [002-pods-labels](./002-pods-labels.md), [006-kubectl-debugging](./006-kubectl-debugging.md)

---

# Troubleshooting Guide

### Env var from ConfigMap/Secret is empty in pod
1. Check ConfigMap/Secret exists: `kubectl get configmap <name>` / `kubectl get secret <name>`.
2. Check key name matches: `kubectl describe configmap <name>` — verify key spelling.
3. Check pod spec: `valueFrom.configMapKeyRef.key` must match exactly.
4. Restart pod after ConfigMap change (env vars are set at pod start, not live-updated).

### Mounted ConfigMap file not updating
1. Updates propagate automatically but with delay (`kubelet` sync period, ~1 min).
2. **subPath** mounts do NOT auto-update — must restart pod.
3. Verify: `kubectl exec <pod> -- cat /etc/config/<key>`.

### "Secret not found" when creating pod
1. Secret must exist in same namespace as pod.
2. Check: `kubectl get secret <name> -n <namespace>`.
3. If using `imagePullSecrets`, Secret type must be `kubernetes.io/dockerconfigjson`.
