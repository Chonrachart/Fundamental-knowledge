# Kustomize Generators

# Overview

- **Why it exists** — ConfigMaps and Secrets that are referenced by pods must trigger a pod rollout when their content changes. With manually created ConfigMaps, changing the content doesn't change the ConfigMap name, so Kubernetes doesn't know to restart pods. Generators solve this by automatically appending a content hash to the generated resource name — any config change produces a new name, which forces a new Deployment rollout automatically.
- **What it is** — `configMapGenerator` and `secretGenerator` are Kustomize built-ins that generate ConfigMap and Secret resources from literals, files, or environment files. The generated resource gets a hash suffix in its name (e.g., `app-config-k7t9m2p`). Deployments that reference the ConfigMap by the base name get their references updated automatically by Kustomize to use the hashed name.
- **One-liner** — Generators = auto-create ConfigMaps/Secrets with a hash suffix so any config change triggers an automatic pod rollout.

# Architecture

```text
Generator → hash-suffixed resource → auto pod rollout:

configMapGenerator:               secretGenerator:
  name: app-config                  name: db-secret
  literals:                         literals:
    - KEY=value                       - password=secret
         │                                    │
         ▼                                    ▼
  ConfigMap: app-config-k7t9m2p    Secret: db-secret-x4r2w8n
  (hash derived from content)      (hash derived from content)
         │                                    │
         ▼                                    ▼
  Deployment envFrom/valueFrom     Pod secretKeyRef
  references updated automatically references updated automatically
         │
         ▼
  Any content change → new hash → new resource name
  → Deployment spec changes → rolling update triggered
```

# Mental Model

- Any config change = new hash = new resource name = Deployment spec updated = automatic rolling update
- The hash is deterministic: same content always produces the same hash, so re-applying without changes is idempotent
- Kustomize automatically rewrites all references to the base name (e.g., `app-config`) to the hashed name in the final manifests

```text
Config change workflow:

1. Edit configMapGenerator literals in kustomization.yaml
2. Run: kubectl apply -k overlays/prod/
3. Kustomize generates new ConfigMap with new hash
   app-config-abc123 (old) → app-config-def456 (new)
4. Kustomize updates Deployment envFrom to reference def456
5. Deployment spec has changed → Kubernetes triggers rolling update
6. New pods start with new config
7. Old ConfigMap (abc123) remains for rollback
```

# Core Building Blocks

### configMapGenerator

- **Why it exists** — ConfigMaps hold application configuration (database hosts, feature flags, log levels). Teams need to manage these values per-environment, version-control them, and ensure pod restarts happen when values change. `configMapGenerator` handles all three automatically.
- **What it is** — A list of ConfigMap generator entries in `kustomization.yaml`. Each entry declares a name, and one or more sources: `literals` (KEY=value pairs), `files` (include file contents as a data key), or `envs` (parse a `.env` file). Kustomize generates a ConfigMap resource with all sources merged and a hash suffix appended to the name.
- **One-liner** — Declare config as literals or files in `kustomization.yaml`; Kustomize creates the ConfigMap with a hash suffix.

```yaml
# kustomization.yaml
configMapGenerator:
  # From literals (KEY=value pairs)
  - name: app-config
    literals:
      - DATABASE_HOST=prod.db.internal
      - DATABASE_PORT=5432
      - LOG_LEVEL=WARNING
      - API_TIMEOUT=60
      - FEATURE_FLAGS=

  # From files (file contents become a data entry keyed by filename)
  - name: nginx-config
    files:
      - nginx.conf              # data key: "nginx.conf"
      - conf.d/default.conf     # data key: "default.conf"

  # From env file (parses KEY=value lines, one per key)
  - name: env-config
    envs:
      - app.env                 # each line becomes a separate data key

  # Combining sources
  - name: combined-config
    literals:
      - ENV=production
    files:
      - config.json
    envs:
      - secrets.env
```

