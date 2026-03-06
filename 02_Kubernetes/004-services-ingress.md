Service
ClusterIP
NodePort
LoadBalancer
Ingress
DNS

---

# Service Types

- **ClusterIP**: Default; virtual IP only inside cluster; pods reach each other by service name.
- **NodePort**: Exposes service on each node's IP at a static port (30000–32767); good for dev or simple access.
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

# Headless Service

- **clusterIP: None**; no virtual IP; DNS returns all pod IPs (A records); used with StatefulSet.

# Ingress

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

# DNS

- CoreDNS provides cluster DNS; services get `<svc>.<ns>.svc.cluster.local`; pods get `<pod-ip>.<ns>.pod.cluster.local` (for headless).
- Short names: `<svc>.<ns>` or `<svc>` in same namespace.

# Endpoints

- Service has Endpoints (or EndpointSlice); list of pod IPs that match selector.
- Readiness probe failures remove pod from endpoints so traffic stops.
