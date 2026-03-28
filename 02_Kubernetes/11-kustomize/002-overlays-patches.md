# Overlays and Patches

### Overview

**Why it exists** — Real applications run across multiple environments (dev, staging, prod) that differ in ways: replica counts, resource limits, environment variables, image tags, ingress hostnames, storage size. Without a system to handle these differences, teams either duplicate entire manifests (causing maintenance nightmares) or hardcode environment-specific values into base manifests (breaking reusability). Overlays and patches solve this by letting you define common base resources once, then layer environment-specific changes on top using plain YAML patches.

**What it is** — An overlay is a Kustomization that references a base Kustomization and applies patches. A patch is a partial YAML document that merges into (or modifies) an existing resource. Kustomize supports two patch types: Strategic Merge Patches (partial YAML that layers on top) and JSON 6902 Patches (precise add/replace/remove operations). Together, they let you express environment differences declaratively without duplicating manifests.

**One-liner** — Overlays = base + patches = environment-specific manifests from a single source of truth.

### Architecture

```text
Directory Structure (Base + Overlays Pattern):

k8s/
├── base/                               # Shared, single source of truth
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── kustomization.yaml
│       └── resources: [deployment.yaml, service.yaml, configmap.yaml]
│
└── overlays/                           # Environment-specific patches
    ├── dev/
    │   ├── kustomization.yaml
    │   │   ├── bases: [../../base]
    │   │   └── patches: [replicas-patch.yaml, image-patch.yaml]
    │   ├── replicas-patch.yaml
    │   ├── image-patch.yaml
    │   └── kustomization-patch.yaml (optional)
    │
    ├── staging/
    │   ├── kustomization.yaml
    │   └── ...patches...
    │
    └── prod/
        ├── kustomization.yaml
        └── ...patches...

Processing Flow:

kubectl apply -k overlays/prod/
    │
    ├─→ Load base resources (base/deployment.yaml, base/service.yaml, ...)
    │
    ├─→ Load prod patches (overlays/prod/replicas-patch.yaml, ...)
    │
    ├─→ Merge patches into base resources
    │
    └─→ Send transformed YAML to API Server
```

### Mental Model

Think of overlays as "layer-by-layer customization":

```text
Layer 0 (Base):
  deployment.yaml: 3 replicas, nginx:1.20, 256MB RAM, no resource limits

Layer 1 (Dev Overlay patches):
  + 1 replica (dev is small)
  + nginx:latest-dev (bleeding edge)
  + 128MB RAM (constrained dev environment)

Layer 2 (Prod Overlay patches):
  + 5 replicas (high availability)
  + nginx:1.25 (stable release)
  + 1GB RAM (production grade)
  + PodDisruptionBudget, HPA, priority class

Result: 3 completely different Deployments from 1 base + 3 overlays.
```

When you run `kubectl apply -k overlays/prod/`:
1. Read `overlays/prod/kustomization.yaml`
2. Load base from `../../base/`
3. Load patch files from `overlays/prod/`
4. Apply patches to base resources
5. Send result to API Server

Key insight: **The base is never modified.** Patches are applied on top, so you can re-use the same base for unlimited overlays.

### Core Building Blocks

### The Base Kustomization

**Why it exists** — The base is the single source of truth. All overlays reference it, so changes to base apply across all environments. Without a defined base, overlays become fragile and maintenance-heavy.

**What it is** — A directory with a `kustomization.yaml` and manifest files (deployment.yaml, service.yaml, etc.). The kustomization declares which manifests to include. Base kustomizations don't reference anything else — they're self-contained.

**One-liner** — Base = reusable YAML + kustomization that includes it.

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

# Include all manifests in base/
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - ingress.yaml

# Optional: global transformations applied to all overlays
commonLabels:
  app: myapp
  managed-by: kustomize
  managed-version: "1.0"

commonAnnotations:
  team: platform
  repo: https://github.com/myorg/k8s
```

Base manifest files are plain Kubernetes YAML:

```yaml
# base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3                     # base default (to be overridden in overlays)
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: nginx:1.20         # base default
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

### Overlay Structure and Inheritance

**Why it exists** — Each environment needs its own directory because it will have its own patches, and possibly its own config files or additional resources. Organizing overlays separately prevents confusion and makes it clear what's environment-specific.