```yaml
# base/deployment.yaml — referencing the generated ConfigMap
spec:
  template:
    spec:
      containers:
      - name: app
        # Load all keys as environment variables
        envFrom:
          - configMapRef:
              name: app-config       # Kustomize rewrites to app-config-<hash>

        # Or reference individual keys
        env:
        - name: DATABASE_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config       # Kustomize rewrites to app-config-<hash>
              key: DATABASE_HOST

        # Mount as files in a volume
        volumeMounts:
        - name: config-vol
          mountPath: /etc/config
      volumes:
      - name: config-vol
        configMap:
          name: nginx-config         # Kustomize rewrites to nginx-config-<hash>
```

### secretGenerator

- **Why it exists** — Secrets (passwords, API keys, TLS certificates) need the same hash-based rollout behavior as ConfigMaps. `secretGenerator` provides the same mechanism for sensitive data and integrates with external secret management tools (sealed-secrets, external-secrets-operator) via file-based sources.
- **What it is** — Same structure as `configMapGenerator` but produces Secret resources. Values from `literals` are base64-encoded automatically. In production, secrets typically come from files (written by vault/sops at deploy time) rather than hardcoded literals in `kustomization.yaml`.
- **One-liner** — Same as configMapGenerator but for Secrets — auto-encodes values and adds hash suffix.

```yaml
# kustomization.yaml — secretGenerator
secretGenerator:
  # From literals (values are base64-encoded automatically)
  - name: db-credentials
    literals:
      - username=appuser
      - password=changeme   # in production, use files or external-secrets instead

  # From files (file contents are base64-encoded)
  # Good for TLS certs, SSH keys
  - name: tls-secret
    type: kubernetes.io/tls
    files:
      - tls.crt
      - tls.key

  # From env file (each KEY=value line becomes a secret entry)
  - name: app-secrets
    envs:
      - secrets.env         # file written by vault/sops at deploy time, gitignored
```

```yaml
# base/deployment.yaml — referencing the generated Secret
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials   # Kustomize rewrites to db-credentials-<hash>
              key: password
        - name: DB_USERNAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
```

### Hash Suffix Behavior

- **Why it exists** — The hash suffix is what makes generators valuable. Without it, updating a ConfigMap doesn't change the Deployment spec, so Kubernetes doesn't roll out new pods — they keep using the old config until manually restarted.
- **What it is** — Kustomize computes a deterministic hash of all the ConfigMap/Secret data. This hash is appended to the resource name (e.g., `app-config-k7t9m2p`). Kustomize also rewrites all references in Deployments, StatefulSets, DaemonSets, etc. to use the hashed name. When content changes, the hash changes, the Deployment spec changes, and Kubernetes triggers a rolling update.
- **One-liner** — Hash suffix = content-addressed naming = automatic rollout on any config change.

```bash
# Observe hash suffix in action
kubectl get configmap
# NAME                         DATA   AGE
# app-config-k7t9m2p           5      2d
# nginx-config-x4r2w8n         2      2d

# Change a literal value, then re-apply
kubectl apply -k overlays/prod/

# New ConfigMap with new hash is created
kubectl get configmap
# NAME                         DATA   AGE
# app-config-k7t9m2p           5      2d    ← old, no longer referenced
# app-config-def456xy           5      5s    ← new, Deployment updated to use this
# nginx-config-x4r2w8n         2      2d    ← unchanged (content didn't change)

# Rolling update is triggered automatically
kubectl rollout status deployment/prod-myapp
```

### Disabling Hash Suffix

- **Why it exists** — Some use cases require a stable, predictable ConfigMap name: external tools that reference the ConfigMap by name, manual deployments that don't use Kustomize, or situations where you manage rollouts separately. In these cases the hash suffix is a problem.
- **What it is** — Set `generatorOptions.disableNameSuffixHash: true` in `kustomization.yaml` to disable hash suffix for all generators, or use `options.disableNameSuffixHash: true` per-generator entry. The ConfigMap/Secret is created with the exact name declared, no hash appended.
- **One-liner** — `disableNameSuffixHash: true` creates a stable name but loses automatic rollout on config change.

```yaml
# kustomization.yaml — disable hash globally for all generators
generatorOptions:
  disableNameSuffixHash: true
  # Optional: add labels to all generated resources
  labels:
    generated-by: kustomize
  # Optional: add annotations to all generated resources
  annotations:
    note: hash-disabled

configMapGenerator:
  - name: app-config    # result: "app-config" (no hash)
    literals:
      - KEY=value

secretGenerator:
  - name: db-secret     # result: "db-secret" (no hash)
    literals:
      - password=secret
```

