# Labels and Selectors

# Overview

- **Why it exists** — Kubernetes objects need a flexible, decoupled way to group and target each other without hard-coded references. Labels provide loose coupling: a Service does not know the names of individual pods — it just says "give me all pods with `app=web`."
- **What it is** — Labels are arbitrary key-value pairs attached to any Kubernetes object. Selectors are queries that match objects by their label values. Together they wire Deployments to pods, Services to pods, and allow ad-hoc filtering with `kubectl`.
- **One-liner** — Labels are key-value tags on objects; selectors are the queries that match them — the glue connecting Deployments, Services, and kubectl queries to pods.

# Architecture

```text
Deployment ──selector: app=web──► Pod (app=web, env=prod)
                                   Pod (app=web, env=prod)
                                   Pod (app=web, env=prod)

Service    ──selector: app=web──► Pod (app=web, env=prod)   ← same pods!
                                   Pod (app=web, env=prod)
                                   Pod (app=web, env=prod)

kubectl get pods -l app=web       ← same selector, ad-hoc query
```

# Mental Model

Labels are like tags in a filing system. You label every document (pod) with whatever attributes matter: `app=web`, `env=prod`, `tier=frontend`. Then any actor (Deployment, Service, kubectl) can select all documents matching a query without needing to know individual document names. Adding a new pod with the right labels automatically makes it a member of all matching groups.

The key insight: **nothing breaks when you add a new pod** — it just picks up membership in all matching selectors automatically.

# Core Building Blocks

### Label syntax rules

- **Why it exists** — A consistent format prevents ambiguity across tools and admission controllers.
- **What it is** — Labels follow a `key: value` format where both key and value are strings. Keys may have an optional DNS-subdomain prefix separated by `/` (e.g. `app.kubernetes.io/name`). Values must be 63 characters or fewer, must start and end with alphanumeric characters, and may contain `-`, `_`, `.` in the middle. An empty value (`""`) is valid.
- **One-liner** — Label keys are `[prefix/]name`; values are short alphanumeric strings with dashes, dots, and underscores allowed.

```yaml
metadata:
  labels:
    app: myapp                          # simple key=value
    tier: frontend
    env: production
    app.kubernetes.io/version: "1.2.3"  # prefixed key (recommended for tooling)
    release: "2024-03-01"
```

### Equality-based selectors

- **Why it exists** — The simplest and most common form of selection: match exactly on a key=value or key!=value.
- **What it is** — Uses `=` (or `==`) and `!=` operators. The Deployment's `spec.selector.matchLabels` and Service's `spec.selector` use equality-based format. Multiple conditions are ANDed together.
- **One-liner** — Equality selectors match `key=value` or `key!=value`; multiple conditions are AND.

```yaml
# In a Service spec:
spec:
  selector:
    app: myapp      # equality-based: must have app=myapp
    tier: frontend  # AND tier=frontend

# In a Deployment spec:
spec:
  selector:
    matchLabels:
      app: myapp
```

```bash
# kubectl equality-based filter
kubectl get pods -l app=myapp
kubectl get pods -l app=myapp,tier=frontend    # AND
kubectl get pods -l env!=production            # NOT equal
```

### Set-based selectors

- **Why it exists** — More expressive than equality selectors; allows matching against a set of values or checking for label existence.
- **What it is** — Uses `in`, `notin`, and `exists` operators. These are only available in `matchExpressions` (not in Service selector or Deployment `matchLabels`). Commonly used in Job, Deployment, and DaemonSet `selector.matchExpressions`.
- **One-liner** — Set-based selectors use `in`, `notin`, `exists` for richer matching — available in `matchExpressions` only.

```yaml
spec:
  selector:
    matchExpressions:
    - key: env
      operator: In
      values: ["production", "staging"]
    - key: tier
      operator: NotIn
      values: ["legacy"]
    - key: app
      operator: Exists   # key exists, any value
```

```bash
# kubectl set-based filter
kubectl get pods -l 'env in (production,staging)'
kubectl get pods -l 'tier notin (legacy)'
kubectl get pods -l 'app'              # exists
kubectl get pods -l '!deprecated'      # does NOT exist
```

### Equality-based vs Set-based comparison

| Feature | Equality-based | Set-based |
|---------|---------------|-----------|
| Operators | `=`, `==`, `!=` | `In`, `NotIn`, `Exists`, `DoesNotExist` |
| Where used | Service selector, `matchLabels`, `kubectl -l` | `matchExpressions`, `kubectl -l` |
| Multi-value match | No (one value per key) | Yes (`In: [a, b, c]`) |
| Existence check | No | Yes (`Exists`, `DoesNotExist`) |
| Syntax | `key=value` | `key in (v1,v2)` |

### Labels vs Annotations

**Why the distinction matters** — Labels are queryable (indexed by API server for selector filtering); annotations are not. Attaching large blobs of data to labels would degrade performance.
**What they are** — Labels are for **selection and grouping** — they are the mechanism that wires objects together. Annotations are for **non-identifying metadata** — tool outputs, build info, checksums, human notes. Annotations can hold arbitrary data (longer strings, JSON blobs) that labels cannot.
- **One-liner** — Labels are for selection (queryable); annotations are for metadata (not queryable).

| Aspect | Labels | Annotations |
|--------|--------|-------------|
| Purpose | Selection, grouping | Supplementary metadata |
| Queryable? | Yes (selectors, `-l` flag) | No |
| Value length | ≤ 63 chars, alphanumeric | Arbitrary |
| Used by controllers? | Yes (Deployment, Service, etc.) | No (tooling only) |
| Examples | `app=web`, `env=prod` | `build-hash=abc123`, `description: "..."` |

```yaml
metadata:
  labels:
    app: web         # selector uses this
    env: prod        # selector uses this
  annotations:
    kubernetes.io/change-cause: "image updated to v1.2"   # informational only
    prometheus.io/scrape: "true"                           # tool-read, not selectable
```
