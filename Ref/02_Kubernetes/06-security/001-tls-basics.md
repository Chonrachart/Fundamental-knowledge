# TLS Basics in Kubernetes

# Overview
- **Why it exists** — Every component in a Kubernetes cluster communicates over a network. Without TLS, an attacker with network access could intercept traffic, steal secrets, or impersonate components. Kubernetes enforces mutual TLS (mTLS) everywhere — all component-to-component communication is encrypted and both sides verify each other's identity.
- **What it is** — TLS (Transport Layer Security) is the protocol that provides encryption and authentication over TCP. In Kubernetes, every component acts as both a server (accepts connections) and a client (initiates connections), so each component holds both a certificate and a private key, and all certificates are signed by a shared Certificate Authority (CA).
- **One-liner** — TLS ensures no Kubernetes component communicates over plain HTTP; every connection is encrypted and mutually authenticated via certificates.

# Architecture

```text
                    ┌──────────────────────────────────────┐
                    │        Kubernetes CA (root)           │
                    │   /etc/kubernetes/pki/ca.crt          │
                    │   /etc/kubernetes/pki/ca.key          │
                    └──────────────┬───────────────────────┘
                                   │ signs all component certs
              ┌────────────────────┼──────────────────────┐
              │                    │                       │
    ┌─────────▼─────────┐ ┌────────▼────────┐  ┌─────────▼────────┐
    │   API Server       │ │     etcd        │  │    kubelet        │
    │ apiserver.crt/.key │ │ etcd.crt/.key   │  │ kubelet.crt/.key  │
    └────────────────────┘ └─────────────────┘  └──────────────────┘

  mTLS: both sides present a cert, both sides verify it was signed by the CA
  ─────────────────────────────────────────────────────────────────────────
  API Server ◄──── mTLS ────► etcd
  API Server ◄──── mTLS ────► kubelet
  API Server ◄──── mTLS ────► controller-manager
  API Server ◄──── mTLS ────► scheduler
  kubectl    ──── mTLS ────► API Server   (via kubeconfig client cert)
```

# Mental Model

Think of the cluster CA as the company's HR department. HR prints ID badges (certificates). When two employees (components) meet, each shows their badge. Because both badges were issued by the same HR office, each employee trusts the other without having met before. If the badge was not issued by HR, access is denied.

Two roles per cert:
- **Server cert** — proves "I am who I claim to be" when a client connects to me.
- **Client cert** — proves "I am who I claim to be" when I initiate a connection.

Components that act as both server and client (e.g. API server) carry both.

# Core Building Blocks

### Certificate Authority (CA)
- **Why it exists** — A central trust anchor so every component can verify every other component's certificate without needing a per-pair configuration.
- **What it is** — A self-signed root certificate (`ca.crt`) and its private key (`ca.key`). Kubernetes has at least two CAs: one for the main cluster PKI and one dedicated to etcd. Kubeadm creates these automatically.
- **One-liner** — The CA is the single source of truth for "who is allowed to present a certificate in this cluster."

```bash
# Inspect the cluster CA
openssl x509 -in /etc/kubernetes/pki/ca.crt -text -noout | grep -E 'Subject:|Issuer:|Not After'
```

### Client Certs vs Server Certs
- **Why it exists** — Distinguishes authentication direction: a server cert says "this is my identity when you connect to me"; a client cert says "this is my identity when I connect to you."
- **What it is** — The difference is in the X.509 Extended Key Usage field: `serverAuth` for server certs, `clientAuth` for client certs. Many Kubernetes certs carry both.
- **One-liner** — Server cert = "trust me as a server"; client cert = "trust me as a client."

### Certificate Locations
- **Why it exists** — All certs are stored in a known location so kubeadm, kubelet, and kubectl can find them predictably.
- **What it is** — `/etc/kubernetes/pki/` on the control-plane node.

```bash
ls /etc/kubernetes/pki/
# Common files:
#   ca.crt / ca.key                   — cluster root CA
#   apiserver.crt / apiserver.key     — API server server cert
#   apiserver-kubelet-client.crt/.key — API server → kubelet client cert
#   apiserver-etcd-client.crt/.key    — API server → etcd client cert
#   etcd/ca.crt                       — etcd CA (separate CA)
#   etcd/server.crt / etcd/server.key — etcd server cert
#   front-proxy-ca.crt                — front proxy CA
```

### Component Certificate Map

| Component | Cert file | Key file | Role |
|-----------|-----------|----------|------|
| API Server (server) | `apiserver.crt` | `apiserver.key` | Serves HTTPS for kubectl, kubelets |
| API Server → kubelet (client) | `apiserver-kubelet-client.crt` | `apiserver-kubelet-client.key` | API server calls kubelet API |
| API Server → etcd (client) | `apiserver-etcd-client.crt` | `apiserver-etcd-client.key` | API server reads/writes etcd |
| etcd (server) | `etcd/server.crt` | `etcd/server.key` | Serves etcd API |
| etcd (peer) | `etcd/peer.crt` | `etcd/peer.key` | etcd cluster member replication |
| kubelet (server) | `/var/lib/kubelet/pki/kubelet.crt` | `kubelet.key` | API server calls kubelet |
| controller-manager (client) | `controller-manager.conf` (kubeconfig) | embedded | Calls API server |
| scheduler (client) | `scheduler.conf` (kubeconfig) | embedded | Calls API server |
| admin (client) | `admin.conf` (kubeconfig) | embedded | kubectl access |

### Inspecting Certificates

```bash
# Full cert details
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout

# Key fields to look for:
#   Subject: CN=kube-apiserver
#   Issuer: CN=kubernetes  (the cluster CA)
#   Not After: <expiry date>
#   X509v3 Subject Alternative Names: DNS:kubernetes, DNS:kubernetes.default, IP:10.96.0.1 ...
#   X509v3 Extended Key Usage: TLS Web Server Authentication

# Check expiry across all certs (kubeadm)
kubeadm certs check-expiration

# Renew all certs
kubeadm certs renew all
```