```yaml
# Per-generator disable (only this one has no hash)
configMapGenerator:
  - name: stable-config
    options:
      disableNameSuffixHash: true   # this one gets stable name
    literals:
      - KEY=value

  - name: app-config                # this one still gets hash suffix
    literals:
      - OTHER_KEY=value
```

### Environment-Specific Config with Generators

- **Why it exists** — Each environment (dev, staging, prod) needs different config values. Generators in overlays let you define per-environment config that gets merged into the overlay's final manifests without modifying the base.
- **What it is** — Place `configMapGenerator` and `secretGenerator` entries in each overlay's `kustomization.yaml`, not in the base. Use `behavior: replace` to override a base-defined ConfigMap, or `behavior: merge` to add keys to a base ConfigMap. Omitting `behavior` defaults to `create` (creates a new ConfigMap, errors if one already exists).
- **One-liner** — Generators in overlays produce env-specific config; use `behavior: replace` to override base config.

```yaml
# overlays/dev/kustomization.yaml
configMapGenerator:
  - name: app-config
    behavior: replace              # replace the base configmap entirely
    literals:
      - DATABASE_HOST=localhost:5432
      - DATABASE_NAME=dev_db
      - REDIS_URL=localhost:6379
      - LOG_LEVEL=DEBUG
      - ENABLE_PROFILING=true

secretGenerator:
  - name: app-secrets
    behavior: replace
    literals:
      - db_password=devpass
      - api_key=dev-key-12345
```

```yaml
# overlays/prod/kustomization.yaml
configMapGenerator:
  - name: app-config
    behavior: replace
    literals:
      - DATABASE_HOST=prod-db.internal
      - DATABASE_NAME=production
      - REDIS_URL=prod-redis.internal
      - LOG_LEVEL=ERROR
      - ENABLE_PROFILING=false
    files:
      - config-prod.toml

secretGenerator:
  - name: app-secrets
    behavior: replace
    envs:
      - secrets.env               # written by vault/sops at deploy time, gitignored
    # Never store real prod secrets as literals in kustomization.yaml
```

```yaml
# behavior options:
# create  — default: create new resource (errors if already exists from base)
# replace — replace the base resource entirely with overlay values
# merge   — add overlay keys to base resource (keeps base keys)

configMapGenerator:
  - name: app-config
    behavior: merge               # add these keys on top of base configmap
    literals:
      - EXTRA_KEY=overlay-value
```

# Troubleshooting

### ConfigMapGenerator creates multiple ConfigMaps with different hashes

- After a config change and re-apply, a new ConfigMap is created and the old one remains (it was referenced by previously running pods)
- The old ConfigMap is safe to delete once all pods have rolled over to the new one

```bash
kubectl get configmap
# app-config-abc123   (old, no longer referenced by any pod)
# app-config-def456   (new, in use)

# Clean up old one
kubectl delete configmap app-config-abc123
```

- This is intentional — it allows rollback (scale down new pods, scale up old pods with old ConfigMap)

### Pod not picking up config changes after re-apply

- Check if the Deployment rolled out: `kubectl rollout status deployment/myapp`
- If hash suffix is disabled (`disableNameSuffixHash: true`), changing config does NOT trigger automatic rollout
- Manually trigger rollout: `kubectl rollout restart deployment/myapp`
- If hash suffix is enabled, verify the Deployment references were updated: `kubectl kustomize overlays/prod/ | grep "configMapRef"`

### "ConfigMap already exists" error on apply

- This happens when `behavior` is omitted (defaults to `create`) but the ConfigMap already exists from a previous apply
- Use `behavior: replace` in overlay generators that override base config

```yaml
configMapGenerator:
  - name: app-config
    behavior: replace   # add this if getting "already exists" errors
    literals:
      - KEY=value
```

### Secret values not updating in running pods

- Pods mount Secret volumes or environment variables at startup — they don't hot-reload
- The hash suffix mechanism solves this: a new Secret hash → Deployment spec changes → rolling update starts new pods with new secret values
- If using `disableNameSuffixHash: true` for secrets, you must manually restart pods after secret changes: `kubectl rollout restart deployment/myapp`
