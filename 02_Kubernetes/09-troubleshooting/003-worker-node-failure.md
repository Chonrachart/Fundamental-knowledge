# Worker Node Failure Troubleshooting

# Overview
- **Why it exists** — When a worker node fails, all pods scheduled to it become unavailable; diagnosing the root cause quickly minimizes downtime.
- **What it is** — Scenario-based guide for diagnosing worker node failures: NotReady status, kubelet problems, disk pressure, memory pressure, and network partition.
- **One-liner** — Start with `kubectl get nodes`, then `kubectl describe node`, then SSH → `systemctl status kubelet`.

# Architecture

```text
Control Plane                    Worker Node
┌──────────────┐                ┌──────────────────────────────────┐
│  API Server  │◄──── HTTPS ───►│  kubelet (:10250)                │
│              │                │    │                             │
│  etcd        │                │    ├── container runtime         │
│              │                │    │   (containerd/CRI-O)        │
│  scheduler   │                │    │                             │
└──────────────┘                │    └── pods (containers)         │
                                │                                  │
                                │  kube-proxy                      │
                                │  CNI plugin (networking)         │
                                └──────────────────────────────────┘
```

The kubelet is the agent on every worker node. It:
- Registers the node with the API server
- Reports node status and conditions
- Starts and stops containers as instructed

If the kubelet stops or loses connectivity to the API server, the node transitions to `NotReady`.

# Mental Model

```text
kubectl get nodes shows NotReady
        |
        v
kubectl describe node <name>
  → Check Conditions table (DiskPressure, MemoryPressure, PIDPressure, Ready)
  → Check Events at the bottom
        |
        v
SSH to the node
        |
        v
systemctl status kubelet
  → Is it running? Did it exit with an error?
        |
        v
journalctl -u kubelet -n 50
  → What error messages is the kubelet logging?
        |
        v
Diagnose based on error:
  "no space left"      → disk pressure  → df -h, crictl rmi --prune
  "OOM"                → memory         → free -h, top
  "connection refused" → network        → ping API server, check firewall
  "config error"       → kubelet config → check /var/lib/kubelet/config.yaml
```

# Core Building Blocks

### Node Conditions
- **Why it exists** — The kubelet continuously reports node health to the API server via Conditions; each condition signals a specific type of pressure or failure.
- **What it is** — A set of boolean status fields on the Node object that indicate resource pressure and readiness.
- **One-liner** — `kubectl describe node` → Conditions section tells you exactly what is wrong.

| Condition | Normal Value | Meaning when True |
|-----------|-------------|------------------|
| `Ready` | `True` | Node is healthy and accepting pods |
| `DiskPressure` | `False` | Node is low on disk space |
| `MemoryPressure` | `False` | Node is low on memory |
| `PIDPressure` | `False` | Too many processes running |
| `NetworkUnavailable` | `False` | Network plugin not configured correctly |

---

# Troubleshooting

### 1. Node Shows NotReady

**Symptom:** `kubectl get nodes` shows a node with `STATUS: NotReady`.

**Check commands:**
```bash
kubectl get nodes                              # identify which node is NotReady
kubectl describe node <node-name>             # read Conditions and Events sections
```

**What to look for in `kubectl describe node`:**
```
Conditions:
  Type              Status  ...  Reason                Message
  ----              ------  ...  ------                -------
  Ready             False   ...  KubeletNotReady       container runtime network not ready
  DiskPressure      True    ...  KubeletHasDiskPressure available disk is low
```

**Then SSH to the node:**
```bash
ssh <node>
systemctl status kubelet
# Check: Active: active (running) or Active: failed
```

```bash
journalctl -u kubelet -n 50
# Read the last 50 log lines for error messages
```

---

### 2. Kubelet Stopped

**Symptom:** `systemctl status kubelet` shows `Active: failed` or `inactive (dead)`.