**What it is** — A directory per environment with a `kustomization.yaml` that:
1. References the base with `resources: [../../base]`
2. Defines environment-specific patches
3. May include environment-specific resources (extra services, ingresses, etc.)

Overlays inherit all base resources, labels, annotations, and transformations.

**One-liner** — Each overlay = reference base + add patches + optionally add env-specific resources.

Example dev overlay:

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Reference the base — all resources are inherited
resources:
  - ../../base
  # Optional: add extra resources only in dev (e.g., test pods, debug services)
  - debug-service.yaml

# Dev-specific naming (so dev and prod can coexist in same cluster)
namePrefix: dev-

# Dev-specific namespace
namespace: dev

# Dev-specific patches (defined below)
patches:
  - path: replicas-patch.yaml
  - path: image-patch.yaml
  - path: resources-patch.yaml

# Dev-specific labels (in addition to base labels)
commonLabels:
  env: dev

# Dev-specific image overrides
images:
  - name: nginx
    newTag: "latest"
    # Can also change the image name:
    # newName: dev-nginx

# Dev-specific config
configMapGenerator:
  - name: app-config
    behavior: replace              # replace the base configmap
    literals:
      - DATABASE_HOST=localhost
      - LOG_LEVEL=DEBUG
      - ENABLE_PROFILING=true

# Dev-specific resource limits (smaller for dev)
replacements:
  - source:
      kind: ConfigMap
      name: app-config
      fieldPath: data.database_host
    targets:
      - select:
          kind: Deployment
        fieldPath: spec.template.spec.containers[0].env[0].value
```

Example prod overlay:

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base
  # Prod-specific resources
  - pod-disruption-budget.yaml
  - horizontal-pod-autoscaler.yaml
  - network-policy.yaml

namePrefix: prod-
namespace: prod

patches:
  - path: replicas-patch.yaml
  - path: image-patch.yaml
  - path: resources-patch.yaml
  - path: affinity-patch.yaml

commonLabels:
  env: production

images:
  - name: nginx
    newTag: "1.25"                 # stable release for prod

# Prod config (env-specific values)
configMapGenerator:
  - name: app-config
    behavior: replace
    literals:
      - DATABASE_HOST=prod.db.corp.internal
      - LOG_LEVEL=WARNING
      - ENABLE_PROFILING=false

# Prod secrets (in real life, these come from vault/sealed-secrets, not literals)
secretGenerator:
  - name: db-credentials
    behavior: replace
    literals:
      - username=produser
      - password=supersecret
```

### Patch Types and Examples

**Why it exists** — Different changes need different patch types. Some changes are simple (just change replicas), others are complex (add a new field deep in the structure). Kustomize supports two patch formats for different use cases.

**What it is** — Kustomize supports two patch types:

1. **Strategic Merge Patch** — Partial YAML that merges into a full resource. Used for most cases because they're readable and straightforward.
2. **JSON 6902 Patch** — RFC 6902 JSON Patch operations (add, replace, remove, move, copy, test). Used for precise changes at specific paths, especially when merging would be ambiguous.

**One-liner** — Strategic Merge = partial YAML that layers; JSON 6902 = precise operations.

#### Strategic Merge Patch (Recommended)

A Strategic Merge Patch is a partial YAML document that Kustomize merges into the full resource. You only specify the fields you want to change.

```yaml
# overlays/prod/replicas-patch.yaml
# This is a partial Deployment YAML (only the fields to change)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 5                       # change replicas from base (3) to 5
```

```yaml
# overlays/prod/image-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx:1.25          # change image tag
```

```yaml
# overlays/prod/resources-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          requests:
            memory: "512Mi"         # increase from base (256Mi)
            cpu: "250m"             # increase from base (100m)
          limits:
            memory: "1Gi"           # increase from base (512Mi)
            cpu: "1"                # increase from base (500m)
```

How to declare Strategic Merge Patches in kustomization.yaml:

```yaml
# overlays/prod/kustomization.yaml
patches:
  - path: replicas-patch.yaml       # applied to all resources named myapp
  - path: image-patch.yaml
  - path: resources-patch.yaml
```

