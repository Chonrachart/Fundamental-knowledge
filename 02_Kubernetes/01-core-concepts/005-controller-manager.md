# kube-controller-manager

# Overview
- **Why it exists** — Desired state must be continuously reconciled against actual state
- **What it is** — Runs many control loops in a single process (Deployment controller, ReplicaSet controller, Node controller, Endpoint controller, etc.). Each loop watches objects and takes corrective action when actual state drifts from desired state.
- **One-liner** — The controller manager is the automation engine that keeps the cluster in its desired state.


# Architecture

# Core Building Blocks

### The Reconcile Loop Concept