**Check commands:**
```bash
systemctl status kubelet                      # is it running?
journalctl -u kubelet -n 100                 # why did it stop?
```

**Fix:**
```bash
systemctl start kubelet
systemctl enable kubelet                     # ensure it starts on reboot
```

If it immediately fails again, read `journalctl` carefully — common causes:
- Config file error → see scenario 5 below
- Container runtime not running → check `systemctl status containerd`
- Certificate issue → check cert paths and expiry

---

### 3. Disk Pressure

**Symptom:** `kubectl describe node` shows `DiskPressure: True`. Pods may be evicted from the node.

**Check commands (on the node):**
```bash
df -h                                         # disk usage by filesystem
du -sh /var/lib/containerd/*                 # container image/layer storage
du -sh /var/log/*                            # log file sizes
```

**Common culprits:**
- Old container images accumulating
- Pod log files growing without rotation
- Large files written by applications to node-local storage

**Fix — prune unused container images:**
```bash
crictl rmi --prune                            # remove all unused images (containerd)
# or for Docker nodes:
docker image prune -a
```

**Fix — clean up logs:**
```bash
journalctl --vacuum-size=500M                # limit journald logs to 500MB
find /var/log -name "*.gz" -mtime +7 -delete # remove old rotated logs
```

---

### 4. Memory Pressure

**Symptom:** `kubectl describe node` shows `MemoryPressure: True`. Pods are evicted (lowest-priority first).

**Check commands (on the node):**
```bash
free -h                                       # total / used / available memory
top                                           # which processes are using the most memory
ps aux --sort=-%mem | head -20               # top 20 memory consumers
```

**Fix options:**
- Reduce pod memory limits to prevent single pods from consuming too much.
- Add memory to the node or add more nodes and rebalance.
- Check for memory leaks in running processes.

---

### 5. Kubelet Config Issues

**Symptom:** Kubelet fails to start; `journalctl -u kubelet` shows config parsing errors or wrong file paths.

**Check commands:**
```bash
cat /var/lib/kubelet/config.yaml              # main kubelet config
cat /var/lib/kubelet/kubeconfig               # kubelet's credentials to API server
journalctl -u kubelet -n 50                  # detailed error output
```

**Common config errors:**
- Wrong `clusterDNS` IP → pods cannot resolve service names
- Wrong `containerRuntimeEndpoint` → kubelet cannot talk to containerd
- Expired client certificate in kubeconfig → `x509: certificate has expired`

**Fix:**
```bash
# Edit the config file, then restart
vi /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl status kubelet                      # verify it came up cleanly
```

---

### 6. Network Partition

**Symptom:** Node shows `NotReady`; kubelet is running on the node but the API server cannot reach it.

**Check commands (on the node):**
```bash
ping <control-plane-IP>                       # basic reachability
curl -k https://<control-plane-IP>:6443/healthz   # test API server reachability
iptables -L -n | grep DROP                   # look for blocking firewall rules
ss -tlnp | grep 10250                        # verify kubelet is listening
```

**Check from the control plane:**
```bash
kubectl describe node <node-name>
# Events: "Kubelet stopped posting node status"
# Conditions: Ready: Unknown (not False — it timed out)
```

**Fix:**
- Restore network connectivity between node and control plane
- Remove blocking firewall rules
- Check cloud security group / NSG rules if in a cloud environment

---

### Full Diagnostic Flow

```bash
# Step 1: identify the problem node
kubectl get nodes

# Step 2: read node conditions and events
kubectl describe node <node-name>

# Step 3: SSH to the node
ssh <node-name>

# Step 4: check kubelet status
systemctl status kubelet

# Step 5: read kubelet logs
journalctl -u kubelet -n 50

# Step 6: check disk and memory
df -h
free -h

# Step 7: fix and verify
systemctl restart kubelet
systemctl status kubelet
# Back on control plane:
kubectl get nodes    # should return to Ready within ~30s
```
