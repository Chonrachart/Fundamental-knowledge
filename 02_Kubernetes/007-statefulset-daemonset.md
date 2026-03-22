# StatefulSet and DaemonSet

- StatefulSet gives pods stable identity (ordered names, stable DNS, persistent storage per pod) for stateful workloads like databases.
- DaemonSet ensures exactly one pod runs on every (or a subset of) node(s) for node-level agents like logging and monitoring.
- Both differ from Deployment: StatefulSet adds ordering and identity; DaemonSet ties pod count to node count instead of a replica field.

# Architecture

```text
StatefulSet "web" (replicas: 3)
  Headless Service (clusterIP: None) ──→ DNS per pod
      |
      ├── web-0  ←→  PVC: data-web-0   DNS: web-0.web.ns.svc.cluster.local
      ├── web-1  ←→  PVC: data-web-1   DNS: web-1.web.ns.svc.cluster.local
      └── web-2  ←→  PVC: data-web-2   DNS: web-2.web.ns.svc.cluster.local
           ↑
           Created in order 0→1→2; deleted in reverse 2→1→0

DaemonSet "fluentd"
      |
      ├── Node A  ──→  fluentd pod (mounts /var/log)
      ├── Node B  ──→  fluentd pod (mounts /var/log)
      └── Node C  ──→  fluentd pod (mounts /var/log)
           ↑
           New node added → DaemonSet automatically creates pod on it
```

# Mental Model

```text
Scenario: Deploy a 3-node Redis cluster with StatefulSet

1. Create Headless Service (clusterIP: None, name: redis)
2. Create StatefulSet (serviceName: redis, replicas: 3, volumeClaimTemplates)
3. Kubernetes creates:
     redis-0 first → waits until Ready
     redis-1 next  → waits until Ready
     redis-2 last
4. Each pod gets:
     Stable DNS:  redis-0.redis.default.svc.cluster.local
     Own PVC:     data-redis-0 (persists across restarts)
5. Delete redis-2 → pod is recreated with SAME name and SAME PVC
```

# Core Building Blocks

### StatefulSet Spec (Key Fields)

- **serviceName**: headless Service (clusterIP: None) used for pod identity and DNS; each pod gets `pod-name.serviceName.ns.svc.cluster.local`.
- **replicas**: desired number of pods.
- **volumeClaimTemplates**: one PVC template per pod; each pod gets its own PVC `<vc-name>-<statefulset-name>-<ordinal>`; PVC is not deleted when pod is deleted (retain data).
- **podManagementPolicy**: `OrderedReady` (default, create/delete in order) or `Parallel` (all at once).
- **updateStrategy**: `RollingUpdate` (with `partition` option) or `OnDelete`.
- StatefulSet pods are named `<name>-<ordinal>` (e.g. `web-0`, `web-1`) and created in order by default.
- PVCs from `volumeClaimTemplates` are NOT deleted when pods or the StatefulSet are removed -- manual cleanup required.
- `podManagementPolicy: Parallel` skips ordered startup if ordering is not needed.
- StatefulSet update with `partition` lets you canary-roll a subset of pods (ordinals >= partition value).

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: web
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        volumeMounts:
        - name: data
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

### Headless Service

- `clusterIP: None` -- no virtual IP; DNS returns A records for each pod IP (`web-0.web.ns.svc.cluster.local`).
- Required for StatefulSet `serviceName`; allows peers to discover each other by name.
- Headless Service (`clusterIP: None`) is required for StatefulSet; gives each pod a stable DNS name.

### DaemonSet Spec

- No **replicas** field; number of pods = number of matching nodes.
- **updateStrategy**: `RollingUpdate` (default, `maxUnavailable` in number) or `OnDelete`.
- **template**: same as Deployment; often runs as privileged or mounts host paths (e.g. `/var/log`, `/var/lib/docker`).
- **nodeSelector** / **affinity** / **tolerations**: limit which nodes get the pod (e.g. only GPU nodes).
- Use for: node-level agents (logging, monitoring, storage), CNI, kube-proxy.
- DaemonSet has no `replicas` field; pod count equals matching node count.
- DaemonSet pods often need `tolerations` to run on control-plane/master nodes.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
spec:
  selector:
    matchLabels:
      app: fluentd
  template:
    metadata:
      labels:
        app: fluentd
    spec:
      tolerations:
      - operator: Exists  # run on all nodes including master
      containers:
      - name: fluentd
        image: fluent/fluentd
        volumeMounts:
        - name: varlog
          mountPath: /var/log
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
```

### StatefulSet vs Deployment

| Aspect | Deployment | StatefulSet |
|--------|------------|-------------|
| Pod names | Random hash | Stable (name-0, name-1) |
| Storage | Shared or any | Often 1 PVC per pod (volumeClaimTemplate) |
| Order | No guarantee | Ordered create/delete (default) |
| DNS | Service round-robin | Per-pod DNS (headless) |
| Use case | Stateless apps | Stateful, clustered apps |

### DaemonSet vs Deployment

- **Deployment**: N replicas anywhere; scheduler places them.
- **DaemonSet**: one per node (or per matching node); for node-level workload.

Related notes: [003-deployments-rolling-update](./003-deployments-rolling-update.md), [004-services-ingress](./004-services-ingress.md), [008-resource-requests-limits](./008-resource-requests-limits.md)

---

# Troubleshooting Guide

### StatefulSet pods stuck in Pending
1. Check PVC: `kubectl get pvc` -- each pod needs its own PVC from `volumeClaimTemplates`.
2. No PV available or StorageClass can't provision: `kubectl describe pvc <name>`.
3. Pods are created in order -- if `pod-0` is stuck, `pod-1` won't start (`OrderedReady`).

### StatefulSet pod deleted but PVC remains
1. By design -- PVCs are NOT deleted when pods or StatefulSet are deleted (data safety).
2. Manual cleanup: `kubectl delete pvc <pvc-name>`.
3. To reattach: recreate StatefulSet with same name; pods get same PVC names.

### DaemonSet pod not scheduled on a node
1. Check tolerations: node may have taints (e.g. master nodes): `kubectl describe node <name> | grep Taint`.
2. Add `tolerations` to DaemonSet pod spec to match node taints.
3. Check `nodeSelector` if set -- may exclude some nodes.
