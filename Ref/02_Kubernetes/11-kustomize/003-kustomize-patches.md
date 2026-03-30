# Kustomize Patches

# Overview

- **Why it exists** — Overlays need to modify base resources without copying them. Copying entire manifests into each overlay defeats the purpose of having a base — you'd be maintaining duplicates again. Patches let you express only the delta: the exact fields that differ per environment, applied on top of the base.
- **What it is** — A patch is a partial document that modifies a base resource. Kustomize supports two patch formats: Strategic Merge Patches (partial YAML that merges field-by-field) and JSON 6902 Patches (RFC 6902 operations: add, replace, remove at a specific path). Additionally, the `images` field in `kustomization.yaml` acts as a dedicated image override mechanism.
- **One-liner** — Patches = the delta between base and overlay, expressed as partial YAML or path-based operations.

# Architecture

```text
Patch Types:

Strategic Merge Patch              JSON 6902 Patch
─────────────────────────────────  ─────────────────────────────
Partial YAML document              RFC 6902 operation list
Matches by kind + name             Targets by kind + name + path
Field-by-field merge               Precise add / replace / remove
Readable, looks like YAML          Verbose, explicit path notation
Best for simple field changes      Best for array ops, removals

Image Override (images: field)
─────────────────────────────────
Declared in kustomization.yaml
No patch file needed
Replaces image name/tag globally
```

# Mental Model

- Strategic merge = partial YAML diff: write only the fields you want to change; Kustomize merges the rest from the base
- JSON 6902 = surgical path-based edit: specify exact path in the document tree, specify the operation (add/replace/remove)
- Image override = shorthand for the most common overlay change (updating image tags between environments)

```text
Base deployment.yaml:
  replicas: 3
  image: nginx:1.20
  memory: 256Mi

Strategic Merge Patch (replicas only):
  replicas: 5          ← only this field, nothing else

Result after merge:
  replicas: 5          ← from patch
  image: nginx:1.20    ← from base (unchanged)
  memory: 256Mi        ← from base (unchanged)

JSON 6902 Patch (same change):
  - op: replace
    path: /spec/replicas
    value: 5
```

# Core Building Blocks

### Strategic Merge Patch

- **Why it exists** — Most overlay changes are simple field updates: change replicas, increase memory, update a label. Strategic Merge makes these changes readable by letting you write a partial YAML document that looks exactly like the resource you're modifying.
- **What it is** — A partial YAML document with the same `apiVersion`, `kind`, and `metadata.name` as the target resource, containing only the fields to change. Kustomize identifies the target resource by matching kind and name, then merges the patch on top field-by-field.
- **One-liner** — Write a mini-version of the resource with only the fields you want to change.

```yaml
# overlays/prod/replicas-patch.yaml
# Only the fields to change — everything else comes from base
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 5                       # change from base (3) to 5
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

```yaml
# overlays/prod/kustomization.yaml — declare patches here
patches:
  - path: replicas-patch.yaml
  - path: resources-patch.yaml
```

```text
Merge result example:

Base (base/deployment.yaml):          Patch (resources-patch.yaml):
  spec:                                 spec:
    replicas: 3                           template:
    template:                               spec:
      spec:                                   containers:
        containers:                           - name: app
        - name: app                             resources:
          image: nginx:1.20                       limits:
          resources:                                memory: "1Gi"
            requests:
              memory: "256Mi"

Result after merge:
  spec:
    replicas: 3          ← unchanged
    template:
      spec:
        containers:
        - name: app
          image: nginx:1.20    ← unchanged
          resources:
            requests:
              memory: "256Mi"  ← unchanged
            limits:
              memory: "1Gi"    ← added by patch
```

### JSON 6902 Patch

- **Why it exists** — Some changes cannot be expressed cleanly with Strategic Merge: removing a field, adding an element to an array at a specific index, or making a change that would be ambiguous during a merge. JSON 6902 patches handle these cases with explicit, unambiguous operations.
- **What it is** — A list of RFC 6902 operations (`add`, `replace`, `remove`, `move`, `copy`, `test`), each specifying a `path` (JSON Pointer notation) and a value. Declared inline in `kustomization.yaml` under `patches` with a `target` selector, or in a separate YAML file.
- **One-liner** — JSON 6902 = explicit operation at an explicit path, no ambiguity.

```yaml
# overlays/prod/kustomization.yaml — inline JSON 6902 patches
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

```text
JSON 6902 Operations:

| Operation | Purpose                        | Example path                        |
|-----------|--------------------------------|-------------------------------------|
| replace   | Change value at path           | /spec/replicas                      |
| add       | Add new field or array element | /spec/affinity                      |
| remove    | Delete field or array element  | /spec/limits/cpu                    |
| move      | Move field to new path         | from: /a → path: /b                 |
| copy      | Copy field to new path         | from: /a → path: /b                 |
| test      | Assert value (fail if wrong)   | /spec/replicas → value: 3           |
```

