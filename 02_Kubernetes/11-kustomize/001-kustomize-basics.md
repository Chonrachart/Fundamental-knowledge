# Kustomize Basics

# Overview

- **Why it exists** — Kubernetes YAML files are repetitive across environments. Teams use templating to avoid duplication, but templating languages (Helm's Go templates, Jinja2, etc.) add complexity and require learning new syntax. Kustomize solves this by letting you customize Kubernetes YAML without a templating language — just YAML patches on top of base YAML. It's plain Kubernetes manifests + declarative transformations, built into `kubectl` since version 1.14.

- **What it is** — Kustomize is a declarative YAML transformation tool. You write base manifests and a `kustomization.yaml` file that declares what to include and how to transform it (rename resources, add labels, override images, patch fields). Running `kubectl apply -k` applies the transformed result. It's pure YAML — no Go templates, no custom syntax, no new language to learn.

- **One-liner** — Kustomize = base YAML + patches + transformations = customized manifests without a templating language.

# Architecture

```text
Declarative YAML Transformation:

Base Manifests (deployment.yaml, service.yaml, ...)
       │
       │ referenced in
       ▼
kustomization.yaml
  ├── resources: [deployment.yaml, service.yaml]
  ├── namePrefix: "prod-"
  ├── commonLabels: {app: myapp}
  ├── images: [{name: nginx, newTag: "1.25"}]
  └── patches: [patch.yaml, ...]
       │
       │ Kustomize processes:
       │  1. Load base resources
       │  2. Apply naming (prefix/suffix)
       │  3. Merge labels/annotations
       │  4. Override images
       │  5. Apply patches
       ▼
kubectl apply -k
       │
       ▼
Final Transformed YAML
(ready for API Server)
```

Kustomize vs Helm:

```text
Kustomize:                          Helm:
─────────────────────────────────────────────────────
Plain YAML + patches                Go templates + variables
No new syntax                        Template language required
Stateless (no tracking)              Stateful (release tracking)
Git-first (version control)          Package distribution focus
Lightweight                          Full package manager
Composition via overlays             Composition via dependencies
```

# Mental Model

Think of Kustomize as "layered YAML assembly":

```text
Layer 1: Base (shared, re-usable)
  base/
  ├── deployment.yaml (3 replicas, image: nginx:1.20)
  ├── service.yaml
  └── kustomization.yaml

Layer 2: Overlay (environment-specific patches on top)
  overlays/prod/
  └── kustomization.yaml
      ├── references: base
      └── patches: [replicas→5, image→1.25, replicas→3]

Result: Final manifests specific to that environment
```

When you run `kubectl apply -k overlays/prod/`:
1. Load base manifests from `base/`
2. Apply patches from `overlays/prod/`
3. Send transformed result to API Server

Each overlay is independent — `overlays/dev` and `overlays/prod` both reference the same base but apply different transformations.

# Core Building Blocks

### kustomization.yaml Structure

- **Why it exists** — The `kustomization.yaml` file is the declarative manifest for transformations. Instead of writing scripts or imperative commands, you describe what to include and how to transform it.

- **What it is** — A YAML file (must be named exactly `kustomization.yaml`) that declares:
- Which resources to include (`resources`)
- Global naming transformations (`namePrefix`, `nameSuffix`, `namespace`)
- Global labels/annotations to add (`commonLabels`, `commonAnnotations`)
- Image overrides (`images`)
- Patches to apply (`patches`)
- Generated content (`configMapGenerator`, `secretGenerator`)

- **One-liner** — `kustomization.yaml` is the recipe for transforming base YAML files.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

# Include these base resources
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

# Global transformations (apply to all resources)
namePrefix: prod-           # prepend to resource names
nameSuffix: -stable         # append to resource names
namespace: prod-ns          # override namespace for all resources

commonLabels:               # add these labels to all resources
  app: myapp
  env: production
  team: platform

commonAnnotations:          # add these annotations to all resources
  managed-by: kustomize
  deployed-at: "2025-01-15"

# Override container images across all resources
images:
  - name: nginx             # original image name (from manifest)
    newName: custom-nginx   # replace with this image name (optional)
    newTag: "1.25"          # replace tag with this

# Apply patches to specific resources
patches:
  - path: replica-patch.yaml
    target:
      kind: Deployment

# Generate ConfigMaps from files/literals (creates ConfigMap resources)
configMapGenerator:
  - name: app-config
    literals:
      - DATABASE_HOST=prod.db.example.com
      - LOG_LEVEL=INFO
    files:
      - config.json         # include contents of config.json as data

# Generate Secrets (same structure as configMapGenerator)
secretGenerator:
  - name: db-secret
    literals:
      - username=admin
      - password=secretpass

# Replace specific fields (JSON 6902 patches for precise updates)
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

### Commands: How to Use Kustomize

- **Why it exists** — Kustomize integrates with `kubectl`, so you don't learn new CLI tools. All the kubectl commands work with `-k` flag to specify a Kustomization.

- **What it is** — `kubectl` has built-in Kustomize support. You can apply, preview, diff, and delete using the same `kubectl` commands you know, but pointing to a directory with `kustomization.yaml` instead of a single file.

- **One-liner** — Use `kubectl -k` (with kustomization.yaml) instead of `kubectl -f` (with single files).

```bash
# Apply a kustomization (create or update resources)
kubectl apply -k ./                           # apply kustomization in current dir
kubectl apply -k overlays/prod/               # apply a specific overlay
kubectl apply -k https://github.com/.../k8s/  # apply from remote URL

# Render output (dry run — shows transformed YAML, doesn't apply)
kubectl kustomize ./                          # print final YAML to stdout
kubectl kustomize overlays/prod/ > output.yaml # save to file

# Preview changes before applying (shows diff vs current state)
kubectl diff -k ./
kubectl diff -k overlays/prod/

# Delete resources (using the same kustomization)
kubectl delete -k ./
kubectl delete -k overlays/prod/

# Verify kustomization is valid (catches syntax errors)
kubectl kustomize ./  # if this prints valid YAML, the kustomization is correct

# Combine with other tools
kubectl kustomize overlays/prod/ | kubectl apply -f -    # pipe through other tools
kubectl kustomize overlays/prod/ | jq '.items[].metadata.name'  # inspect the output

# Apply with server-side dry-run (safest way to preview)
kubectl apply -k ./ --dry-run=server
```

### Base and Overlay Pattern

- **Why it exists** — Real environments (dev, staging, prod) differ in small ways: replicas, image tags, resource limits, DNS names. Copying entire manifests creates duplication. Overlays solve this: one shared base + environment-specific patches on top.

- **What it is** — A directory structure:
- `base/` — shared, re-usable manifests and a kustomization that includes them
- `overlays/[env]/` — environment-specific kustomizations that reference base and apply patches

Each overlay references the base, inherits all its resources, then applies environment-specific transformations. This avoids duplicating 90% of the YAML.

- **One-liner** — Base = common resources; overlays = environment-specific patches on top.

Directory structure:

```text
k8s/
├── base/                          # Shared, re-usable
│   ├── deployment.yaml            # Base deployment (3 replicas, nginx:1.20)
│   ├── service.yaml               # Base service
│   ├── configmap.yaml
│   └── kustomization.yaml         # Base kustomization
│       └── resources: [deployment.yaml, service.yaml, configmap.yaml]
│
└── overlays/                       # Environment-specific
    ├── dev/
    │   ├── kustomization.yaml     # references ../../base, overrides for dev
    │   └── patches/
    │       ├── replicas-patch.yaml
    │       └── image-patch.yaml
    │
    ├── staging/
    │   ├── kustomization.yaml
    │   └── patches/
    │       └── ...
    │
    └── prod/
        ├── kustomization.yaml     # references ../../base, overrides for prod
        └── patches/
            └── ...
```

Example base kustomization:

```yaml
# base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: default

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

commonLabels:
  app: myapp
  managed-by: kustomize
```

Example overlay kustomization (dev):

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Reference the shared base
resources:
  - ../../base

# Environment-specific overrides
namePrefix: dev-
namespace: dev

# Override image tag for dev
images:
  - name: nginx
    newTag: "1.20-dev"

# Patch replicas down for dev (save resources)
patches:
  - path: replicas-patch.yaml

commonLabels:
  env: development
```

Example overlay kustomization (prod):

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namePrefix: prod-
namespace: prod

# Override image tag for prod (use stable release)
images:
  - name: nginx
    newTag: "1.25"

# Patch replicas up for prod (high availability)
patches:
  - path: replicas-patch.yaml

# Override resource limits for prod (more generous)
commonLabels:
  env: production
```

Using overlays:

```bash
# Dry run to see what will be applied
kubectl kustomize overlays/dev/   # shows dev-specific YAML
kubectl kustomize overlays/prod/  # shows prod-specific YAML

# Apply dev
kubectl apply -k overlays/dev/
kubectl diff -k overlays/dev/

# Apply prod (same base, different patches)
kubectl apply -k overlays/prod/
kubectl diff -k overlays/prod/

# Each overlay is independent
# Dev changes don't affect prod
```

### Comparison Table

| Aspect | Kustomize | Helm | Plain kubectl |
|--------|-----------|------|--------------|
| **Syntax** | YAML patches + transformations | Go templates + values | Static YAML |
| **Learning curve** | Low (just YAML) | High (template language) | Very low (no tools) |
| **Reusability** | Overlays for environments | Charts for packages | Copy-paste manifests |
| **Customization** | Strategic merges, JSON patches | Variable substitution | Manual edits |
| **Package sharing** | Not designed for it | Central feature | Not supported |
| **State tracking** | None (stateless) | Tracks releases (stateful) | None |
| **Good for** | Internal tools, multi-env | Shared software (operators) | Simple, static manifests |
| **Complexity** | Medium (patches, overlays) | High (templating, state) | Low (no abstraction) |

# Troubleshooting

### `kubectl apply -k` returns "error: must be exactly one"

The directory doesn't have a `kustomization.yaml` file (or it's named wrong).

