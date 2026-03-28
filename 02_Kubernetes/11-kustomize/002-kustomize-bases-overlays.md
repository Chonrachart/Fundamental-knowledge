# Kustomize Bases and Overlays

# Overview

- **Why it exists** — Real environments (dev, staging, prod) differ in small ways: replica counts, resource limits, environment variables, image tags, ingress hostnames. Without a system to handle these differences, teams either duplicate entire manifests (causing maintenance nightmares) or hardcode environment-specific values into base manifests (breaking reusability). The base/overlay pattern solves this by defining common resources once and layering environment-specific changes on top.
- **What it is** — An overlay is a Kustomization that references a base Kustomization and applies patches or overrides. The base is the single source of truth shared across all environments. Each overlay directory contains its own `kustomization.yaml` that inherits all base resources and then customizes them without modifying the base.
- **One-liner** — Base = single source of truth; overlays = environment-specific customizations layered on top without editing the base.

# Architecture

```text
Base + Overlay directory tree:

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
    │   │   ├── resources: [../../base]
    │   │   └── patches: [replicas-patch.yaml, image-patch.yaml]
    │   ├── replicas-patch.yaml
    │   └── image-patch.yaml
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

# Mental Model

- Overlay references base, adds/overrides without editing base
- Think of it as "layer-by-layer customization"

```text
Layer 0 (Base):
  deployment.yaml: 3 replicas, nginx:1.20, 256MB RAM

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

- Key insight: the base is never modified — patches are applied on top, so you can re-use the same base for unlimited overlays

# Core Building Blocks

### Base Layout

- **Why it exists** — The base is the single source of truth. All overlays reference it, so changes to the base apply across all environments. Without a defined base, overlays become fragile and maintenance-heavy.
- **What it is** — A directory with a `kustomization.yaml` and manifest files (deployment.yaml, service.yaml, etc.). The kustomization declares which manifests to include. Base kustomizations are self-contained and don't reference other bases.
- **One-liner** — Base = reusable YAML manifests + a kustomization that includes them.

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - ingress.yaml

# Optional: global transformations applied through all overlays
commonLabels:
  app: myapp
  managed-by: kustomize
  managed-version: "1.0"

commonAnnotations:
  team: platform
  repo: https://github.com/myorg/k8s
```

```yaml
# base/deployment.yaml — plain Kubernetes YAML, no special syntax
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

### Overlay Layout

- **Why it exists** — Each environment needs its own directory because it will have its own patches and possibly extra resources. Organizing overlays separately prevents confusion and makes it clear what is environment-specific.
- **What it is** — A directory per environment with a `kustomization.yaml` that: references the base with `resources: [../../base]`, defines environment-specific patches, and may include environment-specific extra resources (additional services, ingresses, etc.).
- **One-liner** — Each overlay = reference base + add patches + optionally add env-specific resources.

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Reference the base — all resources are inherited
resources:
  - ../../base
  # Optional: add extra resources only in dev
  - debug-service.yaml

namePrefix: dev-
namespace: dev

patches:
  - path: replicas-patch.yaml
  - path: image-patch.yaml
  - path: resources-patch.yaml

commonLabels:
  env: dev

images:
  - name: nginx
    newTag: "latest"
```

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base
  # Prod-specific extra resources
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
```

### Overlay Inheritance

- **Why it exists** — Overlays inherit everything from the base automatically. This means base-level labels, annotations, and namespace settings flow through to all overlays without repeating them, reducing duplication.
- **What it is** — When an overlay lists `resources: [../../base]`, Kustomize loads all resources declared in the base `kustomization.yaml`, then applies the overlay's own transformations on top. The overlay can override any base setting and can also add new resources not present in the base.
- **One-liner** — Overlay inherits all base resources, labels, and annotations, then stacks its own changes on top.

```bash
# Dry run to see what each overlay produces
kubectl kustomize overlays/dev/   # shows dev-specific YAML
kubectl kustomize overlays/prod/  # shows prod-specific YAML

# Apply dev
kubectl apply -k overlays/dev/
kubectl diff -k overlays/dev/

# Apply prod (same base, different patches)
kubectl apply -k overlays/prod/
kubectl diff -k overlays/prod/

# Each overlay is independent — dev changes don't affect prod
```

### Multi-Environment Pattern

- **Why it exists** — Most teams deploy to at least three environments. Having a standard directory layout and workflow makes it easy for any team member to understand where each environment's config lives and how to apply changes.
- **What it is** — A convention: one `base/` directory shared by all environments, one `overlays/<env>/` directory per environment. Each overlay declares its own namespace, namePrefix, image tags, replica counts, and resource limits. This gives full isolation while sharing 90% of the YAML.
- **One-liner** — One base, N overlays = N independent environment configs from one source of truth.

```text
k8s/
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
│
└── overlays/
    ├── dev/
    │   ├── kustomization.yaml    # namePrefix: dev-, namespace: dev, 1 replica
    │   └── replicas-patch.yaml
    │
    ├── staging/
    │   ├── kustomization.yaml    # namePrefix: staging-, namespace: staging, 2 replicas
    │   └── replicas-patch.yaml
    │
    └── prod/
        ├── kustomization.yaml    # namePrefix: prod-, namespace: prod, 5 replicas
        ├── replicas-patch.yaml
        ├── pod-disruption-budget.yaml
        └── horizontal-pod-autoscaler.yaml
```

```yaml
# overlays/staging/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namePrefix: staging-
namespace: staging

images:
  - name: nginx
    newTag: "1.24-rc"     # release candidate for staging validation

commonLabels:
  env: staging

patches:
  - path: replicas-patch.yaml

configMapGenerator:
  - name: app-config
    behavior: replace
    literals:
      - DATABASE_HOST=staging.db.internal
      - LOG_LEVEL=INFO
```

# Troubleshooting

### Overlay not inheriting base resources

1. Check that the `resources` path in the overlay `kustomization.yaml` correctly points to base
2. Path is relative to the overlay directory, so `../../base` means "go up two levels, then into base/"
3. Verify: `kubectl kustomize overlays/dev/` — if base resources are missing, the path is wrong

```yaml
# Wrong: absolute path from repo root
resources:
  - k8s/base

# Right: relative path from the overlay directory
resources:
  - ../../base
```

### Changes to base not appearing in overlay output

1. Confirm you're re-running `kubectl kustomize` after editing base files
2. Check that the base `kustomization.yaml` includes the modified file in its `resources` list
3. Render and inspect: `kubectl kustomize overlays/prod/ > /tmp/out.yaml && grep -A20 "kind: Deployment" /tmp/out.yaml`

### Overlay-specific resources (PDB, HPA) not being applied

1. These files must be listed in the overlay `kustomization.yaml` under `resources`, not just present in the directory
2. Kustomize only processes files explicitly declared in `kustomization.yaml`

```yaml
# overlays/prod/kustomization.yaml
resources:
  - ../../base
  - pod-disruption-budget.yaml    # must be listed here explicitly
  - horizontal-pod-autoscaler.yaml
```

### namePrefix collision between environments in same cluster

1. Each overlay should set both `namePrefix` and `namespace` to fully isolate environments
2. `namePrefix` alone is not enough if both overlays target the same namespace
3. Verify namespaces are different: `kubectl kustomize overlays/dev/ | grep "namespace:"` vs `kubectl kustomize overlays/prod/ | grep "namespace:"`
