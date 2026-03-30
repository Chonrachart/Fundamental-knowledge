# StatefulSets

# Overview

- **Why it exists** — Databases, message queues, and clustered apps like Redis or Elasticsearch need stable network identities and persistent storage that survive pod restarts and rescheduling. Deployments give pods random names and transient storage — unsuitable for stateful apps.
- **What it is** — A workload controller like Deployment, but designed for stateful applications. StatefulSets give each pod a stable, ordered name (`mysql-0`, `mysql-1`, `mysql-2`), a stable DNS hostname via a headless Service, and its own PersistentVolumeClaim that persists across pod restarts and rescheduling.
- **One-liner** — A StatefulSet gives each pod a permanent identity (name, DNS, storage) that survives restarts and rescheduling.

# Architecture

```text
StatefulSet "mysql" (replicas: 3)
  Headless Service (clusterIP: None, name: mysql)
      │
      ├── mysql-0  ←→  PVC: data-mysql-0   DNS: mysql-0.mysql.default.svc.cluster.local
      ├── mysql-1  ←→  PVC: data-mysql-1   DNS: mysql-1.mysql.default.svc.cluster.local
      └── mysql-2  ←→  PVC: data-mysql-2   DNS: mysql-2.mysql.default.svc.cluster.local
           ↑
           Created in order 0→1→2 (each waits for previous to be Ready)
           Deleted in reverse order 2→1→0
           If mysql-1 is rescheduled → same name, same PVC, same DNS
```

# Mental Model

```text
Scenario: Deploy a 3-node MySQL cluster with StatefulSet

1. Create Headless Service (clusterIP: None, name: mysql)
2. Create StatefulSet (serviceName: mysql, replicas: 3, volumeClaimTemplates)

3. Kubernetes creates pods in order:
     mysql-0 first → waits until Running and Ready
     mysql-1 next  → waits until Running and Ready
     mysql-2 last

4. Each pod gets:
     Stable hostname: mysql-0.mysql.default.svc.cluster.local
     Own PVC:         data-mysql-0 (provisioned from StorageClass)

5. Pod mysql-1 is rescheduled to a different node:
     → pod is recreated with SAME name: mysql-1
     → SAME PVC is reattached: data-mysql-1
     → SAME DNS: mysql-1.mysql.default.svc.cluster.local
     → application data intact

Key difference from Deployment:
  Deployment: pod names have random hashes, get new PVCs on reschedule
  StatefulSet: pod names are stable ordinals, PVCs follow the pod
```

# Core Building Blocks

### Stable Pod Identity

- **Why it exists** — Clustered apps need to identify specific members (primary vs replica, shard owner) by a stable name rather than a random hash.
- **What it is** — Pods are named `<statefulset-name>-<ordinal>` where ordinal starts at 0. The name is deterministic and never changes as long as the StatefulSet exists. Even if a pod is deleted and recreated, it gets the same name and ordinal.
- **One-liner** — StatefulSet pods have permanent names (`app-0`, `app-1`) unlike Deployment pods which have random hashes.

### Ordered Creation and Deletion

- **Why it exists** — Many clustered apps require the first node (ordinal 0) to initialize before others join, and require graceful ordered shutdown.
- **What it is** — By default (`podManagementPolicy: OrderedReady`), pods are created one at a time in ascending order (0, 1, 2...) and each pod must be Running and Ready before the next is created. Deletion goes in reverse order (2, 1, 0). This can be changed to `Parallel` if ordering is not needed.
- **One-liner** — Ordered startup/shutdown ensures clustered apps can safely initialize and drain in sequence.

### Headless Service Requirement

- **Why it exists** — StatefulSet pods need individual DNS names so they can discover and communicate with specific peers.
- **What it is** — StatefulSets require a headless Service (`clusterIP: None`) specified in `spec.serviceName`. This Service creates a DNS A record for each pod: `<pod-name>.<service-name>.<namespace>.svc.cluster.local`. Unlike regular Services, no virtual IP is created — DNS returns the actual pod IP.
- **One-liner** — The headless Service is what gives each StatefulSet pod its own stable DNS hostname.

```yaml
# Required headless service
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  clusterIP: None    # headless
  selector:
    app: mysql
  ports:
  - port: 3306
```

### volumeClaimTemplates

- **Why it exists** — Each pod needs its own PersistentVolumeClaim so their data is separate and persists independently across restarts.
- **What it is** — A template in the StatefulSet spec that Kubernetes uses to create one PVC per pod automatically. PVC names follow the pattern `<template-name>-<pod-name>` (e.g. `data-mysql-0`). Critically, PVCs are NOT deleted when pods are deleted or when the StatefulSet is deleted — data is preserved until you manually delete the PVCs.
- **One-liner** — volumeClaimTemplates automatically provisions one dedicated PVC per pod that outlives pod restarts and deletions.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql      # must match headless service name
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources:
        requests:
          storage: 10Gi
```

### StatefulSet vs Deployment

| Aspect | Deployment | StatefulSet |
|--------|------------|-------------|
| Pod names | Random hash (e.g. `app-7d9f8b`) | Stable ordinal (e.g. `app-0`) |
| Storage | Shared or no PVC per pod | One PVC per pod via volumeClaimTemplate |
| Startup order | No guarantee (all at once) | Ordered (0 → 1 → 2, each waits) |
| DNS per pod | No (Service round-robins) | Yes (headless Service, per-pod A record) |
| PVC lifecycle | Deleted with pod | Retained when pod/StatefulSet deleted |
| Use case | Stateless apps (web servers, APIs) | Stateful apps (databases, message queues) |

### Use Cases

Common applications deployed as StatefulSets:
- **Databases**: MySQL, PostgreSQL, MongoDB, Cassandra
- **Message queues**: Kafka, RabbitMQ
- **Caches/stores**: Redis Cluster, Elasticsearch, ZooKeeper
- **Any clustered app** where members need stable identities to form a cluster

```bash
# Common StatefulSet commands
kubectl get statefulsets
kubectl get sts                           # short form
kubectl describe sts mysql
kubectl scale sts mysql --replicas=5

# Check pods and their PVCs
kubectl get pods -l app=mysql
kubectl get pvc -l app=mysql

# Delete StatefulSet (pods go, PVCs stay)
kubectl delete sts mysql
kubectl get pvc    # PVCs still exist — data safe
kubectl delete pvc data-mysql-0 data-mysql-1 data-mysql-2   # manual cleanup
```
