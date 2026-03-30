# OS Upgrades

# Overview

- **Why it exists** — Nodes must occasionally be rebooted for OS patches, kernel upgrades, or hardware maintenance. Without a controlled drain sequence, pods running on that node are abruptly killed and may not recover if they lack a controller or if persistent data is lost.
- **What it is** — A process of gracefully evicting workloads off a node before taking it offline, then returning it to the cluster once the maintenance is complete.
- **One-liner** — Cordon + drain a node before OS maintenance so workloads land elsewhere safely, then uncordon to return the node to service.

# Architecture

```text
Controlled OS upgrade flow:

  kubectl cordon node01
        │
        ▼
  node01: SchedulingDisabled
  (no new pods scheduled here)
        │
        ▼
  kubectl drain node01
        │
        ├─► DaemonSet pods — skipped (--ignore-daemonsets)
        ├─► emptyDir pods  — deleted (--delete-emptydir-data, DATA LOST)
        └─► normal pods    — evicted → rescheduled on other nodes
        │
        ▼
  SSH to node01 → perform OS upgrade → reboot
        │
        ▼
  kubectl uncordon node01
        │
        ▼
  node01: Ready (scheduler resumes placing pods here)
```

# Mental Model

Think of `cordon` as putting up a "no new guests" sign on a hotel floor, and `drain` as politely asking all current guests to pack up and move to other floors. Once maintenance is done, `uncordon` takes the sign down and the floor is open again.

The critical distinction: `cordon` alone does not move existing pods — it only stops new ones from arriving. `drain` does both (it cordons first, then evicts). If you only cordon and then reboot the node hard, every pod on it is abruptly killed.

Pods managed by a Deployment, ReplicaSet, StatefulSet, or Job will be rescheduled elsewhere automatically. Standalone (bare) pods with no controller will not — use `--force` to delete them anyway, but be aware they will not come back on their own.

# Core Building Blocks

### cordon

- **Why it exists** — Marks a node as unschedulable so the scheduler stops placing new pods there while you prepare for maintenance. Existing pods are not touched.
- **What it is** — Sets the `spec.unschedulable: true` taint on the node. The node status shows `SchedulingDisabled`. All currently running pods keep running; only the scheduler is blocked from adding more.
- **One-liner** — `cordon` = unschedulable flag only; pods already on the node are unaffected.

```bash
# Mark node unschedulable
kubectl cordon <node>

# Verify — STATUS column shows "Ready,SchedulingDisabled"
kubectl get nodes
```

### drain

- **Why it exists** — Safely evicts all evictable pods off a node before it goes offline, respecting PodDisruptionBudgets so availability is maintained during the eviction.
- **What it is** — Implicitly cordons the node first, then sends eviction API requests for each pod (not raw deletes — eviction respects PDB). Pods are rescheduled by their controllers on other nodes.
- **One-liner** — `drain` = cordon + evict; the safe way to empty a node before maintenance.

```bash
# 1. Mark node unschedulable (no new pods)
kubectl cordon <node>

# 2. Evict existing pods (respects PDB)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```

**Key flags:**

| Flag | Why it is needed |
|------|-----------------|
| `--ignore-daemonsets` | DaemonSet pods are managed by the DaemonSet controller and will be recreated immediately if deleted; drain refuses to proceed without this flag to avoid an infinite loop |
| `--delete-emptydir-data` | Pods using `emptyDir` volumes store data only in memory/node-local storage; draining them destroys that data. This flag acknowledges the data loss and allows eviction to proceed |
| `--force` | Required for standalone (bare) pods with no owning controller; without it drain will refuse to evict them because they will not be recreated |
| `--grace-period=<seconds>` | Override the pod's own `terminationGracePeriodSeconds`; use `0` for immediate eviction (not recommended for production) |

### uncordon

- **Why it exists** — Returns the node to the scheduler's pool after maintenance is complete.
- **What it is** — Clears the `spec.unschedulable` flag. The scheduler can now place new pods on the node. Existing pods that were evicted are not automatically moved back — they stay where they were rescheduled.
- **One-liner** — `uncordon` re-enables scheduling on a node after maintenance.

```bash
# 3. Perform OS upgrade (SSH to node)
# ssh <node>
# sudo apt-get update && sudo apt-get dist-upgrade -y
# sudo reboot

# 4. Return node to service
kubectl uncordon <node>

# Verify — STATUS column should show "Ready"
kubectl get nodes
```

### Full sequence

```bash
# 1. Mark node unschedulable (no new pods)
kubectl cordon <node>

# 2. Evict existing pods (respects PDB)
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# 3. Perform OS upgrade (SSH to node)
# ssh <node>
# sudo apt-get update && sudo apt-get dist-upgrade -y
# sudo reboot

# 4. Return node to service
kubectl uncordon <node>

# Verify node is Ready
kubectl get nodes
```

### cordon vs drain comparison

| Action | Unschedulable | Evicts existing pods | Respects PDB |
|--------|--------------|---------------------|-------------|
| `cordon` | Yes | No | N/A |
| `drain` | Yes (implicit) | Yes | Yes |
