# kubectl Debugging Commands

# Overview
- **Why it exists** — Kubernetes resources are managed through the API server; you need tools to inspect cluster state, stream container output, and interact with running containers.
- **What it is** — A reference for the core `kubectl` commands used in debugging: getting resource status, describing events, reading logs, executing into containers, forwarding ports, and checking resource usage.
- **One-liner** — The standard debugging loop is: `get` (status) → `describe` (events) → `logs` (app output) → `exec` (inspect inside).

# Architecture

```text
kubectl CLI
    │
    ▼  (REST/HTTPS :6443)
API Server ──── authenticates + authorizes request
    │
    ├── read operations (get, describe) ──► etcd (cluster state)
    │
    └── exec / logs / port-forward
            │
            ▼  (kubelet API :10250)
        kubelet on target node
            │
            ▼
        container runtime (containerd)
            │
            ▼
        target container (stdin/stdout/exec)
```

# Mental Model

```text
Debugging loop:

kubectl get pods          →  What is the status? Running / Pending / CrashLoopBackOff?
kubectl describe pod      →  Why? Check the Events section at the bottom.
kubectl logs (--previous) →  What did the app print before crashing?
kubectl exec -it -- sh    →  What does the filesystem / network / env look like inside?
kubectl get events        →  What is happening across the whole namespace?
```

Most problems surface in one of three places:
1. **Events** (from `describe`) — scheduler decisions, image pull failures, probe failures
2. **Logs** — app-level errors, missing config, dependency failures
3. **Inside the container** (`exec`) — wrong files, missing env vars, connectivity issues

# Core Building Blocks

### kubectl get
- **Why it exists** — First step in any debug; shows the current state of one or many resources at a glance.
- **What it is** — Lists resources with status columns. Supports output formats, label filters, and watch mode.
- **One-liner** — `kubectl get pods -o wide` is the first command in most debugging sessions.

```bash
kubectl get pods -n production              # pods in a specific namespace
kubectl get pods -A                         # pods in ALL namespaces
kubectl get pods -o wide                    # adds Node and IP columns
kubectl get pods -o yaml                    # full spec and status as YAML
kubectl get pods -l app=web                 # filter by label selector
kubectl get pods --watch                    # live updates (Ctrl-C to stop)
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get deployment,svc,pods             # multiple resource types at once
kubectl get all                             # common resources in namespace
```

| Flag | What it shows |
|------|---------------|
| `-o wide` | Node name, pod IP |
| `-o yaml` | Full spec + status |
| `-l key=val` | Filter by label |
| `-A` | All namespaces |
| `--watch` | Stream changes |

---

### kubectl describe
- **Why it exists** — `get` shows current state; `describe` explains *why* the resource is in that state via the Events section.
- **What it is** — Prints full resource metadata, spec, status fields, and a chronological Events list. The Events section is the most useful place to find scheduling failures, image pull errors, and probe failures.
- **One-liner** — Always check `kubectl describe pod` before looking at logs.

```bash
kubectl describe pod <name> -n <namespace>  # pod detail + events
kubectl describe node <name>                # node capacity, conditions, pods
kubectl describe svc <name>                 # service selector, endpoints
kubectl describe pvc <name>                 # PVC binding status
```

Key sections to read in `kubectl describe pod`:
- **Status / Conditions** — Ready, Initialized, ContainersReady
- **Events** — scheduler decisions, image pull status, probe failures, OOMKilled

---

### kubectl logs
- **Why it exists** — Container stdout/stderr is the primary source of application-level error information.
- **What it is** — Streams or retrieves logs from a container. For full coverage of log management, aggregation, and retention see `03-logging-monitoring/001-managing-logs.md`.
- **One-liner** — Use `--previous` after a crash to see what the container printed before it died.

```bash
kubectl logs <pod>                          # first container in pod
kubectl logs <pod> -c <container>           # specific container (multi-container pod)
kubectl logs -f <pod>                       # follow / tail -f
kubectl logs --previous <pod>              # logs from last crashed instance
kubectl logs deployment/myapp              # logs from one pod of a Deployment
kubectl logs <pod> --tail=50               # last 50 lines only
```

> For persistent log storage, aggregation (Loki, Elasticsearch), and log rotation, see `03-logging-monitoring/001-managing-logs.md`.

---

### kubectl exec
- **Why it exists** — Lets you inspect the inside of a running container: check files, env vars, DNS resolution, and network connectivity.
- **What it is** — Runs a command in a container via the kubelet API. `-it` opens an interactive TTY session. `--` separates kubectl flags from the command passed to the container.
- **One-liner** — `kubectl exec -it <pod> -- sh` drops you into a shell inside the container.

```bash
kubectl exec -it <pod> -- sh                       # interactive shell (sh)
kubectl exec -it <pod> -- bash                     # interactive shell (bash)
kubectl exec <pod> -- env                          # print env vars (non-interactive)
kubectl exec -it <pod> -c <container> -- sh        # specific container in multi-container pod
kubectl exec <pod> -- cat /etc/config/app.yaml     # read a file
kubectl exec <pod> -- ss -tlnp                     # check listening ports
```

