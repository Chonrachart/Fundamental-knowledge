# etcd

# Overview

- **Why it exists** — Kubernetes needs a single, consistent, durable store for all cluster state that works correctly even when control plane nodes fail.
- **What it is** — A distributed key-value store that uses the Raft consensus algorithm to maintain consistency across multiple replicas. It is the source of truth for every Kubernetes object: pods, deployments, secrets, configmaps, node registrations, RBAC rules, and more.
- **One-liner** — etcd is the cluster's database; if you lose it without a backup, the cluster is gone.

# Architecture

```text
Control Plane (HA setup — 3 or 5 etcd members)

  ┌──────────────────────────────────────────────┐
  │                API Server                    │
  │   (only component that reads/writes etcd)    │
  └───────────────────┬──────────────────────────┘
                      │
        ┌─────────────▼─────────────┐
        │       etcd cluster        │
        │                           │
        │  ┌────────┐  ┌────────┐   │
        │  │ Leader │  │Follower│   │
        │  │        │◄─│        │   │
        │  │ writes │  │replicas│   │
        │  └────────┘  └────────┘   │
        │       ▲                   │
        │  ┌────┴───┐               │
        │  │Follower│               │
        │  └────────┘               │
        └───────────────────────────┘

  Quorum requires majority: 3-node needs 2, 5-node needs 3
```

# Mental Model

```text
kubectl apply -f pod.yaml
        │
        ▼
API Server validates request
        │
        ▼
API Server writes object to etcd
        │
        ▼
etcd Raft leader replicates to followers
        │
        ▼
Write acknowledged when majority confirms
        │
        ▼
API Server returns 200 OK to kubectl
        │
        ▼
Controllers/Scheduler watch (via API server) and act
```

# Core Building Blocks

### Raft Consensus

- **Why it exists** — In a distributed system, multiple nodes must agree on the same data even if some nodes are unavailable.
- **What it is** — Raft is the consensus algorithm etcd uses. One node is elected leader; all writes go through the leader. The leader replicates entries to followers and commits once a majority (quorum) acknowledges. If the leader fails, followers elect a new leader automatically.
- **One-liner** — Raft ensures etcd is consistent and fault-tolerant as long as a majority of nodes are healthy.

### Leader Election

- **Why it exists** — Only one node should accept writes at a time to prevent split-brain.
- **What it is** — On startup, etcd nodes hold an election. The winner becomes leader and handles all writes. Followers do not redirect write requests — if a client connects to a follower and attempts a write, the request is rejected; the client must retry against the leader directly. If the leader crashes or becomes unreachable, a new election is triggered within seconds.
- **One-liner** — Leader election ensures there is always exactly one writable etcd node.

### Cluster Sizing

- **Why it exists** — The number of etcd nodes determines fault tolerance; choosing the wrong size leaves the cluster either under-protected or with unnecessary write overhead.
- **What it is** — The configuration of how many etcd member nodes form the cluster, governed by Raft quorum rules. Odd numbers are required because quorum is a strict majority; even numbers do not improve fault tolerance.
- **One-liner** — Cluster sizing controls how many node failures etcd can survive while still accepting writes.

| Nodes | Tolerated failures | Notes |
|-------|-------------------|-------|
| 1 | 0 | Dev/test only — no HA |
| 3 | 1 | Standard HA setup |
| 5 | 2 | Higher availability, more write overhead |

Odd numbers only — even numbers do not improve fault tolerance and increase quorum cost.

### What Lives in etcd

- **Why it exists** — Understanding what data etcd holds clarifies the blast radius of etcd loss and why backups are critical.
- **What it is** — The complete persistent state of the Kubernetes cluster: every API object, configuration record, and lease. Keys are stored under a `/registry/` prefix hierarchy mirroring the API group and resource structure.
- **One-liner** — etcd holds every Kubernetes object and cluster configuration record; losing it without a backup means losing the entire cluster.

- All Kubernetes API objects: pods, deployments, services, configmaps, secrets, namespaces, nodes, RBAC rules
- Cluster configuration and leader lease records
- etcd keys are prefixed by path: `/registry/pods/default/mypod`

```bash
# View etcd keys (run on control plane node)
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  get /registry/pods/default --prefix --keys-only

# Check etcd health
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Where etcd Runs

- In kubeadm clusters: as a static pod on the control plane node(s), managed by kubelet directly from `/etc/kubernetes/manifests/etcd.yaml`.
- In managed clusters (EKS, GKE, AKS): etcd is abstracted away; the cloud provider manages it.
- Data directory: typically `/var/lib/etcd` on the control plane node.

### What Losing etcd Means

- If etcd data is lost and there is no backup: **the cluster is unrecoverable**. All object definitions, secrets, configmaps, and RBAC rules are gone.
- Running pods on worker nodes continue running temporarily (kubelet keeps them alive), but the control plane cannot manage them.
- Recovery requires restoring from a snapshot. See `05-cluster-maintenance/003-etcd-backup-restore.md` for backup/restore procedures.
