# kube-controller-manager

### Overview

- **Why it exists** — Kubernetes is declarative: you declare desired state and something must continuously watch for drift and correct it. Without controllers, objects would be created but nothing would act on them.
- **What it is** — A single binary that runs many independent control loops (controllers) in one process. Each controller watches a specific resource type, compares desired state to actual state, and takes corrective action. Controllers never talk to each other — each only watches the API server.
- **One-liner** — The controller manager is the automation engine that keeps actual cluster state matching desired state through continuous reconciliation loops.

### Architecture

```text
                    ┌─────────────────────────────────────────┐
                    │         kube-controller-manager         │
                    │                                         │
                    │  ┌─────────────────────────────────┐    │
                    │  │  Deployment Controller          │    │
                    │  │  ReplicaSet Controller          │    │
                    │  │  Node Controller                │    │
                    │  │  Endpoint Controller            │    │
                    │  │  Namespace Controller           │    │
                    │  │  ServiceAccount Controller      │    │
                    │  │  Job Controller                 │    │
                    │  │  CronJob Controller             │    │
                    │  │  ... (dozens more)              │    │
                    │  └─────────────────────────────────┘    │
                    └─────────────────┬───────────────────────┘
                                      │ watch / write
                                      ▼
                              ┌───────────────┐
                              │  API Server   │
                              └───────────────┘
```

### Mental Model

```text
The Reconcile Loop (every controller follows this pattern):

  1. Watch API server for resource changes (Informer/cache)
          │
          ▼
  2. Compare desired state vs actual state
          │
     ┌────┴──────────────────────────────────────────┐
     │  desired == actual?                           │
     │    YES → do nothing, requeue after interval   │
     │    NO  → take action to close the gap         │
     └───────────────────────────────────────────────┘
          │ (if NO)
          ▼
  3. Take corrective action (create/delete/update objects)
          │
          ▼
  4. Update status on the object
          │
          ▼
  5. Repeat

Mental shortcut:  if desired ≠ actual → take action
```

Example — ReplicaSet controller:
```text
Desired: 3 pods with label app=web
Actual:  2 pods running (one crashed)

Action:  Create 1 new pod matching the pod template
Result:  3 pods running → reconciled
```

### Core Building Blocks

### Deployment Controller

- **Why it exists** — Deployments need to manage ReplicaSets and orchestrate rolling updates without manual intervention.
- **What it is** — Watches Deployment objects. When a Deployment is created, it creates a ReplicaSet. When the pod template changes (new image, env var, etc.), it creates a new ReplicaSet and manages the transition (scaling new RS up, old RS down) according to the rollout strategy.
- **One-liner** — The Deployment controller manages the lifecycle of ReplicaSets on behalf of Deployments.

### ReplicaSet Controller

- **Why it exists** — The declared number of pod replicas must always be maintained, even as pods crash or nodes fail.
- **What it is** — Watches ReplicaSet objects. Continuously checks that the number of running pods matching the selector equals `spec.replicas`. If a pod is missing, creates one. If there are too many, deletes the excess.
- **One-liner** — The ReplicaSet controller is the "N pods must always run" enforcer.

### Node Controller

- **Why it exists** — The cluster must know when nodes become unhealthy and pods need to be rescheduled.
- **What it is** — Monitors node health by watching heartbeats from kubelet. If a node stops reporting in, the node controller marks it `NotReady` (after ~40s). It then adds the `node.kubernetes.io/not-ready:NoExecute` taint with `tolerationSeconds: 300`. Pods that do not tolerate this taint are evicted after 300s (5 min) so they can be rescheduled elsewhere. This is taint-based eviction (the default since Kubernetes 1.18).
- **One-liner** — The node controller detects dead nodes and triggers pod eviction.

### Endpoint Controller (and EndpointSlice Controller)

- **Why it exists** — Services need an up-to-date list of healthy pod IPs so kube-proxy can route traffic correctly.
- **What it is** — Watches Services and Pods. When pods matching a Service's selector become Ready or NotReady, it updates the Endpoints (or EndpointSlice) object with the current list of pod IPs and ports. kube-proxy then reads this to update iptables rules.
- **One-liner** — The endpoint controller keeps the Service-to-pod IP mapping current.

### Other Notable Controllers

| Controller | What it reconciles |
|-----------|-------------------|
| Namespace Controller | Cleans up resources when a namespace is deleted |
| ServiceAccount Controller | Ensures every namespace has a `default` ServiceAccount |
| Job Controller | Creates pods for Jobs; tracks completions |
| CronJob Controller | Creates Jobs on a cron schedule |
| HPA Controller | Scales Deployments/StatefulSets based on metrics |
| PersistentVolume Controller | Binds PVCs to available PVs |

### The Reconcile Loop Concept

```bash
# You can observe reconciliation in action:

# Scale down manually (creates drift)
kubectl scale deployment myapp --replicas=1

# Watch controller bring it back to 3 (desired state)
kubectl get pods -w

# Another example: delete a pod directly
kubectl delete pod myapp-abc123

# ReplicaSet controller immediately creates a replacement
kubectl get pods   # new pod appears within seconds
```

### Troubleshooting

### Deployment created but no pods appear

1. Check if ReplicaSet was created: `kubectl get rs` — if missing, Deployment controller may have an issue.
2. Check events: `kubectl describe deployment <name>` — Events section.
3. Check controller-manager logs: `kubectl logs -n kube-system -l component=kube-controller-manager`.

### Pods not being replaced after node failure

1. Check if Node controller has marked node NotReady: `kubectl get nodes`.
2. Node eviction has a grace period (default ~5 min after NotReady) — pods may not evict immediately.
3. Check pod tolerations — pods with `tolerationSeconds` set may wait longer before eviction.

### controller-manager not running

1. `kubectl get pods -n kube-system -l component=kube-controller-manager`.
2. Kubernetes still schedules pods (scheduler is separate) but no reconciliation happens.
3. New deployments won't get ReplicaSets; crashed pods won't be replaced.
