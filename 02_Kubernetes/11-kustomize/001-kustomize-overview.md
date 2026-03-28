# Kustomize Overview

# Overview

- **Why it exists** — Kubernetes YAML files are repetitive across environments. Teams use templating to avoid duplication, but templating languages (Helm's Go templates, Jinja2, etc.) add complexity and require learning new syntax. Kustomize solves this by letting you customize Kubernetes YAML without a templating language — just YAML patches on top of base YAML. It's plain Kubernetes manifests + declarative transformations, built into `kubectl` since version 1.14.
- **What it is** — Kustomize is a declarative YAML transformation tool. You write base manifests and a `kustomization.yaml` file that declares what to include and how to transform it (rename resources, add labels, override images, patch fields). Running `kubectl apply -k` applies the transformed result. It's pure YAML — no Go templates, no custom syntax, no new language to learn.
- **One-liner** — Kustomize = base YAML + patches + transformations = customized manifests without a templating language.

# Architecture

```text
kustomization.yaml → kustomize build → kubectl apply

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

```text
Kustomize vs Helm:

Kustomize:                          Helm:
─────────────────────────────────────────────────────
Plain YAML + patches                Go templates + variables
No new syntax                       Template language required
Stateless (no tracking)             Stateful (release tracking)
Git-first (version control)         Package distribution focus
Lightweight                         Full package manager
Composition via overlays            Composition via dependencies
```

# Mental Model

- Base resources + transformations = final manifests
- Think of Kustomize as "layered YAML assembly"

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
      └── patches: [replicas→5, image→1.25]

Result: Final manifests specific to that environment
```

- When you run `kubectl apply -k overlays/prod/`:
  - Load base manifests from `base/`
  - Apply patches from `overlays/prod/`
  - Send transformed result to API Server
- Each overlay is independent — `overlays/dev` and `overlays/prod` both reference the same base but apply different transformations

# Core Building Blocks

### kustomization.yaml Structure

- **Why it exists** — The `kustomization.yaml` file is the declarative manifest for transformations. Instead of writing scripts or imperative commands, you describe what to include and how to transform it.
- **What it is** — A YAML file (must be named exactly `kustomization.yaml`) that declares: which resources to include (`resources`), global naming transformations (`namePrefix`, `nameSuffix`, `namespace`), global labels/annotations to add (`commonLabels`, `commonAnnotations`), image overrides (`images`), patches to apply (`patches`), and generated content (`configMapGenerator`, `secretGenerator`).
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

# Generate ConfigMaps from files/literals
configMapGenerator:
  - name: app-config
    literals:
      - DATABASE_HOST=prod.db.example.com
      - LOG_LEVEL=INFO
    files:
      - config.json

# Generate Secrets
secretGenerator:
  - name: db-secret
    literals:
      - username=admin
      - password=secretpass
```

### kubectl kustomize Commands

- **Why it exists** — Kustomize integrates with `kubectl`, so you don't need to learn new CLI tools. All kubectl commands work with the `-k` flag to specify a Kustomization.
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
kubectl kustomize overlays/prod/ | kubectl apply -f -   # pipe through other tools
kubectl kustomize overlays/prod/ | jq '.items[].metadata.name'

# Apply with server-side dry-run (safest way to preview)
kubectl apply -k ./ --dry-run=server
```

### namePrefix / nameSuffix / commonLabels Transformers

- **Why it exists** — When deploying the same base to multiple environments or clusters, resources need unique names and consistent labels so they don't collide and can be identified by environment.
- **What it is** — Global transformers declared directly in `kustomization.yaml` that modify all resources at once: `namePrefix` prepends a string to every resource name, `nameSuffix` appends a string, `commonLabels` merges a label set into every resource's metadata and selector.
- **One-liner** — Transformers apply naming and labeling changes across all resources in one declaration.

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

# Prefix every resource name with "prod-"
# e.g., "myapp" → "prod-myapp"
namePrefix: prod-

# Append "-v2" to every resource name (optional)
# e.g., "prod-myapp" → "prod-myapp-v2"
# nameSuffix: -v2

# Add these labels to every resource (metadata + pod template selectors)
commonLabels:
  env: production
  team: platform
  version: "1.25"

# Add these annotations to every resource
commonAnnotations:
  managed-by: kustomize
  cost-center: "engineering"
```

```yaml
# overlays/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

namePrefix: dev-       # "myapp" → "dev-myapp"
namespace: dev         # all resources go to dev namespace

commonLabels:
  env: development
```

# Troubleshooting

### `kubectl apply -k` returns "error: must be exactly one"

- The directory doesn't have a `kustomization.yaml` file (or it's named wrong)
- Check the directory path: `ls -la overlays/prod/` — does it have `kustomization.yaml`?
- Verify the exact filename: must be `kustomization.yaml` (not `kustomization.yml`, not `Kustomization.yaml`)
- Move up the directory tree to find the right one: `find . -name kustomization.yaml`

### Image override not working

- The `images.name` must match the image name in the deployment (not the full image with tag)

```yaml
# In deployment.yaml: image: nginx:1.20
images:
  - name: nginx          # must match just the image name, not "nginx:1.20"
    newTag: "1.25"
```

- If using a private registry, the image name must match exactly:

```yaml
images:
  - name: myregistry.azurecr.io/myapp   # match exact name
    newTag: "2.0"
```

- Test it: `kubectl kustomize ./ | grep image:` — see what image is in the output

### "Kustomization cannot reference itself"

- Usually happens when a kustomization tries to include itself as a resource

```yaml
# Wrong: includes itself
resources:
  - ./
  - deployment.yaml

# Right: includes sibling resources
resources:
  - deployment.yaml
  - service.yaml
```

### namePrefix applied but pods still collide across environments

- Verify `namespace` is also set per overlay — name prefix alone doesn't isolate namespaces
- Check that selectors were updated: `kubectl kustomize overlays/dev/ | grep -A5 "selector:"`
- `commonLabels` updates selectors automatically; manually written selectors in patches may not update
