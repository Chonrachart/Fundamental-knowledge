# Ingress and Gateway API

# Overview
- **Why it exists** — Without Ingress, every HTTP service needs its own LoadBalancer (one cloud LB per service = expensive and hard to manage). Ingress consolidates HTTP/HTTPS routing behind one load balancer, using host and path rules to fan traffic to multiple backend services.
- **What it is** — Ingress is a Kubernetes API object that defines HTTP routing rules. A separate **Ingress controller** (e.g., nginx-ingress, Traefik) watches these objects and configures a reverse proxy accordingly. Gateway API is the successor — more expressive, role-oriented, and supports more protocols.
- **One-liner** — Ingress is one load balancer + one reverse proxy handling HTTP routing to many services; Gateway API is its more powerful successor.

# Architecture

```text
Internet
   │
   ▼
Cloud LoadBalancer (single public IP)
   │
   ▼
Ingress Controller Pod (nginx / traefik / etc.)
   │  watches Ingress resources via API server
   │
   ├── host: app.example.com  → Service: app-svc:80
   ├── host: api.example.com  → Service: api-svc:8080
   └── host: app.example.com
         path: /static        → Service: cdn-svc:80
         path: /              → Service: app-svc:80

Each backend Service → Endpoints → Pod IPs
```

# Mental Model

An Ingress resource is just configuration — it does nothing on its own. You must install an Ingress controller first. The controller is a pod (often in `ingress-nginx` namespace) that:
1. Gets a LoadBalancer Service or NodePort to receive external traffic
2. Watches all Ingress resources in the cluster
3. Dynamically reconfigures its proxy rules as Ingress objects change

Think of it as: Ingress resource = nginx.conf rules; Ingress controller = the nginx process that loads them.

```text
External request: https://app.example.com/api/v1/users

1. DNS: app.example.com → LoadBalancer IP
2. LB forwards to Ingress Controller pod
3. Controller matches: host=app.example.com, path prefix=/api → api-svc:8080
4. Forwards to api-svc ClusterIP → iptables DNAT → pod IP
5. Pod handles request
```

# Core Building Blocks

### Ingress Controller
- **Why it exists** — The Ingress resource defines what routing should happen; the controller makes it happen.
- **What it is** — A pod (or set of pods) running a reverse proxy (nginx, Traefik, HAProxy, etc.) that watches Ingress resources and programs its routing accordingly. Not built into Kubernetes — you must install one.
- **One-liner** — The actual proxy pod that implements Ingress rules; without it, Ingress objects are inert.

```bash
# Install nginx ingress controller (example)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Check controller is running
kubectl get pods -n ingress-nginx

# Check controller's LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### Host-Based Routing

Routes traffic based on the HTTP `Host` header — different domains to different backends.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: host-routing
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-svc
            port:
              number: 80
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 8080
```

### Path-Based Routing

Routes traffic to different backends based on the URL path — same domain, multiple services.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: path-routing
spec:
  rules:
  - host: example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 8080
      - path: /static
        pathType: Prefix
        backend:
          service:
            name: cdn-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-svc
            port:
              number: 80
```

### TLS Termination
- **Why it exists** — HTTPS should terminate at the edge (controller) so backend services don't need to handle TLS.
- **What it is** — A TLS Secret containing `tls.crt` and `tls.key` referenced in the Ingress spec. The controller loads the cert, terminates TLS, and forwards plain HTTP to the backend service.
- **One-liner** — Attach a TLS Secret to the Ingress spec to enable HTTPS termination at the controller.

```bash
# Create TLS secret (from existing cert files)
kubectl create secret tls my-tls-secret \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key
```

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:
  - hosts:
    - app.example.com
    secretName: my-tls-secret   # Secret with tls.crt and tls.key
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app-svc
            port:
              number: 80
```

### Inspecting Ingress

```bash
# List all ingress resources
kubectl get ingress -A

# Describe an ingress (shows rules, backend health, events)
kubectl describe ingress <name>

# Check which services the ingress points to
kubectl get ingress <name> -o yaml

# Check ingress controller access logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller
```

### Gateway API (Successor to Ingress)
- **Why it exists** — Ingress has limitations: no TCP/UDP support, no traffic splitting, all config in one object mixing infrastructure and routing concerns. Gateway API fixes this with a richer, role-oriented model.
- **What it is** — A set of CRDs (`GatewayClass`, `Gateway`, `HTTPRoute`, `TCPRoute`, etc.) that express network routing with clear separation of concerns — cluster operators manage `Gateway`, app developers manage `HTTPRoute`.
- **One-liner** — Gateway API is the official successor to Ingress, with better role separation, more protocol support, and native traffic splitting.

```yaml
# Gateway API example: HTTPRoute
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app-route
spec:
  parentRefs:
  - name: my-gateway       # references the Gateway object
  hostnames:
  - "app.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-svc
      port: 8080
```

### Ingress vs Gateway API Comparison

| Feature | Ingress | Gateway API |
|---------|---------|-------------|
| API stability | Stable (v1) | GA since 1.28 |
| Role separation | None — one object | GatewayClass (infra) / Gateway (ops) / Route (dev) |
| HTTP routing | Host + path | Host + path + header + query |
| Traffic splitting | Via annotations | Native (weight-based backendRefs) |
| TCP/UDP support | No | Yes (TCPRoute, UDPRoute) |
| TLS passthrough | Via annotations | Native |
| Extensibility | Annotations (non-standard) | Policy attachment (standard) |
| Portability | Low (annotation hell) | High (standard spec) |
| Adoption | Universal | Growing; nginx, Traefik, Istio support it |
