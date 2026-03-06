StatefulSet
DaemonSet
volumeClaimTemplate
stable identity
headless
pod management

---

# StatefulSet — When to Use

- Use when pods need **stable identity** (stable name, ordered creation/deletion), **stable storage** (PVC per pod), or **ordered rollout**.
- Typical: databases, distributed systems with leader election, apps that rely on fixed pod names.
- Pods get names: **\<statefulset-name>-\<ordinal>** (e.g. web-0, web-1); created in order 0, 1, 2... and deleted in reverse order.

# StatefulSet Spec (Key Fields)

- **serviceName**: Headless Service (clusterIP: None) used for pod identity and DNS; each pod gets **pod-name.serviceName.ns.svc.cluster.local**.
- **replicas**: Desired number of pods.
- **volumeClaimTemplates**: One PVC template per pod; each pod gets its own PVC **\<vc-name>-\<statefulset-name>-\<ordinal>**; PVC is not deleted when pod is deleted (retain data).
- **podManagementPolicy**: **OrderedReady** (default, create/delete in order) or **Parallel** (all at once).
- **updateStrategy**: RollingUpdate (with partition option) or OnDelete.

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

# Headless Service

- **clusterIP: None** → no virtual IP; DNS returns A records for each pod IP (web-0.web.ns.svc.cluster.local).
- Required for StatefulSet **serviceName**; allows peers to discover each other by name.

# DaemonSet — One Pod per Node

- Ensures **every** (or a subset of) node runs a copy of a pod; when nodes are added, DaemonSet adds a pod.
- Use for: node-level agents (logging, monitoring, storage), CNI, kube-proxy (in some setups).
- **nodeSelector** / **affinity** / **tolerations**: Limit which nodes get the pod (e.g. only GPU nodes).

# DaemonSet Spec

- No **replicas**; number of pods = number of matching nodes.
- **updateStrategy**: RollingUpdate (default, maxUnavailable in number) or OnDelete.
- **template**: Same as Deployment; often runs as privileged or mounts host paths (e.g. /var/log, /var/lib/docker).

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

# StatefulSet vs Deployment

| Aspect | Deployment | StatefulSet |
|--------|------------|-------------|
| Pod names | Random hash | Stable (name-0, name-1) |
| Storage | Shared or any | Often 1 PVC per pod (volumeClaimTemplate) |
| Order | No guarantee | Ordered create/delete (default) |
| DNS | Service round-robin | Per-pod DNS (headless) |
| Use case | Stateless apps | Stateful, clustered apps |

# DaemonSet vs Deployment

- **Deployment**: N replicas anywhere; scheduler places them.
- **DaemonSet**: One per node (or per matching node); for node-level workload.
