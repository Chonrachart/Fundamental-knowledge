cluster
pod
deployment
service
kubectl

---

# Cluster

- **Control plane**: API server, scheduler, controller-manager, etcd.
- **Nodes**: Run kubelet and container runtime; execute pods.
- `kubectl cluster-info` — check cluster.

# Pod

- Smallest unit; one or more containers; shared network (localhost) and storage.
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

# Deployment

- Manages ReplicaSet and pods; declarative desired state.
- Rolling update, rollback; scale with `kubectl scale`.

```bash
kubectl apply -f deployment.yaml
kubectl get deployments
kubectl scale deployment/myapp --replicas=3
```

# Service

- Stable DNS and IP for pods; types: ClusterIP, NodePort, LoadBalancer.
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

# kubectl

- CLI to talk to cluster; uses kubeconfig for auth and cluster.

```bash
kubectl get pods
kubectl get nodes
kubectl describe pod <name>
kubectl logs <pod>
kubectl exec -it <pod> -- sh
```