1. Check the directory path: `ls -la overlays/prod/` — does it have `kustomization.yaml`?
2. Verify the exact filename: must be `kustomization.yaml` (not `kustomization.yml`, not `Kustomization.yaml`).
3. Move up the directory tree to find the right one: `find . -name kustomization.yaml`.

### Patches not being applied

1. Check that `patches` section references the correct file: `path: replicas-patch.yaml` must match the actual filename.
2. Verify `target` matches the resource being patched — if patching a Deployment named `app`, the target `kind: Deployment` must be correct.
3. Test with dry run: `kubectl kustomize ./` outputs the final YAML — if patch isn't in output, patch didn't apply.

```bash
# Test patches
kubectl kustomize overlays/prod/  # inspect output
grep -A5 "replicas:"              # search for the patched field
```

### Image override not working

1. The `images.name` must match the image name in the deployment (not the full image with tag).
   ```yaml
   # In deployment.yaml: image: nginx:1.20
   # In kustomization.yaml:
   images:
     - name: nginx          # must match just the image name
       newTag: "1.25"       # replace tag
   ```

2. If using a private registry, the image name must match exactly:
   ```yaml
   images:
     - name: myregistry.azurecr.io/myapp   # match exact name
       newTag: "2.0"
   ```

3. Test it: `kubectl kustomize ./ | grep image:` — see what image is in the output.

### "Kustomization cannot reference itself"

Usually happens when a kustomization tries to include itself as a resource.

1. Check your `resources:` section — don't include `.` or `./` (that would be circular).
2. Example error cause:
   ```yaml
   # ❌ Wrong: includes itself
   resources:
     - ./
     - deployment.yaml

   # ✅ Right: includes sibling resources
   resources:
     - deployment.yaml
     - service.yaml
   ```

### ConfigMapGenerator creates ConfigMap with hash suffix

Kustomize automatically appends a hash to generated ConfigMaps (e.g., `myconfig-a1b2c3d4`) to force pod restarts when the config changes.

1. This is intentional — it ensures pods use new config when it changes.
2. If you don't want the hash, use a static ConfigMap instead of `configMapGenerator`.
3. Reference the ConfigMap by prefix (without hash):
   ```bash
   kubectl get configmap  # see the hashed name
   kubectl describe configmap myconfig  # still works (prefix match)
   ```
