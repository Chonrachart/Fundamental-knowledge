# Pods and Labels

- A Pod is the smallest deployable unit in Kubernetes; it wraps one or more containers with shared network and storage.
- Labels are key-value pairs attached to objects; selectors match labels to connect Deployments, Services, and queries to pods.
- Probes (liveness, readiness) let kubelet monitor container health and control traffic routing.

# Architecture

```text
┌─── Pod (unique IP, shared network namespace) ───────────────┐
│                                                              │
│  ┌─────────────────┐   pause container (holds network ns)   │
│  │                 │                                         │
│  │  ┌───────────┐  │   ┌───────────┐                        │
│  │  │ Container │  │   │ Container │  (sidecar, optional)   │
│  │  │  (main)   │  │   │ (logging) │                        │
│  │  │  :8080    │◄─┼──►│  :9090    │  communicate via       │
│  │  └───────────┘  │   └───────────┘  localhost              │
│  │                 │                                         │
│  │  ┌──────────────┴────────────────┐                        │
│  │  │  Shared Volumes (emptyDir,    │                        │
│  │  │  PVC, configMap, secret)      │                        │
│  │  └───────────────────────────────┘                        │
│  └─────────────────┘                                         │
└──────────────────────────────────────────────────────────────┘
```

# Mental Model

```text
Pod created by Deployment
        │
        ▼
Init containers run sequentially (if any)
        │
        ▼
Main containers start → postStart hook fires
        │
        ▼
kubelet begins probing:
  livenessProbe  → fail → restart container
  readinessProbe → fail → remove from Service endpoints
        │
        ▼
Pod termination signal (SIGTERM)
        │
        ▼
preStop hook runs → graceful shutdown
        │
        ▼
terminationGracePeriodSeconds expires → SIGKILL
```

# Core Building Blocks

### Pod Spec

- **containers**: List of containers; required; name, image, ports, env, resources, etc.
- **initContainers**: Run to completion before main containers start; order matters.
- **restartPolicy**: `Always`, `OnFailure`, `Never`; default `Always`.
- **nodeSelector**, **affinity**: Constrain which nodes the pod can run on.
- A pod gets a unique IP; containers in the same pod share that IP and communicate via `localhost`.
- Init containers run sequentially and must all succeed before main containers start.
- Default `restartPolicy` is `Always` — suitable for long-running services.

### Labels and Selectors

- **Labels**: Key-value pairs on objects (pods, etc.); e.g. `app=web`, `env=prod`.
- **Selectors**: Match labels; used by Deployment (selector), Service (selector), and when listing: `kubectl get pods -l app=web`.
- Label selectors: equality (`=`, `!=`) or set-based (`in`, `notin`, `exists`).
- Labels are arbitrary key-value metadata; selectors filter objects by label for grouping and targeting.

```yaml
metadata:
  labels:
    app: myapp
    tier: frontend
spec:
  selector:
    matchLabels:
      app: myapp
```

### Probes

- `livenessProbe`: Is the container alive? If fail, kubelet restarts container.
- `readinessProbe`: Is the container ready for traffic? If fail, pod removed from Service endpoints.
- Types: `httpGet`, `tcpSocket`, `exec`; `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`.
- Liveness probe failure restarts the container; readiness probe failure removes it from Service endpoints.

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
readinessProbe:
  tcpSocket:
    port: 8080
  periodSeconds: 3
```

### Lifecycle

- **postStart**: Hook after container starts (run alongside main process).
- **preStop**: Hook before container is terminated; use for graceful shutdown.
- **terminationGracePeriodSeconds**: Time to wait after SIGTERM before SIGKILL.
- `terminationGracePeriodSeconds` defaults to 30 seconds.

### Resources

- **requests**: Guaranteed; scheduler uses this; e.g. `cpu: "100m"`, `memory: "128Mi"`.
- **limits**: Max; container can be throttled (CPU) or OOMKilled (memory) if exceeded.
- Always set requests (and limits where needed) for production.
- Resource `requests` are guaranteed and used for scheduling; `limits` cap usage and trigger throttling/OOMKill.

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

Related notes: [001-kubernetes-overview](./001-kubernetes-overview.md), [003-deployments-rolling-update](./003-deployments-rolling-update.md), [008-resource-requests-limits](./008-resource-requests-limits.md)

---

# Troubleshooting Guide

### Pod not receiving traffic despite being Running
1. Check readiness probe: `kubectl describe pod <name>` — is it passing?
2. If readiness fails, pod is removed from Service endpoints: `kubectl get endpoints <svc>`.
3. Fix: adjust `initialDelaySeconds` or probe path/port.

### Init container stuck / pod in `Init:0/1`
1. Check init container logs: `kubectl logs <pod> -c <init-container-name>`.
2. Init containers run sequentially; if one fails, pod stays in Init state.
3. Common: waiting for dependency (DB, config), wrong image, missing env.

### Liveness probe killing healthy container
1. Probe too aggressive: increase `initialDelaySeconds` and `timeoutSeconds`.
2. App takes long to start: use `startupProbe` instead for slow-starting apps.
3. Check probe endpoint actually returns 200: `kubectl exec <pod> -- curl localhost:8080/health`.
