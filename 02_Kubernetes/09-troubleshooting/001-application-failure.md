# Application Failure Troubleshooting

# Overview
- **Why it exists** — Application pods fail for predictable, recurring reasons; knowing the symptom-to-cause mapping cuts debug time dramatically.
- **What it is** — Scenario-based guide covering the most common pod failure modes: each scenario is symptom → check commands → likely cause → fix.
- **One-liner** — Start with `kubectl get pods`, move to `kubectl describe pod` Events, then `kubectl logs --previous`.

# Mental Model

```text
Pod issue reported
      |
      v
kubectl get pods ──→ Running? Pending? CrashLoopBackOff? ImagePullBackOff?
      |
      v
kubectl describe pod ──→ Events: scheduler decisions, pull errors, probe failures, OOMKilled
      |
      v
kubectl logs --previous ──→ Application errors, crash output, missing config
      |
      v
kubectl exec -it -- sh ──→ Check files, env vars, connectivity inside container
      |
      v
kubectl get events --sort-by=.lastTimestamp ──→ Namespace-wide timeline
```

### Troubleshooting Scenarios

---

### 1. Pod Stuck in Pending

**Symptom:** `kubectl get pods` shows `STATUS: Pending` and it never progresses.

**What it means:** The scheduler cannot place the pod on any node.

**Check commands:**
```bash
kubectl describe pod <name> -n <namespace>          # read the Events section
kubectl get nodes --show-labels                     # verify node labels for affinity rules
kubectl describe node <node-name>                   # check Allocatable vs Requests
kubectl get pvc -n <namespace>                      # check if PVC is bound
```

**Likely causes and fixes:**

| Cause | Evidence in Events | Fix |
|-------|-------------------|-----|
| Insufficient CPU/memory | `0/3 nodes are available: 3 Insufficient cpu` | Reduce pod resource requests, or add nodes |
| Node taint not tolerated | `node(s) had untolerated taint` | Add `tolerations` to pod spec |
| nodeSelector / affinity mismatch | `node(s) didn't match node selector` | Fix labels on nodes or relax affinity rules |
| PVC not bound | PVC stays `Pending` | Check StorageClass exists, PV available |

---

### 2. CrashLoopBackOff

**Symptom:** `kubectl get pods` shows `STATUS: CrashLoopBackOff` with increasing `RESTARTS` count.

**What it means:** The container starts, crashes, and Kubernetes keeps restarting it with exponential back-off.

**Check commands:**
```bash
kubectl logs <pod> -n <namespace>                   # logs from current (possibly empty)
kubectl logs <pod> --previous -n <namespace>        # logs from the crashed instance
kubectl describe pod <pod> -n <namespace>           # look at Last State → Exit Code
```

**Reading exit codes:**

| Exit Code | Common Meaning |
|-----------|---------------|
| `1` | General application error (check logs for details) |
| `2` | Misuse of shell built-ins |
| `127` | Command not found (wrong CMD/ENTRYPOINT) |
| `137` | Killed by signal 9 (OOMKilled or manual kill) |
| `139` | Segmentation fault |
| `143` | Graceful termination (signal 15) |

**Likely causes and fixes:**
- Missing environment variable or secret → check logs for `not set` / `not found`, add env var to Deployment spec.
- Wrong `command` / `args` in pod spec → verify with `kubectl exec` using the same image.
- Dependency not available at startup (e.g., DB not ready) → add an init container or readiness check.
- Application bug → examine `--previous` logs carefully for the stack trace.

**Quick debug run:**
```bash
# Run a temporary pod with the same image to inspect it interactively
kubectl run debug --image=<same-image> -it --rm -- sh
```

---

### 3. ImagePullBackOff / ErrImagePull

**Symptom:** `kubectl get pods` shows `STATUS: ImagePullBackOff` or `ErrImagePull`.

**What it means:** The kubelet on the node cannot pull the container image.

**Check commands:**
```bash
kubectl describe pod <name> -n <namespace>
# Look in Events for: "Failed to pull image" — message contains the actual error
```

