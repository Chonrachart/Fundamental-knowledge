# kube-apiserver

# Overview
- **Why it exists** — Every component in the cluster needs a single source of truth and a single entry point for reads and writes.
- **What it is** —The front door for all cluster operations; validates and authenticates requests, authorizes via RBAC, and persists objects to etcd. It is the only component that reads/writes etcd directly.
- **One-liner** — The API server is the gatekeeper — everything goes through it, nothing bypasses it.

```bash
curl -k https://<control-plane-ip>:6443/healthz     # Health check
kubectl api-versions                                # List API versions
```

# Architecture

# Core Building Blocks

### Authentication

### Authorization (RBAC)

### Admission Control

### REST API on Port 6443

### Watches (Event-Driven Architecture)
