ConfigMap
Secret
env
volumeMount
envFrom

---

# ConfigMap

- Store non-sensitive config (key-value or file content); mount or inject as env.
- Namespaced; reference in pod spec.

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

# Secret

- Store sensitive data (base64-encoded in etcd by default); use for TLS, passwords, tokens.
- Types: Opaque (generic), kubernetes.io/dockerconfigjson (registry), kubernetes.io/tls.
- Prefer external secret operators or CSI for production secrets; encrypt at rest.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  password: <base64>
```

# Env from ConfigMap/Secret

- **env**: Single var from ConfigMap/Secret key.
- **envFrom**: All keys from ConfigMap/Secret as env vars (optional prefix).

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

# Volume Mount

- Mount ConfigMap or Secret as files in container; update on change (kubelet syncs).
- **subPath**: Mount one key as one file; useful when whole ConfigMap is one file.

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

# Best Practices

- Keep ConfigMaps/Secrets small; split by concern.
- Use immutable: true for ConfigMaps/Secrets that do not change (better performance).
- Do not put real secrets in Git; use tooling (sealed-secrets, external-secrets, Vault).
