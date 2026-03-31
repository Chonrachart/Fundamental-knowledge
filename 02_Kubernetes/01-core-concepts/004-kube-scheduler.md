# kube-scheduler

# Overview
- **Why it exists** — Pods need to be placed on nodes that have sufficient resources and meet constraints.
- **What it is** — Watches for pods with no `nodeName` set, scores candidate nodes by available resources and more, then writes the chosen `nodeName` back to the pod via the API server.
- **One-liner** — The scheduler decides which node each pod lands on.

# Architecture

# Core Building Blocks

### Node Affinity and NodeSelector

### Taints and Tolerations (Scheduling Impact)

### Checking Scheduling Decisions