When Kustomize merges a Strategic Merge Patch:
1. Find the resource matching the patch's `kind` and `metadata.name`
2. Merge the patch on top of the resource (field by field)
3. Result: base resource with patched fields

Example merge:

```yaml
# Base (base/deployment.yaml)
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: app
        image: nginx:1.20
        resources:
          requests:
            memory: "256Mi"

# Patch (overlays/prod/resources-patch.yaml)
spec:
  template:
    spec:
      containers:
      - name: app
        resources:
          limits:
            memory: "1Gi"

# Result (after merge)
spec:
  replicas: 3                       # unchanged (not in patch)
  template:
    spec:
      containers:
      - name: app
        image: nginx:1.20           # unchanged (not in patch)
        resources:
          requests:                 # unchanged (not in patch)
            memory: "256Mi"
          limits:                   # added by patch
            memory: "1Gi"
```

#### JSON 6902 Patch (Precise Changes)

JSON 6902 Patch uses RFC 6902 operations for precise, unambiguous changes. Use this when you need to:
- Add a new array element
- Remove a field
- Replace at a specific array index
- Make changes that would be ambiguous with Strategic Merge

```yaml
# overlays/prod/kustomization.yaml with JSON 6902 patches
patches:
  - target:
      kind: Deployment
      name: myapp
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 5

      - op: replace
        path: /spec/template/spec/containers/0/image
        value: nginx:1.25

      - op: add
        path: /spec/template/spec/affinity
        value:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                  - key: app
                    operator: In
                    values:
                    - myapp
                topologyKey: kubernetes.io/hostname

      - op: remove
        path: /spec/template/spec/containers/0/resources/limits/cpu
```

JSON 6902 operations:

| Operation | Purpose | Example |
|-----------|---------|---------|
| `replace` | Change value at path | `{op: replace, path: /spec/replicas, value: 5}` |
| `add` | Add new field or array element | `{op: add, path: /spec/affinity, value: {...}}` |
| `remove` | Delete field or array element | `{op: remove, path: /spec/limits/cpu}` |
| `move` | Move field to new path | `{op: move, from: /a, path: /b}` |
| `copy` | Copy field to new path | `{op: copy, from: /a, path: /b}` |
| `test` | Assert value equals (optional, fails patch if false) | `{op: test, path: /spec/replicas, value: 3}` |

### Environment-Specific ConfigMaps and Secrets

**Why it exists** — Every environment needs different configuration: dev points to localhost, prod to the production database. Storing these in overlays ensures config matches the environment, and they're version-controlled in Git (with secrets managed by tools like sealed-secrets).

**What it is** — ConfigMaps and Secrets are generated per-overlay, not in base. The `configMapGenerator` and `secretGenerator` in each overlay's kustomization creates environment-specific config that gets merged into the manifests.

**One-liner** — Generate env-specific config in overlays, not base.

Dev config example:

```yaml
# overlays/dev/kustomization.yaml
configMapGenerator:
  - name: app-config
    literals:
      - DATABASE_HOST=localhost:5432
      - DATABASE_NAME=dev_db
      - REDIS_URL=localhost:6379
      - LOG_LEVEL=DEBUG
      - API_TIMEOUT=30
      - FEATURE_FLAGS=debug-enabled,new-ui-beta
    files:
      - config.toml                 # include whole file as config data

secretGenerator:
  - name: app-secrets
    literals:
      - db_password=devpass
      - api_key=dev-key-12345
```

Prod config example:

```yaml
# overlays/prod/kustomization.yaml
configMapGenerator:
  - name: app-config
    literals:
      - DATABASE_HOST=prod-db.internal
      - DATABASE_NAME=production
      - REDIS_URL=prod-redis.internal
      - LOG_LEVEL=ERROR
      - API_TIMEOUT=60
      - FEATURE_FLAGS=
    files:
      - config-prod.toml

secretGenerator:
  - name: app-secrets
    literals:
      - key=value   # placeholder — in production use sealed-secrets, external-secrets, or sops
    # Never store real secrets in kustomization.yaml files
```

How deployments use the generated config:

```yaml
# base/deployment.yaml (references configmap and secret)
spec:
  template:
    spec:
      containers:
      - name: app
        image: nginx:1.20
        env:
        - name: DATABASE_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DATABASE_HOST
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: db_password
```

