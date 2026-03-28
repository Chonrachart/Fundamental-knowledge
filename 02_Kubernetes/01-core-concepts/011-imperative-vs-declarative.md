# Imperative vs Declarative

## Overview

**Why it exists** — Kubernetes supports two ways of interacting with the cluster. Understanding the distinction is critical for knowing when quick one-liners are appropriate vs when you need version-controlled manifests.
**What it is** — Imperative commands tell Kubernetes exactly what to do step by step (`kubectl run`, `kubectl expose`, `kubectl delete`). Declarative commands describe the desired end state and let Kubernetes figure out how to reach it (`kubectl apply -f`). The reconciliation loop is built around the declarative model.
**One-liner** — Imperative = tell it what to do; declarative = tell it what you want and let it converge.

## Architecture

```text
Imperative:
  User ──────────────────────────────────► API Server
  "create pod nginx with image nginx"       (one action, one result)

Declarative:
  User writes YAML (desired state)
      │
      ▼
  kubectl apply -f manifest.yaml ──► API Server ──► etcd
                                          │
                                          ▼
                                   Controllers watch,
                                   compare desired vs actual,
                                   reconcile continuously
```

## Mental Model

```text
Imperative (step-by-step instructions):
  kubectl run nginx --image=nginx
  kubectl expose pod nginx --port=80
  kubectl scale deployment nginx --replicas=3
  kubectl delete pod nginx-abc123

  Problem: if something breaks, you don't know the intended state.
  Each command is a one-time action — not idempotent.

Declarative (state description):
  # nginx-deployment.yaml
  replicas: 3
  image: nginx:alpine

  kubectl apply -f nginx-deployment.yaml
  # Run again → no change (already matches)
  # Change replicas to 5, run again → scales up
  # Store in Git → full history of intended state
```

## Core Building Blocks

### Imperative Commands

**Why it exists** — Quick operations, learning, debugging, and one-off tasks don't need a full manifest file.
**What it is** — Direct kubectl commands that create, update, or delete resources immediately. Each command is a single API call. Results are not stored as a file; the next person to manage the cluster may not know how the resource was created.
**One-liner** — Imperative commands are fast but leave no record of intent — use for learning and quick fixes only.

Common imperative commands:
```bash
# Create resources
kubectl run nginx --image=nginx:alpine                     # create a pod
kubectl run nginx --image=nginx --restart=Never            # pod (not deployment)
kubectl create deployment myapp --image=myapp:1.0          # create a deployment
kubectl create service clusterip web --tcp=80:8080         # create a service
kubectl create configmap myconfig --from-literal=key=val   # create configmap
kubectl create secret generic mysecret --from-literal=password=abc123

# Update resources
kubectl scale deployment myapp --replicas=5
kubectl set image deployment/myapp app=myapp:2.0
kubectl label pod mypod env=production
kubectl annotate pod mypod description="my pod"

# Delete resources
kubectl delete pod nginx
kubectl delete deployment myapp
kubectl delete -f manifest.yaml    # delete what's in the file
```

### Declarative Approach

**Why it exists** — Production systems need reproducibility, auditability, and GitOps workflows where YAML files are the single source of truth.
**What it is** — Writing YAML manifests that describe desired state, then applying them with `kubectl apply`. The command is idempotent: applying the same file twice makes no changes. Applying an updated file converges to the new desired state. Files live in Git, enabling code review, history, and rollback.
**One-liner** — Declarative manifests are the production-grade approach: version-controlled, reviewable, repeatable.

```bash
# Apply (create or update — idempotent)
kubectl apply -f deployment.yaml
kubectl apply -f ./k8s/            # apply all YAML files in a directory
kubectl apply -f https://raw.githubusercontent.com/.../manifest.yaml

# Dry run (shows what would change without applying)
kubectl apply -f deployment.yaml --dry-run=server

# Diff (shows what would change vs current cluster state)
kubectl diff -f deployment.yaml

# Delete using manifest
kubectl delete -f deployment.yaml
```

### Comparison Table

| Aspect | Imperative | Declarative |
|--------|-----------|-------------|
| Syntax | `kubectl run`, `kubectl create`, `kubectl scale` | `kubectl apply -f file.yaml` |
| Idempotent | No — running twice may error or create duplicates | Yes — running twice is safe |
| Stored in Git | No | Yes — YAML file is the source of truth |
| Auditability | Low — who ran what command? | High — Git history shows all changes |
| Code review | Not possible | PRs and reviews for all changes |
| Good for | Quick fixes, learning, CKA exam, one-offs | Production, GitOps, CI/CD pipelines |
| Reconciliation | Manual | Controllers continuously reconcile |

### The `--dry-run=client -o yaml` Trick

**Why it exists** — Writing YAML from scratch is tedious and error-prone. You can generate valid YAML from imperative commands.
**What it is** — Running an imperative command with `--dry-run=client -o yaml` prints the YAML that would be applied without actually creating the resource. This is the fastest way to bootstrap a manifest.
**One-liner** — Use `--dry-run=client -o yaml` to generate YAML from imperative commands, then save and customize it.

```bash
# Generate deployment YAML
kubectl create deployment myapp --image=nginx:alpine \
  --replicas=3 --dry-run=client -o yaml > deployment.yaml

# Generate pod YAML
kubectl run mypod --image=busybox --dry-run=client -o yaml > pod.yaml

# Generate service YAML
kubectl expose deployment myapp --port=80 --target-port=8080 \
  --dry-run=client -o yaml > service.yaml

# Generate configmap YAML
kubectl create configmap myconfig \
  --from-literal=ENV=production \
  --dry-run=client -o yaml > configmap.yaml

# Useful in CKA exam: generate the template, then edit the YAML file
kubectl run nginx --image=nginx \
  --dry-run=client -o yaml | kubectl apply -f -
```

### When to Use Each

```text
Use IMPERATIVE when:
  - Learning Kubernetes for the first time
  - Debugging: "what does this look like?"
  - Quick one-off tasks (delete a pod, scale for a hotfix)
  - CKA/CKAD exam (speed matters)
  - Generating YAML templates (--dry-run=client -o yaml)

Use DECLARATIVE when:
  - Production workloads
  - GitOps / CI-CD pipelines
  - Anything that needs to be reviewed, repeated, or audited
  - Infrastructure as code (changes tracked in Git)
  - Multiple environments (parameterize with Helm/Kustomize)
```

## Troubleshooting

### `kubectl apply` returns "field is immutable"

1. Some fields (like `selector`) cannot be changed after creation — you must delete and recreate.
2. For Deployments: changing `selector` requires `kubectl delete deployment <name>` then reapply.
3. Use `kubectl diff -f file.yaml` first to preview changes and catch immutable field errors.

### Accidentally applied wrong image/config imperatively

1. No YAML? Capture current state: `kubectl get deployment myapp -o yaml > backup.yaml`.
2. Edit and reapply: `kubectl apply -f backup.yaml`.
3. Going forward, store intended state in Git before making changes.

### `kubectl apply` vs `kubectl replace` vs `kubectl create`

```bash
kubectl create -f file.yaml   # fails if already exists
kubectl apply -f file.yaml    # create or update (preferred)
kubectl replace -f file.yaml  # full PUT — loses server-side fields; resource must already exist
```

Always prefer `kubectl apply` — it is the only truly idempotent option.
