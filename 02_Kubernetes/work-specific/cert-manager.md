# cert-manager

- Kubernetes add-on that automates provisioning, renewal, and management of TLS certificates as native resources.
- Watches Certificate custom resources, requests certs from configured Issuers (self-signed, Let's Encrypt, Vault, etc.), stores them as Kubernetes Secrets.
- Key property: certificates renew automatically before expiry — no manual rotation.

# Architecture

```text
┌──────────────────────────────────────────────────────────────────┐
│                        cert-manager                              │
│                                                                  │
│  ┌──────────────────┐   ┌──────────────┐   ┌─────────────────┐  │
│  │ cert-manager     │   │ webhook      │   │ cainjector      │  │
│  │ controller       │   │              │   │                 │  │
│  │                  │   │ validates    │   │ injects CA      │  │
│  │ watches CRDs,    │   │ Certificate  │   │ bundles into    │  │
│  │ issues certs,    │   │ and Issuer   │   │ webhook configs │  │
│  │ renews before    │   │ resources    │   │ and CRDs        │  │
│  │ expiry           │   │              │   │                 │  │
│  └────────┬─────────┘   └──────────────┘   └─────────────────┘  │
│           │                                                      │
└───────────┼──────────────────────────────────────────────────────┘
            │
    ┌───────┴────────────────────────────┐
    │           Issuer / ClusterIssuer   │
    │                                    │
    │  ┌──────────┐ ┌────────────────┐   │
    │  │SelfSigned│ │ Let's Encrypt  │   │
    │  │          │ │ (ACME)         │   │
    │  └──────────┘ └────────────────┘   │
    │  ┌──────────┐ ┌────────────────┐   │
    │  │ CA       │ │ Vault / Venafi │   │
    │  │ (own CA) │ │ (enterprise)   │   │
    │  └──────────┘ └────────────────┘   │
    └────────────────────────────────────┘
            │
            ▼
    ┌────────────────────┐
    │  Kubernetes Secret │
    │  (tls.crt, tls.key)│
    │                    │
    │  consumed by:      │
    │  - Ingress         │
    │  - Rancher         │
    │  - any pod         │
    └────────────────────┘
```

# Mental Model

```text
Issuer defines WHERE to get certs
         │
         ▼
Certificate defines WHAT cert to get (domain, secret name)
         │
         ▼
cert-manager controller creates CertificateRequest
         │
         ▼
Issuer signs or requests from CA/ACME
         │
         ▼
cert-manager stores cert in Secret (tls.crt + tls.key)
         │
         ▼
Ingress or pod mounts the Secret for TLS
```

Concrete example:
```yaml
# 1. Create an Issuer (self-signed for internal use)
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-issuer
spec:
  selfSigned: {}
---
# 2. Request a Certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-tls
  namespace: default
spec:
  secretName: my-app-tls-secret    # cert stored here
  duration: 2160h                  # 90 days
  renewBefore: 360h               # renew 15 days before expiry
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
    - myapp.example.local

# 3. Verify
# kubectl get certificate my-app-tls
# kubectl get secret my-app-tls-secret
```

# Core Building Blocks

### Issuer vs ClusterIssuer

- **Issuer**: namespace-scoped; can only issue certs within its own namespace.
- **ClusterIssuer**: cluster-wide; any namespace can reference it.
- Choose ClusterIssuer for shared CAs (self-signed, Let's Encrypt) used across namespaces.

```yaml
# Namespace-scoped
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: my-issuer
  namespace: default       # only works in default namespace

# Cluster-scoped
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: my-cluster-issuer  # works in any namespace
```

### Issuer Types

| Type | Use case | How it works |
|------|----------|-------------|
| SelfSigned | Dev/internal (`.local` domains) | Generates its own CA; browsers show warning |
| CA | Internal PKI | Uses your own CA cert/key stored in a Secret |
| ACME (Let's Encrypt) | Public domains | HTTP-01 or DNS-01 challenge to prove domain ownership |
| Vault | Enterprise | Requests certs from HashiCorp Vault PKI |
| Venafi | Enterprise | Integrates with Venafi TPP or Cloud |

### Certificate Resource

- Declares desired certificate: domain names, duration, renewal window, issuer reference.
- cert-manager creates a `CertificateRequest` → Issuer signs → stores in `secretName`.
- Automatic renewal: triggers when `renewBefore` threshold is reached.

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
  namespace: default
spec:
  secretName: example-tls-secret
  issuerRef:
    name: selfsigned-issuer
    kind: ClusterIssuer
  dnsNames:
    - app.example.local
    - www.example.local
  duration: 2160h          # 90 days
  renewBefore: 360h        # renew 15 days before expiry
```

### ACME (Let's Encrypt) Challenges

Two methods to prove domain ownership:

| Challenge | How it works | When to use |
|-----------|-------------|-------------|
| HTTP-01 | cert-manager creates temp Ingress at `/.well-known/acme-challenge/` | Public-facing Ingress exists |
| DNS-01 | cert-manager creates TXT record via DNS provider API | Wildcard certs, no public Ingress |

```yaml
# Let's Encrypt with HTTP-01
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v2.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-key
    solvers:
      - http01:
          ingress:
            class: nginx
```

### Ingress Integration

- Add annotation `cert-manager.io/cluster-issuer` to an Ingress.
- cert-manager automatically creates a Certificate and populates the Secret.
- No need to create a Certificate resource manually.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  annotations:
    cert-manager.io/cluster-issuer: "selfsigned-issuer"
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - myapp.example.local
      secretName: myapp-tls        # cert-manager creates this
  rules:
    - host: myapp.example.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

Related notes: [004-services-ingress](./004-services-ingress.md), [005-configmaps-secrets](./005-configmaps-secrets.md)

### Components (3 pods)

| Component | Role |
|-----------|------|
| `cert-manager` | Main controller; watches CRDs, creates requests, stores certs |
| `cert-manager-webhook` | Validates Certificate/Issuer resources via admission webhook |
| `cert-manager-cainjector` | Injects CA bundles into webhooks and CRDs |


- cert-manager automates TLS certificate lifecycle: issue, store, renew.
- Issuer (namespace-scoped) vs ClusterIssuer (cluster-wide) define where certs come from.
- Certificate resource defines what cert to get; result stored in a Kubernetes Secret.
- Auto-renewal happens based on `renewBefore` — no manual intervention needed.
- Self-signed for internal/dev; ACME (Let's Encrypt) for public domains.
- Ingress annotation `cert-manager.io/cluster-issuer` auto-creates certificates.
- Three components: controller (issues certs), webhook (validates CRDs), cainjector (injects CA bundles).
- Install via static manifest or Helm; requires CRDs to be installed first.
