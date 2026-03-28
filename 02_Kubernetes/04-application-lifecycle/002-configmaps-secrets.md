# ConfigMaps and Secrets

# Overview
- **Why it exists** — Hardcoding configuration and credentials into container images makes them inflexible and insecure; ConfigMaps and Secrets let you decouple config from the image so the same image runs in dev, staging, and production with different values.
- **What it is** — Namespace-scoped Kubernetes objects that store key-value pairs or file content; ConfigMaps for non-sensitive config, Secrets for sensitive data; both injectable into pods as env vars or volume-mounted files.
- **One-liner** — Decouple application configuration and credentials from the container image.

# Architecture

```text
┌─────────────┐    ┌──────────────┐
│  ConfigMap  │    │    Secret    │
│  (plaintext)│    │  (base64)    │
└──────┬──────┘    └──────┬───────┘
       │                  │
       ├──── env/envFrom ─┤──► container ENV vars (set once at pod start)
       │                  │
       └── volume mount ──┘──► files in container filesystem
                                  │
                           kubelet watches ──► auto-sync (~1 min)
                           (except subPath ──► NO auto-sync)
```

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

ConfigMaps and Secrets must live in the **same namespace** as the pod that references them.

# Core Building Blocks

### ConfigMap

- **Why it exists** — Stores non-sensitive configuration so pods can receive different settings without rebuilding the image.
- **What it is** — A key-value store where values can be plain strings or multi-line file content (e.g., full YAML/INI files).
- **One-liner** — Named bag of non-sensitive key-value or file-content config.

Creation methods:

```bash
# Literal key-value pairs
kubectl create configmap app-config --from-literal=DB_HOST=db.default.svc.cluster.local --from-literal=LOG_LEVEL=info

# From a file (key = filename, value = file contents)
kubectl create configmap app-config --from-file=config.yaml

# Declarative YAML
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: info
  DB_HOST: db.default.svc.cluster.local
  config.yaml: |
    log_level: info
    timeout: 30s
```

### Secret

- **Why it exists** — Sensitive values (passwords, tokens, TLS keys) need separate handling from plain config — restricted RBAC, encryption at rest, and audit logging.
- **What it is** — Same structure as ConfigMap but values are base64-encoded in the API; access is gated by RBAC; can be encrypted at rest via EncryptionConfiguration.
- **One-liner** — Named bag of sensitive data stored base64-encoded with tighter access controls.

> **Important:** base64 is encoding, NOT encryption. Anyone who can read the Secret object sees the plaintext. Enable encryption at rest and restrict RBAC for real security.

Creation methods:

```bash
# Literal
kubectl create secret generic db-secret --from-literal=password=s3cr3t

# From file
kubectl create secret generic tls-secret --from-file=tls.crt --from-file=tls.key

# Specific type
kubectl create secret tls my-tls --cert=tls.crt --key=tls.key
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=pass
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
data:
  password: czNjcjN0   # base64 of "s3cr3t"
```

### Secret Types

| Type | Purpose |
|---|---|
| `Opaque` | Generic key-value (default) |
| `kubernetes.io/dockerconfigjson` | Registry pull credentials (`imagePullSecrets`) |
| `kubernetes.io/tls` | TLS certificate + private key |
| `kubernetes.io/service-account-token` | Service account API token |
| `kubernetes.io/basic-auth` | Username + password |
| `kubernetes.io/ssh-auth` | SSH private key |

### Injection: env var vs volume mount

| Method | How | Live update? | Best for |
|---|---|---|---|
| `env` (single key) | `valueFrom.configMapKeyRef` / `secretKeyRef` | No — restart required | Individual env vars |
| `envFrom` (all keys) | `configMapRef` / `secretRef` + optional `prefix` | No — restart required | Bulk injection of all keys |
| `volumeMount` | ConfigMap/Secret as files in a directory | Yes — ~1 min delay | Config files, TLS certs |
| `volumeMount` with `subPath` | Single key as a named file | No — restart required | Single file overlay |

```yaml
# env var injection examples
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

# envFrom — inject all keys at once
envFrom:
- configMapRef:
    name: app-config
- secretRef:
    name: db-secret
    # optional prefix: APP_  → keys become APP_KEY_NAME
```

```yaml
# Volume mount injection
volumeMounts:
- name: config-vol
  mountPath: /etc/config
  readOnly: true
volumes:
- name: config-vol
  configMap:
    name: app-config
```

### Encryption at Rest

By default, Secrets are stored in etcd as base64 plaintext. Enable `EncryptionConfiguration` on the API server to encrypt Secret data at rest using AES-GCM or other providers. In managed clusters (EKS, GKE, AKS) this is typically a one-checkbox option.

For production workloads prefer external secret management: `sealed-secrets`, `external-secrets-operator`, or HashiCorp Vault with the CSI provider.

# Troubleshooting

### Env var from ConfigMap/Secret is empty in pod
1. Verify the object exists: `kubectl get configmap <name>` / `kubectl get secret <name>`
2. Check key spelling: `kubectl describe configmap <name>` — key names are case-sensitive
3. Env vars are set at pod start — after updating the ConfigMap, restart the pod for changes to take effect

### Mounted ConfigMap file not updating
1. Volume-mounted ConfigMaps auto-update with ~1 min kubelet sync delay — wait and re-check
2. `subPath` mounts do NOT auto-update — must restart the pod
3. Verify current content: `kubectl exec <pod> -- cat /etc/config/<key>`

### "Secret not found" when pod is created
1. Secret must exist in the **same namespace** as the pod
2. Check: `kubectl get secret <name> -n <namespace>`
3. For `imagePullSecrets` the Secret type must be `kubernetes.io/dockerconfigjson`
