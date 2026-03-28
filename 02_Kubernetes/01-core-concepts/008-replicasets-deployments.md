# ReplicaSets and Deployments

### Overview

**Why it exists** — Running a single pod is fragile; if it crashes, it's gone. You need a controller to maintain the desired number of replicas and a higher-level abstraction to manage updates safely.
**What it is** — A ReplicaSet ensures N copies of a pod are always running by watching and reconciling pod count. A Deployment owns and manages ReplicaSets, providing declarative updates, history tracking, and the ability to scale or roll back. In practice you always create Deployments, never ReplicaSets directly.
**One-liner** — A Deployment manages ReplicaSets; a ReplicaSet manages pods; together they keep your app running at the desired scale.

### Architecture

```text
Deployment (desired state: image, replicas, strategy)
    │
    ├── ReplicaSet v2 (current)   replicas: 3
    │       ├── Pod-a  (Running)
    │       ├── Pod-b  (Running)
    │       └── Pod-c  (Running)
    │
    └── ReplicaSet v1 (previous)  replicas: 0  (kept for rollback)

Ownership chain:
  Deployment ──ownerRef──► ReplicaSet ──ownerRef──► Pod
```

### Mental Model

```text
kubectl apply -f deployment.yaml   (3 replicas of nginx:alpine)
        │
        ▼
Deployment controller creates ReplicaSet (hash in name)
        │
        ▼
ReplicaSet controller creates 3 Pods
        │
        ▼
Scheduler assigns each pod to a node
        │
        ▼
kubelet starts containers on each node

--- Later: a pod crashes ---
ReplicaSet controller sees 2 running (desired: 3)
→ creates a replacement pod immediately
```

### Core Building Blocks

### ReplicaSet

**Why it exists** — Pods are mortal; they crash, get evicted, or their node fails. A ReplicaSet ensures the desired count is always maintained.
**What it is** — A controller that keeps exactly N pods matching a label selector running at all times. It uses a pod template to create new pods when count drops, and deletes pods when count exceeds desired. The ReplicaSet's selector must match the pod template's labels.
- You rarely create ReplicaSets directly — Deployments manage them.
- ReplicaSet names include a hash of the pod template (e.g. `myapp-7d9f8b4c6`).
- Deleting a ReplicaSet deletes all its pods unless you use `--cascade=orphan`.

**One-liner** — A ReplicaSet is the "N pods must always run" controller.

```bash
# See ReplicaSets for a deployment
kubectl get rs
kubectl get rs -l app=myapp

# See which RS a pod belongs to
kubectl get pod <name> -o jsonpath='{.metadata.ownerReferences[0].name}'

# Describe a ReplicaSet
kubectl describe rs <rs-name>
```

### Deployment

**Why it exists** — You need more than just "keep N pods running" — you need to update them safely, roll back on failure, and track history.
**What it is** — A higher-level controller that manages ReplicaSets. When you change the pod template (new image, env var, etc.), the Deployment controller creates a new ReplicaSet and transitions traffic to it according to the configured strategy. Old ReplicaSets are kept (scaled to 0) for rollback up to `revisionHistoryLimit` (default 10).

Key properties:
- Declarative: `kubectl apply` is idempotent — re-applying the same YAML makes no changes
- Revision tracking: each pod template change increments the revision number
- Rollback: `kubectl rollout undo` reverts to the previous ReplicaSet

**One-liner** — A Deployment adds update strategy, revision history, and rollback capability on top of ReplicaSets.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp           # must match pod template labels
  template:
    metadata:
      labels:
        app: myapp         # must match selector above
    spec:
      containers:
      - name: app
        image: myapp:1.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