**Likely causes and fixes:**

| Cause | Evidence | Fix |
|-------|----------|-----|
| Typo in image name or tag | `repository does not exist` | Fix `image:` field in pod/Deployment spec |
| Tag does not exist | `manifest unknown` | Verify tag exists in the registry |
| Private registry, no pull secret | `unauthorized: authentication required` | Create an `imagePullSecret` and reference it in pod spec or ServiceAccount |
| Node cannot reach registry | `dial tcp: i/o timeout` | Check node DNS and network egress |

**Creating an image pull secret:**
```bash
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<user> \
  --docker-password=<password> \
  -n <namespace>
```

Then reference it in the pod spec:
```yaml
spec:
  imagePullSecrets:
    - name: regcred
```

---

### 4. OOMKilled

**Symptom:** Pod keeps restarting; `kubectl describe pod` shows `Last State: Terminated, Reason: OOMKilled`.

**What it means:** The container used more memory than its `resources.limits.memory` value; the kernel killed it.

**Check commands:**
```bash
kubectl describe pod <name> -n <namespace>
# Look for: Last State → Reason: OOMKilled

kubectl top pods -n <namespace>
# See current memory usage vs limits
```

**Example output from describe:**
```
Last State:    Terminated
  Reason:      OOMKilled
  Exit Code:   137
```

**Fix options:**
1. Increase `resources.limits.memory` in the Deployment spec.
2. Profile the application to find a memory leak.
3. Add horizontal scaling (HPA) to distribute load.

```yaml
resources:
  requests:
    memory: "256Mi"
  limits:
    memory: "512Mi"   # increase this value
```

---

### 5. Service Not Routing Traffic

**Symptom:** Pod is Running, Service exists, but requests fail or time out.

**What it means:** The Service has no Endpoints — its label selector does not match any pod labels.

**Check commands:**
```bash
kubectl get endpoints <service-name> -n <namespace>
# If ENDPOINTS shows <none>, the selector matches nothing

kubectl describe svc <service-name> -n <namespace>
# Look at Selector: field

kubectl get pods -l <key>=<value> -n <namespace>
# Verify pods actually have the label the Service is selecting
```

**Likely causes and fixes:**

| Cause | Evidence | Fix |
|-------|----------|-----|
| Label selector mismatch | `Endpoints: <none>` | Align `spec.selector` in Service with pod `labels` |
| Pod not Ready | Endpoints exist but traffic fails | Check readiness probe — pod may be in Ready=False state |
| Wrong port | Endpoints exist, correct pod, wrong targetPort | Fix `targetPort` to match container `containerPort` |
| Namespace mismatch | Service in different namespace | Services are namespace-scoped; use FQDN `svc.namespace.svc.cluster.local` |

**Quick check flow:**
```bash
kubectl get svc <name> -o yaml | grep -A5 selector
kubectl get pods --show-labels -n <namespace>
kubectl get endpoints <name> -n <namespace>
```

---

### 6. Init Container Stuck

**Symptom:** The pod stays in `Init:0/1` (or similar) indefinitely; the main app container never starts.

**What it means:** An init container is still running or has failed. All init containers must complete successfully before the main containers start.

**Check commands:**
```bash
kubectl get pods -n <namespace>
# STATUS: Init:0/1 means 0 of 1 init containers completed

kubectl describe pod <name> -n <namespace>
# Shows init container status, events

kubectl logs <pod> -c <init-container-name> -n <namespace>
# Logs from the specific init container
```

**How to find init container names:**
```bash
kubectl get pod <name> -o jsonpath='{.spec.initContainers[*].name}'
```

**Likely causes and fixes:**
- Init container waiting for a service that is down → verify the dependency is reachable.
- Init container command failing → read its logs, check exit code in `kubectl describe`.
- DNS not resolving inside the init container → `kubectl exec` into it and run `nslookup <hostname>`.

**Example: check init container logs directly:**
```bash
kubectl logs <pod> -c init-myservice -n <namespace>
# e.g. "waiting for myservice to be ready..."
```
