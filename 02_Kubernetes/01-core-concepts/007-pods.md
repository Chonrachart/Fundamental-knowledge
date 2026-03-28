# Pods

# Overview

- **Why it exists** — Containers that work together (e.g. an app and its log shipper) need to share the same network and storage. The pod is the abstraction that groups them and gives them a shared context.
- **What it is** — The smallest deployable unit in Kubernetes. A pod contains one or more containers that share a network namespace (same IP, communicate via `localhost`) and can share storage volumes. Pods are ephemeral — they are created, run, and destroyed. You rarely create pods directly; Deployments, StatefulSets, and DaemonSets manage them.
- **One-liner** — A pod is a co-located group of containers that share network and storage, treated as a single scheduling unit.

# Architecture

```text
┌─── Pod (unique IP, shared network namespace) ────────────────┐
│                                                              │
│  pause container (holds network namespace — invisible)       │
│                                                              │
│  ┌───────────────┐      ┌───────────────┐                   │
│  │  Main         │      │  Sidecar      │  (optional)       │
│  │  Container    │◄────►│  Container    │                   │
│  │  :8080        │      │  :9090        │  share localhost  │
│  └───────────────┘      └───────────────┘                   │
│                                                              │
│  ┌─────────────────────────────────────────┐                │
│  │  Shared Volumes                         │                │
│  │  (emptyDir, PVC, configMap, secret)     │                │
│  └─────────────────────────────────────────┘                │
└──────────────────────────────────────────────────────────────┘
```

# Mental Model

```text
Pod lifecycle:

Init containers run sequentially (if any)
        │ all must succeed
        ▼
Main containers start → postStart hook fires
        │
        ▼
kubelet begins probing:
  startupProbe  → fail → restart (protects slow-starting apps)
  livenessProbe → fail → restart container
  readinessProbe → fail → remove from Service endpoints
        │
        ▼
Pod termination:
  preStop hook runs (graceful shutdown)
        │
        ▼
  SIGTERM sent to container process
        │
        ▼
terminationGracePeriodSeconds (default 30s)
        │
        ▼
SIGKILL if still running
```

# Core Building Blocks

### Pod Spec Anatomy

- **Why it exists** — The pod spec is the declarative description of what should run: which containers, which images, which volumes, and under what conditions.
- **What it is** — A YAML structure under `spec:` that describes the pod's contents and behavior. Key fields:
- `containers`: required list of containers; each has `name`, `image`, `ports`, `env`, `resources`
- `initContainers`: run to completion before main containers; sequential order; all must succeed
- `volumes`: storage volumes available to the pod; containers reference these in `volumeMounts`
- `restartPolicy`: `Always` (default, for services), `OnFailure` (for jobs), `Never`
- `nodeSelector`, `affinity`, `tolerations`: constrain which node the pod lands on

- **One-liner** — The pod spec is the complete blueprint for what runs inside the pod.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  initContainers:
  - name: wait-for-db
    image: busybox
    command: ['sh', '-c', 'until nc -z db 5432; do sleep 2; done']

  containers:
  - name: app
    image: myapp:1.0
    ports:
    - containerPort: 8080
    env:
    - name: DB_HOST
      value: "db"
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
    volumeMounts:
    - name: config
      mountPath: /etc/config

  volumes:
  - name: config
    configMap:
      name: myapp-config

  restartPolicy: Always