```

### Scaling

**Why it exists** — Traffic and load change; you need to adjust the number of replicas without recreating the Deployment.
**What it is** — Changing `spec.replicas` either via `kubectl scale` or by editing the manifest. The ReplicaSet controller reconciles immediately. Scaling does not trigger a new ReplicaSet — only pod template changes do.
**One-liner** — Scaling changes how many pods run without touching the pod template or creating a new revision.

```bash
# Scale imperatively
kubectl scale deployment myapp --replicas=5

# Scale by editing the manifest (declarative)
# Change replicas: 5 in deployment.yaml, then:
kubectl apply -f deployment.yaml

# Check scaling progress
kubectl get deployment myapp
kubectl rollout status deployment/myapp

# Watch pods appear/disappear
kubectl get pods -l app=myapp -w
```

### Update Strategies

**Why it exists** — Different applications have different tolerance for downtime and over-provisioning during updates. The strategy controls how the Deployment transitions from the old ReplicaSet to the new one.
**What it is** — Two strategies are available, configured via `spec.strategy.type`.

**RollingUpdate** (default) — Replaces pods incrementally. Controls the pace with two parameters:
- `maxSurge`: maximum number of pods that can be created above the desired count during the update (default: 25%). Use to allow new pods to start before old ones are killed.
- `maxUnavailable`: maximum number of pods that can be unavailable during the update (default: 25%). Use to ensure minimum capacity is maintained.

**Recreate** — Terminates all old pods first, then creates new ones. Results in a brief period of zero running pods (downtime). Use for apps that cannot run two versions simultaneously.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  strategy:
    type: RollingUpdate        # or Recreate
    rollingUpdate:
      maxSurge: 1              # at most 4 pods total during update
      maxUnavailable: 0        # never go below 3 running pods
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
        image: myapp:2.0
```

```bash
# Monitor a rolling update
kubectl rollout status deployment/myapp

# View revision history
kubectl rollout history deployment/myapp

# View details of a specific revision
kubectl rollout history deployment/myapp --revision=2

# Roll back to the previous revision
kubectl rollout undo deployment/myapp

# Roll back to a specific revision
kubectl rollout undo deployment/myapp --to-revision=1

# Pause a rollout mid-way (e.g. to canary test)
kubectl rollout pause deployment/myapp
kubectl rollout resume deployment/myapp
```

**One-liner** — RollingUpdate replaces pods gradually (zero-downtime); Recreate kills all pods first (brief downtime, simpler).

### Relationship: Deployment → ReplicaSet → Pod

```bash
# Full hierarchy view
kubectl get deployment myapp
kubectl get rs -l app=myapp
kubectl get pods -l app=myapp

# See owner references (who created what)
kubectl get pod <pod-name> -o yaml | grep -A5 ownerReferences
kubectl get rs <rs-name> -o yaml | grep -A5 ownerReferences

# Deployment status columns
# READY = pods that passed readiness probe
# UP-TO-DATE = pods on the latest pod template
# AVAILABLE = pods ready for at least minReadySeconds
kubectl get deployment myapp
# NAME    READY   UP-TO-DATE   AVAILABLE   AGE
# myapp   3/3     3            3           5m
```

### Troubleshooting

### Deployment created but no pods appear

1. Check if ReplicaSet was created: `kubectl get rs -l app=<name>`.
2. If RS exists but 0 pods: check `kubectl describe rs <rs-name>` — may be a quota or image pull issue.
3. Check deployment events: `kubectl describe deployment <name>`.

### Pods created but keep restarting

1. `kubectl describe pod <name>` — check Events and Last State.
2. `kubectl logs <pod>` and `kubectl logs <pod> --previous` for crash logs.
3. Common: app exits on startup (bad config), liveness probe too aggressive, OOMKill (check `kubectl describe pod` for `OOMKilled`).

### Scale command has no effect

1. Check if HPA is managing the deployment: `kubectl get hpa` — HPA overrides manual scaling.
2. Verify: `kubectl get deployment <name>` — check if READY count changes.
3. Check for pending pods if scaling up: `kubectl get pods` — may be resource constraints.
