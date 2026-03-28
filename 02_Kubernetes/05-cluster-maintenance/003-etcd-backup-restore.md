# etcd Backup and Restore

# Overview

- **Why it exists** — etcd is the single source of truth for all cluster state: every object, every secret, every config. If etcd data is corrupted or lost without a backup, the cluster state is irrecoverable — you cannot reconstruct what was running, what secrets existed, or what policies were in place. Regular backups are the only safety net.
- **What it is** — A process of using `etcdctl` to snapshot the etcd key-value store to a file, and restoring from that snapshot when needed. The snapshot captures the full cluster state at a point in time.
- **One-liner** — etcd IS the cluster; back it up with `etcdctl snapshot save` and restore with `etcdctl snapshot restore`.

### Architecture (ASCII diagram)

```text
etcd data flow:

  kubectl apply / API calls
          │
          ▼
  kube-apiserver
          │
          ▼
  etcd (port 2379)  ◄──── snapshot save ────► /tmp/etcd-backup.db
          │                                         │
          │                                         │
          ▼                                    snapshot restore
  /var/lib/etcd/                                    │
  (live data dir)                                   ▼
                                         /var/lib/etcd-restored/
                                         (new data dir → update etcd manifest)
```

# Mental Model

Think of etcd as the cluster's brain. `kubectl get pods` is just reading from etcd. `kubectl apply` writes to etcd. Everything the API server returns is ultimately a read from etcd.

A backup is a frozen copy of that brain at a moment in time. Restoring it means: stop the old brain, swap in the frozen copy, restart. The cluster will wake up believing it is back in that earlier state — any objects created after the backup was taken will be gone.

The most common exam trap: forgetting `ETCDCTL_API=3`. Without it, the v2 API is used and commands silently fail or behave differently.

# Core Building Blocks

### ETCDCTL_API environment variable

- **Why it exists** — `etcdctl` supports both v2 and v3 APIs. The default is v2. Kubernetes uses etcd v3. Snapshot save/restore commands only exist in the v3 API.
- **What it is** — An environment variable that forces `etcdctl` to use the v3 API for all commands in the session.
- **One-liner** — Always set `ETCDCTL_API=3` before any `etcdctl` command.

```bash
# Set inline per command
ETCDCTL_API=3 etcdctl <command>

# Or export for the session
export ETCDCTL_API=3
etcdctl <command>
```

### Certificate paths

- **Why it exists** — etcd uses mutual TLS; every client (including `etcdctl`) must present a valid certificate signed by the etcd CA. Without the certs, the connection is refused.
- **What it is** — Three files under `/etc/kubernetes/pki/etcd/`:

| Flag | File | Purpose |
|------|------|---------|
| `--cacert` | `/etc/kubernetes/pki/etcd/ca.crt` | etcd CA certificate — verifies server identity |
| `--cert` | `/etc/kubernetes/pki/etcd/server.crt` | Client certificate — authenticates etcdctl to etcd |
| `--key` | `/etc/kubernetes/pki/etcd/server.key` | Client private key |

```bash
# Verify the cert files exist
ls /etc/kubernetes/pki/etcd/
# ca.crt  ca.key  healthcheck-client.crt  healthcheck-client.key
# peer.crt  peer.key  server.crt  server.key
```

### Backup — snapshot save

- **Why it exists** — Creates a consistent, point-in-time snapshot of all etcd data that can be restored later.
- **What it is** — `etcdctl snapshot save` connects to the etcd endpoint and writes the current state to a `.db` file. The snapshot is self-contained and portable.
- **One-liner** — `etcdctl snapshot save` writes a full cluster state snapshot to a file.

```bash
ETCDCTL_API=3 etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

**Verify the backup is valid:**
```bash
ETCDCTL_API=3 etcdctl snapshot status /tmp/etcd-backup.db --write-out=table
# Output: hash, revision, total keys, total size
```

**Backup frequency recommendation:**
- Production clusters: at minimum daily, ideally before any major change (upgrade, large deployment, config change).
- Store backups off-cluster (object storage, NFS, remote server) — a backup on the same node as etcd is useless if the node is lost.

### Restore — snapshot restore

- **Why it exists** — Recovers cluster state from a backup after data corruption, accidental deletion, or disaster recovery.
- **What it is** — A multi-step process: stop the API server (so nothing writes to etcd during restore), restore the snapshot to a new data directory, reconfigure the etcd manifest to point to the new directory, then restart.
- **One-liner** — Restore writes snapshot data to a new dir, then etcd is pointed to that dir via manifest update.

```bash
# 1. Stop kube-apiserver (move manifest out of static pod dir)
mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/kube-apiserver.yaml
# Wait for the API server pod to stop (check: crictl ps | grep kube-apiserver)

# 2. Restore snapshot to new data dir
ETCDCTL_API=3 etcdctl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored

# 3. Update etcd manifest to point to new data dir
# Edit /etc/kubernetes/manifests/etcd.yaml
# Change --data-dir=/var/lib/etcd  →  --data-dir=/var/lib/etcd-restored
# Also update the hostPath volume mount if present:
#   path: /var/lib/etcd  →  path: /var/lib/etcd-restored

# 4. Move kube-apiserver manifest back
mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/kube-apiserver.yaml

# 5. Wait for control plane to restart (30–60 seconds)
watch kubectl get nodes
```

**Verify etcd and cluster are healthy after restore:**
```bash
# Node list should return (may take a minute for API server to be ready)
kubectl get nodes

# Check etcd pod is running
kubectl get pods -n kube-system | grep etcd

# Check etcd health directly
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Finding etcd endpoint and cert paths from running cluster

```bash
# Inspect the etcd static pod manifest to find actual paths
cat /etc/kubernetes/manifests/etcd.yaml | grep -E "data-dir|cert|key|trusted"

# Or inspect the running etcd pod
kubectl describe pod etcd-<controlplane> -n kube-system | grep -A5 "Command:"
```

# Troubleshooting

### etcdctl snapshot save: "context deadline exceeded" or connection refused
1. Verify etcd is running: `kubectl get pods -n kube-system | grep etcd`.
2. Confirm the endpoint: default is `https://127.0.0.1:2379`; check the etcd manifest for `--advertise-client-urls`.
3. Confirm cert paths are correct — copy exact paths from the etcd manifest: `cat /etc/kubernetes/manifests/etcd.yaml`.
4. Ensure you are running on the control plane node, not a worker.

### Restore: API server not coming back after moving manifest back
1. Check if the etcd pod is actually running with the new data dir: `crictl ps | grep etcd`.
2. Check etcd logs: `crictl logs <etcd-container-id>` or `kubectl logs etcd-<node> -n kube-system`.
3. Common cause: the `hostPath` volume in the etcd manifest still points to the old directory. Both `--data-dir` flag and the `volumes.hostPath.path` must be updated.
4. If the API server manifest was moved back too quickly, wait for etcd to finish initializing first.

### After restore, objects created after the backup are missing
1. This is expected behavior — the restore sets cluster state back to the backup point in time.
2. Any objects created after the backup snapshot was taken will not exist.
3. To minimize data loss, take backups frequently and before any critical operations.

### etcdctl snapshot status shows 0 keys or tiny file size
1. The snapshot file may be corrupt or from a partial write. Do not use it for restore.
2. Retake the backup: verify etcd is healthy first with the endpoint health check.
3. Check available disk space before saving: `df -h /tmp`.