```

### Init Containers

- **Why it exists** — Some setup tasks (waiting for a dependency, seeding a database, fetching secrets) must complete before the main app starts.
- **What it is** — Containers that run sequentially before the main containers. Each must exit successfully (exit code 0) before the next starts. If an init container fails, the pod restarts it (according to `restartPolicy`). Init containers have the same spec as regular containers but can use different images.

Common uses:
- Wait for a service to be ready (`until nc -z db 5432`)
- Copy or transform configuration files
- Run database migrations
- Clone a git repo into a shared volume

- **One-liner** — Init containers are sequential setup steps that must all pass before the main app starts.

### Liveness Probe

- **Why it exists** — A container can be running (process is alive) but stuck or deadlocked. The liveness probe detects this and restarts the container.
- **What it is** — A health check kubelet runs periodically. If it fails for `failureThreshold` consecutive times, kubelet kills and restarts the container. Types: `httpGet` (checks HTTP status code), `tcpSocket` (checks TCP connection), `exec` (runs a command; exit 0 = healthy).
- **One-liner** — The liveness probe answers "is this container healthy enough to keep running?"

### Readiness Probe

- **Why it exists** — A container may be running but not yet ready to serve traffic (loading caches, warming up). Traffic should not reach it until it's ready.
- **What it is** — Same mechanics as liveness probe, but failure removes the pod from Service endpoints instead of restarting it. The pod stays Running but receives no traffic. Once the probe passes again, the pod is added back to endpoints.
- **One-liner** — The readiness probe answers "is this container ready to receive traffic?"

### Startup Probe

- **Why it exists** — Slow-starting apps (legacy apps, JVM apps) would be killed by liveness probes before they finish starting up.
- **What it is** — Runs before liveness and readiness probes. While the startup probe is failing, liveness/readiness probes are disabled. Once the startup probe succeeds once, it hands off to the other probes. Configure with a high `failureThreshold` × `periodSeconds` to allow enough startup time.
- **One-liner** — The startup probe protects slow-starting containers from being killed before they're up.

```yaml
containers:
- name: app
  image: myapp:1.0
  startupProbe:
    httpGet:
      path: /health
      port: 8080
    failureThreshold: 30    # allow up to 30 * 10s = 5 min to start
    periodSeconds: 10
  livenessProbe:
    httpGet:
      path: /health
      port: 8080
    initialDelaySeconds: 0
    periodSeconds: 10
    failureThreshold: 3
  readinessProbe:
    httpGet:
      path: /ready
      port: 8080
    periodSeconds: 5
    failureThreshold: 1
```

| Probe | Failure action | Use when |
|-------|---------------|----------|
| startupProbe | Liveness/readiness probes don't start until this succeeds; restarts container after failureThreshold | App takes a long time to start |
| livenessProbe | Restarts the container | App can deadlock or get stuck |
| readinessProbe | Removes from Service endpoints | App needs warm-up before handling traffic |

### Pod Lifecycle Phases

- **Why it exists** — Operators and controllers need a standardized way to understand where a pod is in its life at a glance, from scheduling through completion or failure.
- **What it is** — A high-level summary field (`status.phase`) on a Pod object that reflects the overall state of the pod at any given moment. It is distinct from individual container statuses and conditions.
- **One-liner** — Pod lifecycle phases are the five top-level states that describe where a pod is in its existence, from pending through succeeded or failed.

| Phase | Meaning |
|-------|---------|
| `Pending` | Pod accepted but not yet scheduled or images not pulled |
| `Running` | At least one container is running (or starting/restarting) |
| `Succeeded` | All containers exited with code 0; restartPolicy: Never/OnFailure |
| `Failed` | All containers exited; at least one with non-zero exit code |
| `Unknown` | Node lost contact with API server; pod state unknown |

```bash
# Get pod phase
kubectl get pod <name> -o jsonpath='{.status.phase}'

# Watch pod lifecycle
kubectl get pods -w

# See all pod details including phase, conditions, container statuses
kubectl describe pod <name>
```

# Troubleshooting

### Pod not receiving traffic despite being Running

1. Check readiness probe: `kubectl describe pod <name>` — is readiness probe passing?
2. If readiness fails, pod is excluded from Service endpoints: `kubectl get endpoints <svc>`.
3. Fix: adjust `initialDelaySeconds`, correct probe path/port, or check app's `/ready` handler.

### Init container stuck (Pod shows `Init:0/1`)

1. Check init container logs: `kubectl logs <pod> -c <init-container-name>`.
2. Init containers run sequentially; if one fails the pod stays in Init state.
3. Common causes: waiting for a dependency that is not ready, wrong image, missing env var.

### Liveness probe killing healthy container

1. Probe too aggressive: increase `initialDelaySeconds` and `timeoutSeconds`.
2. Slow-starting app: add a `startupProbe` with a high `failureThreshold`.
3. Verify probe endpoint: `kubectl exec <pod> -- curl -s localhost:8080/health`.

### Pod stuck in Terminating

1. Check for finalizers: `kubectl get pod <name> -o jsonpath='{.metadata.finalizers}'`.
2. If node is down, pod may be stuck — force delete: `kubectl delete pod <name> --force --grace-period=0`.
3. Check `preStop` hook — if it hangs, pod waits `terminationGracePeriodSeconds` before SIGKILL.
