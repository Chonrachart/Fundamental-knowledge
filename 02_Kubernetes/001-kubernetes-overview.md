# Kubernetes Overview

- Kubernetes orchestrates containers across a cluster of nodes, managing scheduling, scaling, and self-healing.
- A control plane (API server, scheduler, controller-manager, `etcd`) makes decisions; worker nodes (`kubelet`, container runtime) run pods.
- `kubectl` is the CLI client that talks to the API server using `kubeconfig` for auth and cluster selection.

# Architecture

```text
                        Control Plane
    ┌─────────────────────────────────────────────┐
    │  API Server ◄── kubectl / clients           │
    │      │                                      │
    │      ├── Scheduler (assigns pods to nodes)  │
    │      ├── Controller Manager (reconcile loop)│
    │      └── etcd (cluster state store)         │
    └─────────────────────────────────────────────┘
                        │
            ┌───────────┴───────────┐
            ▼                       ▼
    ┌──────────────┐        ┌──────────────┐
    │   Node 1     │        │   Node 2     │
    │  kubelet     │        │  kubelet     │
    │  kube-proxy  │        │  kube-proxy  │
    │  container   │        │  container   │
    │  runtime     │        │  runtime     │
    │  [Pod][Pod]  │        │  [Pod][Pod]  │
    └──────────────┘        └──────────────┘
```

# Mental Model

```text
User applies manifest (kubectl apply -f)
        │
        ▼
API Server validates and stores in etcd
        │
        ▼
Scheduler watches for unassigned pods → picks a node
        │
        ▼
kubelet on chosen node pulls image → starts container(s)
        │
        ▼
Controller Manager watches desired vs actual → reconciles
  (e.g., Deployment controller creates ReplicaSet → ReplicaSet creates pods)
```

Example: deploying nginx

```bash
kubectl apply -f deployment.yaml    # desired state → API server → etcd
kubectl get deployments             # see DESIRED / CURRENT / READY
kubectl get pods                    # see pods created by ReplicaSet
```

# Core Building Blocks

### Cluster

- **Control plane**: API server, scheduler, controller-manager, etcd.
- **Nodes**: Run `kubelet` and container runtime; execute pods.
- `kubectl cluster-info` — check cluster.
- The API server is the only component that talks to `etcd` directly.
- `etcd` stores all cluster state; losing `etcd` without backup means losing the cluster.
- Scheduler assigns pods to nodes based on resource requests, affinity, and taints/tolerations.
- Controller Manager runs reconciliation loops (Deployment, ReplicaSet, Node, etc.).
- `kubelet` on each node ensures containers described in PodSpecs are running and healthy.
- `kube-proxy` maintains network rules on nodes for Service traffic forwarding.
- Default API server port is 6443 (HTTPS).

### Pod

- Smallest deployable unit; one or more containers; shared network (localhost) and storage.
- Defined in YAML; created directly or by Deployment, StatefulSet, DaemonSet.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:alpine
    ports:
    - containerPort: 80
```

### Deployment

- Manages ReplicaSet and pods; declarative desired state.
- Rolling update, rollback; scale with `kubectl scale`.

```bash
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl scale deployment/myapp --replicas=3
```

### Service

- Stable DNS and IP for pods; types: `ClusterIP`, `NodePort`, `LoadBalancer`.
- Selects pods by label selector.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-svc
spec:
  selector:
    app: myapp
  ports:
  - port: 80
  type: ClusterIP
```

### kubectl

- CLI to talk to cluster; uses `kubeconfig` for auth and cluster.
- `kubectl config current-context` shows which cluster/namespace you are targeting.

```bash
kubectl get pods
kubectl get nodes
kubectl describe pod <name>
kubectl logs <pod>
kubectl exec -it <pod> -- sh
```

Related notes: [002-pods-labels](./002-pods-labels.md), [003-deployments-rolling-update](./003-deployments-rolling-update.md), [004-services-ingress](./004-services-ingress.md)

---

# Troubleshooting Guide

### Cannot connect to cluster
1. Check `kubeconfig`: `kubectl config view` — verify server URL, context, and credentials.
2. Check context: `kubectl config current-context` — switch with `kubectl config use-context <name>`.
3. Check API server reachable: `curl -k https://<api-server>:6443/healthz`.

### kubectl command returns "connection refused"
1. API server may be down: check `systemctl status kube-apiserver` on control plane node.
2. Wrong `kubeconfig`: ensure `~/.kube/config` points to the right cluster.
3. Firewall blocking port 6443: check with `ss -tlnp | grep 6443` on the control plane.

### Deployment created but no pods appear
1. Check deployment: `kubectl describe deployment <name>` — look at Events.
2. Check ReplicaSet: `kubectl get rs` — verify desired/current/ready counts.
3. If replicas are 0: check if `replicas:` is set correctly in the spec.