When you apply `kubectl apply -k overlays/prod/`:
1. Kustomize generates `app-config` ConfigMap with prod values
2. Kustomize generates `app-secrets` Secret with prod values
3. Deployment references these ConfigMaps/Secrets
4. Pods get prod configuration from generated resources

### Comparison Table: When to Use Each Patch Type

| Aspect | Strategic Merge | JSON 6902 |
|--------|-----------------|-----------|
| **Readability** | High (looks like YAML) | Low (verbose operations) |
| **Ease of use** | Easy (copy structure) | Complex (must know paths) |
| **Array handling** | Automatic merging | Precise index control |
| **Remove fields** | Difficult | Easy (`op: remove`) |
| **Adding nested objects** | Easy | Easy |
| **Best for** | Simple changes (replicas, image tags) | Complex, precise changes |
| **Learning curve** | Low | High |

### Troubleshooting

### Patch not being applied

1. Check that the resource name in the patch matches the actual resource name.
   ```yaml
   # Base resource: metadata.name: myapp
   # Patch metadata.name: must also be myapp (not app, not my-app)

   # ❌ Wrong: patch for different resource
   metadata:
     name: app                      # doesn't match base name "myapp"

   # ✅ Right: patch for correct resource
   metadata:
     name: myapp                    # matches base
   ```

2. Verify the patch file path in `kustomization.yaml` is correct.
   ```bash
   # Test: does the file exist?
   ls -la overlays/prod/replicas-patch.yaml

   # In kustomization.yaml, is the path relative to the directory?
   patches:
     - path: replicas-patch.yaml    # correct: relative path
     - path: ./replicas-patch.yaml  # also correct
     - path: overlays/prod/replicas-patch.yaml  # wrong: absolute from root
   ```

3. Render the output and search for your change.
   ```bash
   kubectl kustomize overlays/prod/ > output.yaml
   grep -A5 "replicas:" output.yaml    # did replicas change?
   ```

### `kustomize` command not found

`kubectl kustomize` is built-in to kubectl, but the standalone `kustomize` CLI may not be installed.

```bash
# Use kubectl kustomize (built-in, always available)
kubectl kustomize overlays/prod/

# Or install standalone kustomize (optional)
# https://kustomize.io/installation/
```

### JSON 6902 patch returns "doc is missing path"

The path in the patch doesn't exist in the resource.

```yaml
# ❌ Wrong: path doesn't exist
- op: replace
  path: /spec/affinity/nodeAffinity   # this path doesn't exist in base

# ✅ Right: use op: add for new fields
- op: add
  path: /spec/affinity
  value: {nodeAffinity: {...}}
```

JSON 6902 paths are strict. If you're adding a completely new field, use `op: add`, not `op: replace`.

### Multiple patches conflicting

If multiple patches modify the same field, the last one wins (patches are applied in order).

```yaml
# overlays/prod/kustomization.yaml
patches:
  - path: replicas-patch.yaml       # sets replicas: 5
  - path: another-patch.yaml        # also sets replicas: 3 (overwrites)

# Result: replicas will be 3 (from another-patch.yaml)
```

Solution: Combine conflicting patches into one file.

### ConfigMapGenerator creates multiple ConfigMaps with different hashes

When you change config and reapply, Kustomize creates a new ConfigMap with a new hash (to force pod restarts). The old ConfigMap remains.

```bash
# You'll see both:
kubectl get configmap
# app-config-abc123       (old, no longer used)
# app-config-def456       (new, in use by pods)

# Cleanup old ones:
kubectl delete configmap app-config-abc123
```

This is intentional — it enables safe rollout (pods get new config, old ConfigMap is kept for rollback).

### "image name must not be empty"

The `images` override's `name` field doesn't match the image in the deployment.

```yaml
# In deployment.yaml: image: nginx:1.20
# In kustomization.yaml:
images:
  - name: nginx                # ✅ correct: just the image name
    newTag: "1.25"

images:
  - name: "nginx:1.20"        # ❌ wrong: includes the tag
    newTag: "1.25"

images:
  - name: ""                  # ❌ wrong: empty name
    newTag: "1.25"
```

The `name` field must be the image name only (without tag or registry prefix, unless those are part of the original image name).
