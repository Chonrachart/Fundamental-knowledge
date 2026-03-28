# Multi-Container Pods

## Overview
**Why it exists** — Some processes are so tightly coupled that they must share the same network namespace and local storage to function; packaging them in one pod avoids inter-pod network hops and lets them communicate over localhost.
**What it is** — A pod that declares more than one container; all containers share the pod's network namespace (same IP, same localhost), and can share volumes explicitly defined in the pod spec.
**One-liner** — Co-locate tightly coupled helper processes with the main app so they share network and storage.

## Architecture (ASCII)

```text
┌─────────────────────── Pod ──────────────────────────┐
│  Shared network namespace (same IP / localhost)       │
│  Shared volumes (explicit volumeMounts)               │
│                                                       │
│  ┌──────────────┐   ┌──────────────┐                 │
│  │  main app    │   │  sidecar     │  (both running) │
│  │  :8080       │   │  log-agent   │                 │
│  └──────┬───────┘   └──────┬───────┘                 │
│         │                  │                          │
│         └────── /var/log (shared emptyDir) ──────────┘
└──────────────────────────────────────────────────────┘

Init containers run sequentially BEFORE main containers start:

initContainers:        │  containers:
  [init-1]  →  [init-2]  →  [main] + [sidecar]
  (sequential)            (all start together)
```

## Mental Model

```text
Decide: should two processes be in the same pod?

YES — same pod if:
  - They MUST share localhost (IPC, same port namespace)
  - They share a volume tightly (log drain, proxy inject)
  - One cannot start without the other being present

NO — separate pods if:
  - They scale independently
  - They can communicate over the network
  - They have independent lifecycles
```

All containers in a pod are scheduled on the same node together. If one container fails and restarts, the others keep running (unless the pod's `restartPolicy` causes the pod to terminate).

## Core Building Blocks

### Sidecar Pattern

**Why it exists** — Adds cross-cutting functionality (logging, proxying, metrics collection) to the main app container without modifying its code.
**What it is** — A secondary container that runs alongside the main app in the same pod, sharing the network namespace and optionally a volume.
**One-liner** — Attach helper functionality to main app via a co-located container.

Common uses:
- **Log agent** (e.g., Fluentd, Filebeat): reads log files the main app writes to a shared volume and ships them to a logging backend
- **Service mesh proxy** (e.g., Envoy/Istio): intercepts all inbound/outbound traffic for mTLS, retries, and observability
- **Metrics exporter**: scrapes the main app's internal metrics and exposes them in Prometheus format

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-sidecar
spec:
  containers:
  - name: main-app
    image: myapp:1.0
    volumeMounts:
    - name: log-volume
      mountPath: /var/log/app
  - name: log-agent
    image: fluent/fluent-bit:latest
    volumeMounts:
    - name: log-volume
      mountPath: /var/log/app
      readOnly: true
  volumes:
  - name: log-volume
    emptyDir: {}
```

### Init Container Pattern

**Why it exists** — Some setup tasks (downloading config, waiting for a dependency, running DB migrations) must complete successfully before the main application starts; init containers provide a guaranteed sequencing mechanism.
**What it is** — Containers listed under `initContainers` that run to completion (exit 0) in order before any container in `containers` starts. If an init container fails, Kubernetes restarts it (per the pod's restart policy) until it succeeds.
**One-liner** — Run ordered setup steps that must succeed before the main app starts.

Common uses:
- Wait for a database or upstream service to be reachable
- Download or render configuration files into a shared volume
- Run database schema migrations
- Clone a git repository before the web server starts

```yaml
initContainers:
- name: wait-for-db
  image: busybox
  command: ['sh', '-c', 'until nc -z db-service 5432; do echo waiting; sleep 2; done']
- name: load-config
  image: curlimages/curl
  command: ['sh', '-c', 'curl -o /config/app.yaml https://config-server/app.yaml']
  volumeMounts:
  - name: config-vol
    mountPath: /config
containers:
- name: main-app
  image: myapp:1.0
  volumeMounts:
  - name: config-vol
    mountPath: /etc/app
```

### Ambassador Pattern

**Why it exists** — Simplifies the main app's networking by providing a local proxy that handles service discovery, authentication, or protocol translation to an external service.
**What it is** — A sidecar container that the main app connects to on localhost; the ambassador translates the local call into an appropriate call to the real external service.
**One-liner** — Local proxy sidecar abstracts the complexity of connecting to an external service.

Example: main app always connects to `localhost:6379`; the ambassador container proxies to the real Redis cluster (with TLS and auth), so the main app needs no Redis-specific configuration.

### Adapter Pattern

**Why it exists** — Different apps produce metrics or logs in different formats; an adapter sidecar normalizes the output so a single monitoring stack can consume all of them.
**What it is** — A sidecar that reads the main app's output (e.g., proprietary metrics endpoint) and transforms it into a standard format (e.g., Prometheus `/metrics`).
**One-liner** — Transform main app output into a standard format for monitoring or logging pipelines.

Example: legacy app exposes metrics as CSV on port 9090; adapter sidecar reads that and re-exposes as Prometheus-compatible `/metrics` on port 8080.

### Pattern Comparison

| Pattern | Runs when | Direction | Primary purpose |
|---|---|---|---|
| Sidecar | Alongside main (entire pod life) | Both | Enhance/extend main app (logging, proxy) |
| Init container | Before main containers start | Sequential setup | Preconditions, setup tasks |
| Ambassador | Alongside main | Outbound proxy | Simplify external service access |
| Adapter | Alongside main | Inbound normalization | Standardize main app output |

### Two Containers Sharing a Volume (Full Example)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: shared-volume-pod
spec:
  containers:
  - name: writer
    image: busybox
    command: ['sh', '-c', 'while true; do date >> /data/output.txt; sleep 5; done']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  - name: reader
    image: busybox
    command: ['sh', '-c', 'tail -f /data/output.txt']
    volumeMounts:
    - name: shared-data
      mountPath: /data
  volumes:
  - name: shared-data
    emptyDir: {}   # lives as long as the pod; wiped on pod deletion
```

## Troubleshooting

### Init container keeps restarting — main app never starts
1. Check init container logs: `kubectl logs <pod> -c <init-container-name>`
2. Check init container status: `kubectl describe pod <pod>` — look at `Init Containers` section
3. Common causes: dependency not yet reachable, wrong command, missing volume or ConfigMap

### Sidecar container crashes, main app still running
1. Pod stays Running as long as main app runs (init containers are done)
2. Check sidecar logs: `kubectl logs <pod> -c <sidecar-name>`
3. Sidecar crash does not kill the pod unless `restartPolicy: Never` and the container exits

### Containers cannot communicate over localhost
1. All containers in a pod share the same network namespace — localhost works by design
2. Verify the target container is actually listening on the expected port: `kubectl exec <pod> -c <container> -- netstat -tlnp`
3. Check for port conflicts between containers in the same pod