Notes:
- Use `--` to separate kubectl flags from the container command.
- Prefer ephemeral debug containers (`kubectl debug`) in production; `exec` requires the container to be running and have a shell binary.

---

### kubectl port-forward
- **Why it exists** — Lets you reach a pod or service on its container port from your local machine without exposing it through an Ingress or LoadBalancer.
- **What it is** — Opens a TCP tunnel from `localhost:<local-port>` to `<pod/service>:<remote-port>` through the API server and kubelet.
- **One-liner** — Forward a local port to a pod port for quick local testing without changing the service.

```bash
kubectl port-forward pod/<name> 8080:80         # local 8080 → pod port 80
kubectl port-forward svc/<name> 8080:80         # forward to a Service
kubectl port-forward deployment/myapp 8080:80   # picks one pod from Deployment
```

Notes:
- Ties up the terminal while running; Ctrl-C to stop.
- Not for production traffic — use for dev/debug only.
- If the pod restarts, the tunnel drops and must be re-established.

---

### kubectl top
- **Why it exists** — Shows real-time CPU and memory usage for pods and nodes; essential for diagnosing resource pressure and OOMKilled events.
- **What it is** — Queries the metrics-server (must be installed separately) for live resource metrics.
- **One-liner** — `kubectl top pods` shows which pods are consuming the most CPU/memory right now.

```bash
kubectl top pods                            # CPU/memory for all pods in current namespace
kubectl top pods -n kube-system            # control plane component usage
kubectl top pods --sort-by=memory          # sort by memory usage
kubectl top nodes                           # CPU/memory usage per node
```

> Requires `metrics-server` to be running in the cluster. If you see `error: metrics not available`, deploy metrics-server first.

---

### kubectl get events
- **Why it exists** — Events are written by controllers, the scheduler, and the kubelet whenever something notable happens; they are often the fastest way to see what went wrong across a namespace.
- **What it is** — Cluster-scoped event objects that record reasons, messages, and counts for resource state changes.
- **One-liner** — `kubectl get events --sort-by=.lastTimestamp` gives a chronological view of what just happened.

```bash
kubectl get events -n <namespace>                          # all events in namespace
kubectl get events --sort-by=.lastTimestamp               # newest last (most useful)
kubectl get events --sort-by=.lastTimestamp -A            # all namespaces, newest last
kubectl get events --field-selector involvedObject.name=<pod>  # events for one pod
```

| Column | Meaning |
|--------|---------|
| `REASON` | Short code: `Scheduled`, `Pulling`, `Failed`, `OOMKilling` |
| `MESSAGE` | Human-readable detail |
| `COUNT` | How many times this event fired |
| `LAST SEEN` | When it last occurred |

# Troubleshooting

### Pod is Running but application is not responding
1. Check whether the pod is actually Ready: `kubectl get pods -o wide` — look at the READY column (e.g. `0/1` means container is up but not ready).
2. Inspect readiness probe failures: `kubectl describe pod <name>` — Events will show `Readiness probe failed` with the HTTP status or command exit code.
3. Port-forward directly to the pod to bypass the Service: `kubectl port-forward pod/<name> 8080:80` — then `curl localhost:8080` to confirm the app itself responds.
4. If the app responds via port-forward but not via Service, check the Service selector: `kubectl describe svc <name>` and compare the `Selector:` field against actual pod labels (`kubectl get pods --show-labels`).

### kubectl exec fails — "error: unable to upgrade connection"
1. Confirm the target pod is Running: `kubectl get pod <name>` — exec requires the container to be in a running state.
2. Check that the node hosting the pod is Ready: `kubectl get nodes` — if the node is `NotReady`, kubelet cannot serve exec requests.
3. Verify network connectivity between your machine and the node's kubelet port (10250): this is required for exec and logs tunneling.
4. If the container has no shell binary, use an ephemeral debug container instead: `kubectl debug -it <pod> --image=busybox --target=<container>`.

### Logs show nothing / kubectl logs returns empty output
1. The container may have just started or crashed before writing anything — check `kubectl describe pod <name>` Events for the exit code.
2. Use `--previous` to read the last terminated instance: `kubectl logs --previous <pod>`.
3. If the pod is in `Init:x/y` state, the main container hasn't started — read init container logs: `kubectl logs <pod> -c <init-container-name>`.
4. Some apps write to files rather than stdout — exec into the container and check common log paths: `kubectl exec <pod> -- ls /var/log/` or the app's configured log directory.

### Node resource pressure — pods evicted or OOMKilled
1. Check node conditions: `kubectl describe node <name>` — look for `MemoryPressure`, `DiskPressure`, or `PIDPressure` in the Conditions table.
2. Identify the heaviest consumers: `kubectl top pods -A --sort-by=memory` and `kubectl top nodes`.
3. Review evicted pod events: `kubectl get events -A | grep Evict` to identify which pods were removed and from which node.
4. Remediate by adding resource `requests`/`limits` to pods that lack them, enabling LimitRange defaults in the namespace, or cordoning the pressured node (`kubectl cordon <node>`) and draining it (`kubectl drain <node> --ignore-daemonsets`) before investigating disk or memory usage.