### Image Override (images: field)

- **Why it exists** — Updating image tags is the most common overlay change (promote from dev to staging to prod). Writing a full patch file just to change a tag is verbose. The `images` field provides a shorthand that is easier to read and update.
- **What it is** — A list of image override rules declared directly in `kustomization.yaml`. Each rule matches resources by `name` (the image name without tag), and can replace the tag (`newTag`), the image name (`newName`), or both. Applies to all resources in the kustomization that reference the matched image.
- **One-liner** — `images:` = one-liner image tag override without writing a patch file.

```yaml
# overlays/prod/kustomization.yaml
images:
  # Change tag only (most common: promote to stable release)
  - name: nginx
    newTag: "1.25"

  # Change both name and tag (e.g., use private registry)
  - name: myapp
    newName: myregistry.azurecr.io/myapp
    newTag: "2.1.0"

  # Use digest instead of tag (immutable, safer for prod)
  - name: nginx
    newTag: "@sha256:abc123..."
```

```yaml
# overlays/dev/kustomization.yaml
images:
  - name: nginx
    newTag: "latest"    # dev gets bleeding edge

# overlays/staging/kustomization.yaml
images:
  - name: nginx
    newTag: "1.25-rc1"  # staging gets release candidate

# overlays/prod/kustomization.yaml
images:
  - name: nginx
    newTag: "1.25"      # prod gets stable release
```

### patchesStrategicMerge vs patches

- **Why it exists** — Kustomize has two ways to declare strategic merge patches. The older `patchesStrategicMerge` field (deprecated but still works) accepts only file paths. The newer `patches` field accepts both file paths and inline patches, and also accepts JSON 6902 patches. Understanding the difference prevents confusion when reading older kustomization files.
- **What it is** — `patchesStrategicMerge` is the legacy field accepting a list of file paths to strategic merge patch files. `patches` is the unified field accepting strategic merge patches (via `path:`) and JSON 6902 patches (via `patch: |-`), each with an optional `target:` selector for more precise targeting.
- **One-liner** — Prefer `patches` (unified, supports both types); `patchesStrategicMerge` is legacy but still valid.

```yaml
# Legacy style (still works, avoid for new files)
patchesStrategicMerge:
  - replicas-patch.yaml
  - resources-patch.yaml

# Modern style (preferred)
patches:
  # Strategic merge patch via file path
  - path: replicas-patch.yaml

  # Strategic merge patch with explicit target (more precise)
  - path: resources-patch.yaml
    target:
      kind: Deployment
      name: myapp

  # JSON 6902 patch inline
  - target:
      kind: Deployment
      name: myapp
    patch: |-
      - op: remove
        path: /spec/template/spec/containers/0/resources/limits/cpu

  # Target by label selector (patches multiple resources at once)
  - path: common-patch.yaml
    target:
      kind: Deployment
      labelSelector: "env=production"
```

# Base resource: metadata.name: myapp
# Wrong: patch for different resource
metadata:
  name: app             # doesn't match base name "myapp"

# Right: patch for correct resource
metadata:
  name: myapp           # matches base
```

- Verify the patch file path in `kustomization.yaml` is relative to the kustomization directory
- Render the output and inspect: `kubectl kustomize overlays/prod/ | grep -A5 "replicas:"`

### JSON 6902 patch returns "doc is missing path"

- The path in the patch doesn't exist in the resource — use `op: add` for new fields, `op: replace` only for existing fields

```yaml
# Wrong: path doesn't exist yet
- op: replace
  path: /spec/affinity/nodeAffinity    # /spec/affinity doesn't exist in base

# Right: use op: add for new fields
- op: add
  path: /spec/affinity
  value:
    nodeAffinity: {...}
```

### Multiple patches conflicting on the same field

- If multiple patches modify the same field, the last one wins (patches are applied in declared order)

```yaml
patches:
  - path: replicas-patch.yaml       # sets replicas: 5
  - path: another-patch.yaml        # also sets replicas: 3  ← this wins

# Result: replicas will be 3
```

- Solution: combine conflicting patches into one file, or remove the duplicate

### Image override not changing the image

- The `images.name` must match the image name in the deployment without the tag

```yaml
# In deployment.yaml: image: nginx:1.20

images:
  - name: nginx          # correct: just the image name
    newTag: "1.25"

  - name: "nginx:1.20"  # wrong: includes the tag in name
    newTag: "1.25"
```

- Test: `kubectl kustomize ./ | grep "image:"` — verify the output has the expected tag
