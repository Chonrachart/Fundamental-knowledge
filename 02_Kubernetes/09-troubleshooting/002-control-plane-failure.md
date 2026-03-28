# Control Plane Failure Troubleshooting

### Overview
**Why it exists** — If the control plane is degraded, nothing else works correctly: pods stop scheduling, controllers stop reconciling, and `kubectl` itself may become unresponsive.
**What it is** — Scenario-based guide for diagnosing control plane component failures: API server, scheduler, controller-manager, and etcd.
**One-liner** — Control plane components run as static pods in `kube-system`; start every investigation with `kubectl get pods -n kube-system`.

### Architecture (ASCII)

```text
Control Plane Node
┌────────────────────────────────────────────────┐
│                                                │
│  kube-apiserver        ← entry point for all  │
│       │                  kubectl commands      │
│       ▼                                        │
│    etcd                ← cluster state store   │
│                                                │
│  kube-scheduler        ← assigns pods to nodes │
│                                                │
│  kube-controller-mgr   ← reconciles desired    │
│                          vs actual state       │
└────────────────────────────────────────────────┘
         ▲
         │  (static pods managed by kubelet on control plane node)
         │  Manifests in: /etc/kubernetes/manifests/
```

### Mental Model

```text
kubectl unresponsive?
    └── API server down → check kube-apiserver pod / systemctl / journalctl

kubectl works but pods not scheduling?
    └── scheduler down → check kube-scheduler pod in kube-system

Deployments/ReplicaSets not converging?
    └── controller-manager down → check kube-controller-manager pod in kube-system

API server up but slow or returning errors?
    └── etcd issues → check etcd pod, verify cert paths and connectivity
```

All control plane components run as **static pods**. The kubelet on the control plane node reads manifests from `/etc/kubernetes/manifests/` and keeps them running. Deleting the pod object only causes it to be recreated.

### Core Building Blocks

### Static Pods (Control Plane Components)
**Why it exists** — Control plane components must run even before the cluster API is available; static pods are managed directly by the kubelet without going through the API server.
**What it is** — Pod manifests placed in `/etc/kubernetes/manifests/`; the kubelet watches this directory and runs the pods directly.
**One-liner** — Edit the YAML in `/etc/kubernetes/manifests/` to change control plane component configuration.

```bash
ls /etc/kubernetes/manifests/
# kube-apiserver.yaml  kube-controller-manager.yaml  kube-scheduler.yaml  etcd.yaml
```

### kubectl get componentstatuses
**Why it exists** — Quick health check for scheduler, controller-manager, and etcd.
**What it is** — Deprecated but still functional in many clusters; queries health endpoints of control plane components.
**One-liner** — `kubectl get cs` gives a fast overview of control plane component health.

```bash
kubectl get componentstatuses
# or short form:
kubectl get cs
```

### Troubleshooting Scenarios

---

### 1. kubectl Unresponsive / Connection Refused

**Symptom:** `kubectl get pods` returns `The connection to the server <host>:6443 was refused` or hangs.

**What it means:** The API server is down or unreachable.

**Check commands (run on the control plane node via SSH):**
```bash
# Check if kube-apiserver static pod is running
kubectl get pods -n kube-system | grep apiserver

# If kubectl itself is broken, check the process directly
systemctl status kube-apiserver          # if running as a systemd service
# OR check the static pod via crictl (if using containerd)
crictl ps | grep apiserver

# Check logs
journalctl -u kube-apiserver -n 100
# OR via kubectl once partial access is restored:
kubectl logs -n kube-system kube-apiserver-<node-name>
```

**Likely causes:**
- API server process crashed → check `journalctl` for startup errors (wrong flags, missing cert).
- Certificate expired → check `/etc/kubernetes/pki/` cert expiry dates with `openssl x509 -in <cert> -noout -dates`.
- etcd unreachable → API server cannot start if it cannot connect to etcd.
- Resource exhaustion on the control plane node → check `df -h` and `free -h`.

---

### 2. Pods Not Scheduling

