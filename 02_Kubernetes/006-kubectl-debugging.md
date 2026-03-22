# kubectl Debugging and Resource Inspection

- `kubectl` talks to the cluster API server; uses `kubeconfig` (default `~/.kube/config`) for cluster, user, context.
- Most commands are namespaced; use `-n <namespace>` or `--all-namespaces` (`-A`).
- Core debugging loop: get (status) -> describe (events) -> logs (app output) -> exec (inspect inside container).

# Debugging Workflow

```text
Pod issue reported
      |
      v
kubectl get pods ──→ Running? Pending? CrashLoopBackOff?
      |
      v
kubectl describe pod ──→ Events: image pull, probe failure, resource limits
      |
      v
kubectl logs (--previous) ──→ Application errors, crash output
      |
      v
kubectl exec -it -- sh ──→ Check files, connectivity, env vars
      |
      v
kubectl get events -n <ns> ──→ Cluster-wide events for the namespace
```

# Mental Model

```text
Scenario: Pod stuck in CrashLoopBackOff

1. kubectl get pods
   → STATUS: CrashLoopBackOff, RESTARTS: 5

2. kubectl describe pod myapp-xyz
   → Events: Back-off restarting failed container
   → Last State: Terminated, Exit Code: 1

3. kubectl logs myapp-xyz --previous
   → "Error: DATABASE_URL not set"

4. Fix: add missing env var to Deployment spec, re-apply
```

# Core Building Blocks

### Context and Configuration

- `kubectl config get-contexts`: list contexts.
- `kubectl config use-context <name>`: switch context.
- Kubeconfig holds cluster endpoint, credentials, and namespace defaults.

### get -- List Resources

```bash
kubectl get pods -n production
kubectl get pods -o wide                        # adds node, IP
kubectl get pods -o yaml                        # full spec
kubectl get pods -l app=web                     # filter by label
kubectl get pods -w                             # watch for changes
kubectl get pods --sort-by=.metadata.creationTimestamp
kubectl get deployment,svc,pods                 # multiple types
kubectl get all                                 # common resources
```

- `-o jsonpath`, `-o custom-columns`: custom output formats.
- `kubectl get pods -o wide` shows node placement and pod IP -- first step in most debugging.

### describe -- Detailed Info and Events

- `kubectl describe pod <name>`: shows spec, status, events; why a pod is Pending, CrashLoopBackOff, etc.
- `kubectl describe node <name>`: node capacity, allocatable, conditions, pods.
- Events at bottom: scheduler decisions, pull errors, probe failures, OOMKilled.
- `kubectl describe` Events section is the most useful place to find scheduling and image pull failures.
- `kubectl get events --sort-by=.lastTimestamp` shows recent cluster events in order.
- Always check pod status (get), then events (describe), then app output (logs) -- in that order.

### logs -- Container Logs

```bash
kubectl logs <pod>                              # logs from first container
kubectl logs <pod> -c <container>               # multi-container pod
kubectl logs -f <pod>                           # follow (like tail -f)
kubectl logs --previous <pod>                   # previous container instance (after crash)
kubectl logs deployment/myapp                   # logs from one pod of deployment
```

- `kubectl logs --previous` retrieves logs from the last crashed container instance.

### exec -- Run Command in Container

```bash
kubectl exec -it <pod> -- sh                    # interactive shell
kubectl exec <pod> -- env                       # non-interactive command
kubectl exec -it <pod> -c <container> -- sh     # specific container
```

- `--` separates kubectl args from the command passed to the container.
- Use for debug; avoid in production; prefer ephemeral debug containers.
- `--` in `kubectl exec` separates kubectl flags from the command to run inside the container.

### port-forward -- Access Service or Pod Locally

```bash
kubectl port-forward pod/<name> 8080:80         # local 8080 -> pod port 80
kubectl port-forward svc/<name> 8080:80         # forward to service
kubectl port-forward deployment/myapp 8080:80   # picks a pod of deployment
```

- Useful for local testing; not for production traffic.
- `kubectl port-forward` is for local dev/debug only; it ties up a terminal and is not production-grade.

Related notes: [001-kubernetes-overview](./001-kubernetes-overview.md), [002-pods-labels](./002-pods-labels.md)

---

# Troubleshooting Guide

### Pod stuck in Pending
1. Check events: `kubectl describe pod <name>` -- Events section shows why.
2. Insufficient resources: `kubectl describe node <node>` -- compare Allocatable vs Allocated.
3. nodeSelector/affinity: verify node labels match: `kubectl get nodes --show-labels`.
4. PVC not bound: `kubectl get pvc` -- if Pending, no matching PV or StorageClass issue.

### ImagePullBackOff
1. Check image name/tag: `kubectl describe pod <name>` -- look for "Failed to pull image".
2. Private registry: add `imagePullSecrets` to pod spec or default `ServiceAccount`.
3. Network: node can't reach registry; check DNS and proxy on the node.

### CrashLoopBackOff
1. Check logs: `kubectl logs <pod>` and `kubectl logs <pod> --previous`.
2. Check exit code: `kubectl describe pod <pod>` -- Last State -> Exit Code.
3. Common causes: missing env/config, wrong CMD, dependency not available.
4. Debug: `kubectl run debug --image=<same-image> -it --rm -- sh`.

### Node NotReady
1. Check conditions: `kubectl describe node <name>` -- look at Conditions table.
2. SSH to node, check `kubelet`: `systemctl status kubelet` and `journalctl -u kubelet -n 50`.
3. Common: `kubelet` stopped, container runtime down, disk/memory pressure, network.

### Cannot connect to pod via port-forward
1. Verify pod is Running: `kubectl get pod <name>`.
2. Check port matches: `kubectl port-forward pod/<name> 8080:<container-port>`.
3. Check app is actually listening: `kubectl exec <pod> -- ss -tlnp`.
