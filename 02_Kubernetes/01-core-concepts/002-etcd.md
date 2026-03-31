# etcd

# Overview
- **Why it exists** — Cluster state (every object, every config) must be stored durably and consistently across control plane replicas.
- **What it is** — A distributed key-value store that holds all Kubernetes objects. Only the API server communicates with etcd directly. Losing etcd without a backup means losing the entire cluster state.
- **One-liner** — etcd is the brain of the cluster; everything Kubernetes knows lives here.


# Architecture

# Core Building Blocks

### Cluster Sizing

### What Lives in etcd

### Where etcd Runs

### What Losing etcd Means
