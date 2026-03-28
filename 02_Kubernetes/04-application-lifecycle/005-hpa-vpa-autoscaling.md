# HPA, VPA, and Autoscaling

# Overview
- **Why it exists** — Manual replica scaling cannot react fast enough to traffic spikes and wastes resources during off-peak hours; autoscaling adjusts capacity automatically in response to real demand.
- **What it is** — HPA (Horizontal Pod Autoscaler) scales replica count up/down based on CPU, memory, or custom metrics; VPA (Vertical Pod Autoscaler) adjusts the requests/limits of existing pods instead of changing replica count.
- **One-liner** — HPA scales out (more pods); VPA scales up (bigger pods) — both remove the need for manual intervention.

# Architecture

```text
                    ┌───────────────┐
                    │ metrics-server│  (or Prometheus adapter for custom)
                    └───────┬───────┘
                            │ CPU / memory / custom metrics
                            ▼
┌──────────────────────────────────────────────────┐
│  HPA Controller (runs in kube-controller-manager)│
│                                                  │
│  every 15s:                                      │
│    current = avg metric across pods              │
│    desired = ceil(current * currentVal/targetVal)│
│    clamp to [minReplicas, maxReplicas]           │
│    apply scaleDown stabilization (default 300s)  │
└──────────────────┬───────────────────────────────┘
                   │ patch .spec.replicas
                   ▼
            ┌──────────────┐
            │  Deployment  │ ──► ReplicaSet ──► Pods
            └──────────────┘
```

# Mental Model

```text
Scenario: Deployment with HPA (min=2, max=10, target CPU=70%)

Normal load:
  HPA sees avg CPU = 30% → keeps 2 replicas (at minimum)

Traffic spike:
  HPA sees avg CPU = 85% → desired = ceil(2 * 85/70) = ceil(2.43) = 3
  Next interval: still high → scales to 4... up to 10 max

Load drops:
  HPA sees avg CPU = 20% → wants to scale down
  Waits 300s (stabilizationWindowSeconds) before acting
  → prevents flapping when load is intermittent
```

# Core Building Blocks

### How HPA Works

- **Why it exists** — Eliminates the need to manually adjust replicas as traffic fluctuates; reacts within seconds to sustained metric changes.
- **What it is** — A control loop running in the controller-manager that polls metrics every 15 seconds, computes the desired replica count, and patches the target Deployment (or StatefulSet).
- **One-liner** — Control loop that polls metrics every 15s and adjusts replica count within configured bounds.

Key points:
- HPA requires `metrics-server` for CPU/memory metrics (or a custom metrics adapter for anything else)
- Pods must have resource **requests** set — HPA calculates utilization as `usage / request`
- Do not manually `kubectl scale` a Deployment that HPA manages — HPA will override it

### kubectl autoscale (Imperative)

- **Why it exists** — Provides a fast one-liner to create an HPA without writing YAML, useful for quick testing or initial setup.
- **What it is** — The imperative `kubectl autoscale` command that creates an HPA resource targeting a Deployment with CPU utilisation, min, and max replica bounds.
- **One-liner** — Create an HPA in one command without a manifest.

```bash
kubectl autoscale deployment myapp --cpu-percent=70 --min=2 --max=10
kubectl get hpa
kubectl describe hpa myapp
```

### HPA YAML Spec

- **Why it exists** — The declarative YAML form of HPA supports advanced configuration (multiple metrics, scale-up/down behaviour policies) that the imperative command cannot express.
- **What it is** — A `HorizontalPodAutoscaler` manifest using `autoscaling/v2` that declares target metrics, replica bounds, and optional stabilisation and rate-limiting behaviour.
- **One-liner** — Declarative HPA with full control over metrics, replica bounds, and scale behaviour policies.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300   # wait 5 min before scaling down
      policies:
      - type: Pods
        value: 1
        periodSeconds: 60               # remove at most 1 pod per minute
    scaleUp:
      stabilizationWindowSeconds: 0    # scale up immediately
```

### CPU / Memory / Custom Metrics

- **Why it exists** — CPU and memory alone are insufficient for workloads that scale on queue depth, request rate, or external signals; the metrics taxonomy explains which adapter to use for each scenario.
- **What it is** — The four HPA metric source types (`Resource`, `Pods`, `Object`, `External`) and the adapter or component that must supply each one.
- **One-liner** — Pick the right metric type and adapter based on whether you scale on CPU, per-pod rate, a K8s object, or an external signal.

| Metric type | Source | Example use case |
|---|---|---|
| `Resource` (cpu/memory) | `metrics-server` | Standard CPU or memory utilization |
| `Pods` (custom per-pod) | Custom metrics adapter | Requests-per-second per pod |
| `Object` (metric from a K8s object) | Custom metrics adapter | Ingress requests per second |
| `External` (outside cluster) | External metrics adapter | SQS queue depth, Pub/Sub backlog |

For custom metrics, deploy an adapter such as the Prometheus adapter or KEDA.

### VPA Overview

- **Why it exists** — Some workloads (batch jobs, stateful apps) cannot scale horizontally; VPA right-sizes their resource requests/limits based on historical usage so they are neither starved nor over-provisioned.
- **What it is** — A separate controller (not built into Kubernetes) that watches pod metrics over time and recommends — or automatically applies — updated requests/limits to containers.
- **One-liner** — Automatically right-sizes container resource requests/limits based on observed usage.

VPA operates in three modes:

| Mode | Behavior |
|---|---|
| `Off` | Only produces recommendations; no changes made |
| `Initial` | Sets requests on new pods only; running pods unchanged |
| `Auto` | Evicts and restarts pods to apply new requests/limits |

> **Warning:** VPA `Auto` mode restarts pods to apply changes, which causes brief disruption. Do not use HPA and VPA on the same metric for the same Deployment — they conflict.

### HPA vs VPA Comparison

| Dimension | HPA | VPA |
|---|---|---|
| What it changes | Replica count | requests/limits per container |
| Scaling axis | Horizontal (more pods) | Vertical (bigger pods) |
| Works well for | Stateless apps with variable traffic | Stateful apps, batch jobs, right-sizing |
| Conflict risk | Conflicts with manual `kubectl scale` | Conflicts with HPA on same metric |
| Disruption | None (new pods added) | `Auto` mode evicts/restarts pods |
| Requires metrics-server | Yes | Yes |
| Built into Kubernetes | Yes | No (separate install) |

### metrics-server Requirement

HPA (and VPA) depend on `metrics-server` being installed and running in the cluster:

```bash
kubectl get pods -n kube-system | grep metrics-server
kubectl top nodes     # if this works, metrics-server is functioning
kubectl top pods      # per-pod CPU and memory
```

Without metrics-server, HPA remains in an `<unknown>` state and does not scale.

# Troubleshooting

### HPA not scaling — replicas stay at minimum
1. Check metrics-server: `kubectl get pods -n kube-system | grep metrics-server`
2. Check HPA status: `kubectl describe hpa <name>` — look at `Conditions` and `Current Metrics`
3. Verify pods have `requests` set — HPA cannot compute utilization without them
4. Confirm `kubectl top pods` returns data (not `<unknown>`)

### HPA flapping — scales up and down repeatedly
1. Increase `stabilizationWindowSeconds` in `behavior.scaleDown` (default 300s may not be enough)
2. Add a scale-down policy: max N pods per minute
3. Check if the metric itself is noisy; consider using a custom metric with smoothing or KEDA

### HPA shows `<unknown>` for metrics
1. metrics-server not installed or not ready
2. Pod has no resource requests set (HPA cannot calculate utilization)
3. Container image / app not exposing metrics on expected endpoint