**Symptom:** New pods stay in `Pending` indefinitely; `kubectl describe pod` Events show no scheduler activity.

**What it means:** The kube-scheduler is down or not functioning.

**Check commands:**
```bash
kubectl get pods -n kube-system | grep scheduler
# Expected: kube-scheduler-<node> Running

kubectl describe pod kube-scheduler-<node> -n kube-system
# Check Events for restart reasons

kubectl logs kube-scheduler-<node> -n kube-system
# Look for connection errors to API server or internal panics
```

**Likely causes and fixes:**

| Cause | Evidence | Fix |
|-------|----------|-----|
| Scheduler pod CrashLoopBackOff | `RESTARTS` count climbing | Check logs for root cause; fix manifest in `/etc/kubernetes/manifests/kube-scheduler.yaml` |
| Scheduler lost connection to API server | Log: `Failed to watch *v1.Node` | Verify kubeconfig path in scheduler manifest |
| Leader election issue (HA clusters) | No active leader in logs | Check scheduler lease in `kube-system` namespace: `kubectl get lease -n kube-system` |

---

### 3. Controllers Not Reconciling

**Symptom:** Creating a Deployment does not create ReplicaSets; scaling a Deployment has no effect; endpoints for Services are not updated.

**What it means:** The kube-controller-manager is down.

**Check commands:**
```bash
kubectl get pods -n kube-system | grep controller-manager
# Expected: kube-controller-manager-<node> Running

kubectl logs kube-controller-manager-<node> -n kube-system
# Look for authentication errors or panics

kubectl get cs
# controller-manager should show Healthy
```

**Likely causes and fixes:**

| Cause | Evidence | Fix |
|-------|----------|-----|
| Pod CrashLoopBackOff | RESTARTS climbing | Read logs; fix manifest at `/etc/kubernetes/manifests/kube-controller-manager.yaml` |
| Service account token issue | `401 Unauthorized` in logs | Verify `--kubeconfig` flag points to a valid kubeconfig |
| Cert rotation needed | `x509: certificate has expired` | Renew certs with `kubeadm certs renew controller-manager.conf` |

---

### 4. etcd Issues

**Symptom:** API server is running but returns `etcdserver: request timed out` errors; reads/writes are slow or failing.

**What it means:** The API server cannot reliably reach etcd, or etcd is degraded.

**Check commands:**
```bash
# Check etcd pod status
kubectl get pods -n kube-system | grep etcd
kubectl describe pod etcd-<node> -n kube-system

# etcd logs
kubectl logs etcd-<node> -n kube-system
# Look for: "failed to send out heartbeat", "took too long", "no leader"

# On the control plane node:
journalctl -u etcd -n 100                  # if etcd runs as a service instead of static pod
```

**Verify etcd health directly (if `etcdctl` is available):**
```bash
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  endpoint health
```

**Likely causes and fixes:**

| Cause | Evidence | Fix |
|-------|----------|-----|
| Wrong cert paths in manifest | `no such file or directory` in etcd logs | Fix paths in `/etc/kubernetes/manifests/etcd.yaml` |
| Disk I/O too slow | `took too long to execute` warnings | Move etcd data to faster disk; etcd is latency-sensitive |
| Quorum lost (HA etcd) | `no leader` in logs | Restore quorum; at least `(n/2)+1` members must be healthy |
| etcd data corruption | Startup failure with data errors | Restore from etcd snapshot backup |

---

### General Control Plane Diagnostic Flow

```text
1. kubectl get pods -n kube-system
   → Are all control plane pods Running?
   → Which ones are CrashLoopBackOff or Pending?

2. kubectl describe pod <component>-<node> -n kube-system
   → Read Events section for immediate clues

3. kubectl logs <component>-<node> -n kube-system
   → Read error messages from the component

4. kubectl get cs
   → Quick health summary for scheduler, controller-manager, etcd

5. SSH to control plane node
   systemctl status kubelet
   ls /etc/kubernetes/manifests/
   journalctl -u kubelet -n 50
   → Is the kubelet running? Are the manifest files present?
```
