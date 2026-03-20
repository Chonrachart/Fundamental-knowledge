# Services and Ingress

- A Service provides a stable DNS name and virtual IP for a set of pods, decoupling consumers from pod lifecycle changes.
- Service types (ClusterIP, NodePort, LoadBalancer) control where traffic can originate; Ingress adds HTTP/HTTPS routing on top.
- CoreDNS resolves service names within the cluster; endpoints track which pod IPs back each service.

# Architecture

```text
ClusterIP                NodePort                   LoadBalancer
┌──────────┐        ┌──────────────┐         ┌───────────────────┐
│ Internal │        │  External    │         │  Cloud LB         │
│ pod/svc  │        │  client      │         │  (public IP)      │
│    │     │        │    │         │         │    │              │
│    ▼     │        │    ▼         │         │    ▼              │
│ ClusterIP│        │ NodeIP:30xxx │         │ NodeIP:30xxx      │
│ 10.96.x.x│       │    │         │         │    │              │
│    │     │        │    ▼         │         │    ▼              │
│    ▼     │        │ ClusterIP    │         │ ClusterIP         │
│  Pods    │        │    │         │         │    │              │
└──────────┘        │    ▼         │         │    ▼              │
                    │  Pods        │         │  Pods             │
                    └──────────────┘         └───────────────────┘
```

```text
Ingress Flow:

Client → Ingress Controller (nginx/traefik pod)
              │
              ▼
        Ingress rules match host + path
              │
              ▼
        Route to backend Service:port
              │
              ▼
        Service forwards to pod endpoints
```

# Core Building Blocks

### Service Types

- **ClusterIP**: Default; virtual IP only inside cluster; pods reach each other by service name.
- **NodePort**: Exposes service on each node's IP at a static port (30000-32767); good for dev or simple access.
- **LoadBalancer**: Cloud provider creates external load balancer; points to nodes (or to NodePort); typical for cloud.

```yaml
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
  - port: 80
    targetPort: 8080
```

### Headless Service

- **clusterIP: None**; no virtual IP; DNS returns all pod IPs (A records); used with StatefulSet.

### Ingress

- HTTP/HTTPS routing into the cluster; one load balancer for many services.
- **Ingress resource**: Rules (host, path → backend service); TLS.
- **Ingress controller**: Watches Ingress; configures LB or reverse proxy (e.g. nginx, traefik).

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myingress
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web
            port:
              number: 80
```

### DNS

- CoreDNS provides cluster DNS; services get `<svc>.<ns>.svc.cluster.local`; pods get `<pod-ip>.<ns>.pod.cluster.local` (for headless).
- Short names: `<svc>.<ns>` or `<svc>` in same namespace.

### Endpoints

- Service has Endpoints (or EndpointSlice); list of pod IPs that match selector.
- Readiness probe failures remove pod from endpoints so traffic stops.

Related notes: [001-kubernetes-overview](./001-kubernetes-overview.md), [002-pods-labels](./002-pods-labels.md), [006-kubectl-debugging](./006-kubectl-debugging.md)

---

# Troubleshooting Guide

### Service returns "connection refused"
1. Check endpoints: `kubectl get endpoints <svc>` — if empty, selector doesn't match pod labels.
2. Check pod is running and ready: `kubectl get pods -l <selector>`.
3. Verify `targetPort` matches the port app listens on inside container.

### Ingress returns 404 or 502
1. Check Ingress controller is running: `kubectl get pods -n ingress-nginx`.
2. Check Ingress resource: `kubectl describe ingress <name>` — verify host, path, backend.
3. 502: backend service/pod not ready; check pod logs.
4. Verify service port matches Ingress backend port number.

### NodePort not reachable from outside
1. Check NodePort range: must be 30000-32767.
2. Check firewall on node: `iptables -L -n` or cloud security group.
3. Verify with: `curl <node-ip>:<nodeport>`.
4. Check kube-proxy is running: `kubectl get pods -n kube-system -l k8s-app=kube-proxy`.

# Quick Facts (Revision)

- ClusterIP is the default Service type; it is only reachable from within the cluster.
- NodePort builds on ClusterIP; LoadBalancer builds on NodePort — each type is a superset.
- Headless service (`clusterIP: None`) returns pod IPs directly via DNS, not a virtual IP.
- Ingress requires a running Ingress controller; the Ingress resource alone does nothing.
- Service DNS format: `<svc>.<namespace>.svc.cluster.local`.
- Endpoints are updated automatically when pods match/unmatch the selector or fail readiness probes.
- `targetPort` is the port the container listens on; `port` is what the Service exposes.
