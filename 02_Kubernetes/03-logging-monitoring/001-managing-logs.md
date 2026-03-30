# Managing Logs in Kubernetes

# Overview
- **Why it exists** — Containers are ephemeral; when a pod restarts or is deleted, container stdout/stderr is lost unless captured by a persistent logging system.
- **What it is** — A set of tools and patterns for collecting, viewing, and persisting container logs — from `kubectl logs` for local debugging to DaemonSet-based log aggregation for production clusters.
- **One-liner** — `kubectl logs` for debugging; cluster-level logging agent for production persistence.

- Containers are ephemeral; when a pod is deleted or restarted, container stdout/stderr is lost unless captured.
- `kubectl logs` retrieves container stdout/stderr from the kubelet on the node where the pod runs.
- Cluster-level logging requires a separate system (DaemonSet agent, sidecar, or direct backend integration) to persist logs beyond pod lifetime.

# Architecture

```text
Container stdout/stderr
        │
        ▼
kubelet (node-local storage)
        │
        ├─► kubectl logs ────► local inspection
        │
        ├─► DaemonSet agent (Fluentd, Logstash)
        │       │
        │       ▼
        │   Backend (Elasticsearch, S3, Splunk)
        │
        ├─► Sidecar container
        │       │
        │       ▼
        │   Application logging service
        │
        └─► Direct app → Backend (no intermediate agent)
```

# Mental Model

```text
Scenario: Debugging an app that crashed

1. Pod is Running, but logs show an error
   └─ kubectl logs <pod>
      → "Error: Connection refused"

2. Pod crashed and restarted
   └─ kubectl logs <pod> --previous
      → logs from before the crash

3. Multi-container pod: which container failed?
   └─ kubectl logs <pod> -c <container-name>
      → narrowed to specific container

4. Need to see last 100 lines in real-time
   └─ kubectl logs <pod> -f --tail=100
      → streaming live output

5. Aggregating logs across many pods
   └─ kubectl logs -l app=myapp --all-containers=true
      → all pods matching label, all containers
```

# Core Building Blocks

### kubectl logs -- Retrieve Container Logs

- **Why it exists** — Developers need a quick way to inspect what a container wrote to stdout/stderr without shelling into the node or setting up a full logging pipeline.
- **What it is** — A kubectl subcommand that retrieves container logs from the kubelet on the node where the pod runs; supports filtering by container, following live output, tailing lines, time ranges, and fetching logs from a previously crashed container instance.
- **One-liner** — `kubectl logs` is the first-stop debugging tool for reading container stdout/stderr directly from the kubelet.

- Reads from kubelet on the node; default reads from first container in pod.
- Use `-c <container>` for multi-container pods; `--previous` for crashed instances.
- Only works if kubelet retains logs; no persistence after pod deletion.

```bash
# Basic: first container in a pod
kubectl logs <pod>

# Specific container in multi-container pod
kubectl logs <pod> -c <container-name>

# Follow live (like tail -f)
kubectl logs <pod> -f

# Last 100 lines (useful for large logs)
kubectl logs <pod> --tail=100

# Logs from last 5 minutes
kubectl logs <pod> --since=5m

# Logs from previous container (after crash or restart)
kubectl logs <pod> --previous

# All containers in a pod
kubectl logs <pod> --all-containers=true

# All pods matching a label
kubectl logs -l app=myapp --all-containers=true

# From a deployment (picks first pod)
kubectl logs deployment/myapp

# Follow with timestamp
kubectl logs <pod> -f --timestamps=true
```

- `--previous` only works if the kubelet has saved the previous container's logs (configurable).
- `-l <label>` selects pods by label; useful for aggregating logs from a Deployment.

### Cluster-Level Logging Approaches

Three main patterns for persistent log collection:

| Approach | Agent | Pros | Cons |
|----------|-------|------|------|
| **Node-level DaemonSet** | Fluentd, Logstash, Filebeat on every node | Minimal pod overhead; centralized setup | Depends on node filesystem access; can miss logs if pod deleted before agent reads |
| **Sidecar container** | Logging container in pod spec | Tightly coupled logging config with app; logs app's stdout/stderr | One sidecar per pod; resource overhead |
| **Direct app logging** | Application writes directly to backend | No intermediate agent; low latency | Logging code in app; each app needs SDK/config |

**Node-level DaemonSet example:**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  template:
    spec:
      containers:
      - name: fluentd
        image: fluent/fluentd:latest
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

**Sidecar container example:**
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-logging
spec:
  containers:
  - name: app
    image: myapp:latest
    stdout: stream
  - name: log-forwarder
    image: fluent/fluent-bit:latest
    volumeMounts:
    - name: shared-logs
      mountPath: /logs
  volumes:
  - name: shared-logs
    emptyDir: {}
```

### Log Aggregation and Backend

**EFK Stack (Elasticsearch, Fluent Bit, Kibana):**
- Fluent Bit agents (DaemonSet) forward logs to Elasticsearch.
- Kibana queries and visualizes logs with full-text search.
- Popular for large clusters; centralized log storage and analysis.

**ELK Stack (Elasticsearch, Logstash, Kibana):**
- Heavier than Fluent Bit; more data transformation features.
- Logstash sits between log source and Elasticsearch.

**Other backends:**
- CloudWatch (AWS), Stackdriver (GCP), Application Insights (Azure).
- Splunk, Datadog, New Relic (third-party SaaS).

### Best Practices

- Set appropriate log levels; avoid verbose logging in production (impacts performance and storage).
- Rotate logs on nodes to prevent disk exhaustion; kubelet has log rotation built-in.
- Use structured logging (JSON) for easier parsing and aggregation.
- Ensure cluster-level logging is configured for any production cluster.
- Do not rely solely on `kubectl logs` for production debugging; deploy a persistent logging solution.

Related notes: [006-kubectl-debugging](../006-kubectl-debugging.md), [002-pods-labels](../002-pods-labels.md)
