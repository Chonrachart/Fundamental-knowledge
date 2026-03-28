# Certificates API and kubeconfig

### Overview
- **Why it exists** — Clusters need a way to issue signed certificates for new users and components without exposing the CA private key. Separately, every kubectl user needs a portable, structured way to carry cluster address, credentials, and context.
- **What it is** — Two related tools: the CertificateSigningRequest (CSR) API lets you request certs signed by the cluster CA through Kubernetes itself; kubeconfig is the config file (`~/.kube/config`) that stores cluster endpoints, user credentials, and named contexts so kubectl knows who it is and which cluster it is talking to.
- **One-liner** — CSR API = "get a cert signed by the cluster"; kubeconfig = "where is the cluster, who am I, which context am I in."

### Architecture (ASCII)

```text
  CSR Workflow
  ─────────────────────────────────────────────────────────────────
  User/App                 Kubernetes API             Cluster CA
     │                          │                          │
     │─ 1. openssl genrsa ──────┤                          │
     │─ 2. openssl req (CSR) ───┤                          │
     │─ 3. kubectl apply CSR ──►│                          │
     │                          │─ 4. admin approves ─────►│
     │                          │◄─ 5. signed cert ────────│
     │◄─ 6. kubectl get csr ────┤                          │

  kubeconfig Structure
  ─────────────────────────────────────────────────────────────────
  ~/.kube/config
  ┌─────────────────────────────────────────────────────────────┐
  │  clusters:                                                  │
  │    - name: prod                                             │
  │      server: https://prod-api:6443                         │
  │      certificate-authority-data: <base64 CA cert>          │
  │                                                             │
  │  users:                                                     │
  │    - name: alice                                            │
  │      client-certificate-data: <base64 client cert>         │
  │      client-key-data: <base64 client key>                  │
  │                                                             │
  │  contexts:                                                  │
  │    - name: alice@prod                                       │
  │      cluster: prod                                          │
  │      user: alice                                            │
  │      namespace: dev       (optional default namespace)      │
  │                                                             │
  │  current-context: alice@prod                                │
  └─────────────────────────────────────────────────────────────┘
```

### Mental Model

**CSR API:** The CA private key never leaves the control plane. Instead of handing out the key, you submit a certificate request through the API. An admin (or automated process) approves it, Kubernetes signs it, and you retrieve the signed cert. This keeps the CA key secure while allowing new identities to be minted on-demand.

**kubeconfig:** Think of it as a Rolodex. Each card (context) says "to talk to cluster X, use credentials Y, and default to namespace Z." You can have dozens of clusters in one file and switch between them with a single command.

### Core Building Blocks

### CertificateSigningRequest (CSR) API

- **Why it exists** — Provides a controlled, audited way to issue certificates without distributing the CA private key.
- **What it is** — A Kubernetes resource (`certificates.k8s.io/v1`) that wraps a PEM-encoded CSR and carries an approval status.
- **One-liner** — Submit a CSR object, get it approved, retrieve a signed cert.

#### Step-by-step workflow

```bash
# Step 1: Generate a private key
openssl genrsa -out alice.key 2048

# Step 2: Generate a CSR (CN becomes the username; O becomes the group)
openssl req -new -key alice.key -out alice.csr \
  -subj "/CN=alice/O=dev-team"

# Step 3: Encode and submit to the API
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: alice
spec:
  request: $(base64 -w0 alice.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400   # 1 day
  usages:
  - client auth
EOF

# Step 4: Approve the request
kubectl certificate approve alice

# Deny instead (if rejecting the request)
kubectl certificate deny alice

# Step 5: List all CSRs and their status
kubectl get csr
# NAME    AGE   SIGNERNAME                            REQUESTOR   CONDITION
# alice   10s   kubernetes.io/kube-apiserver-client   admin       Approved,Issued

# Step 6: Retrieve the signed certificate
kubectl get csr alice -o jsonpath='{.status.certificate}' | base64 -d > alice.crt

# Verify the signed cert
openssl x509 -in alice.crt -text -noout | grep Subject
```

#### CSR status values

| Condition | Meaning |
|-----------|---------|
| Pending | Submitted, waiting for approval |
| Approved,Issued | Approved and cert has been signed |
| Denied | Rejected; cert will not be issued |
| Expired | CSR is past its expiry window |

---

### kubeconfig

- **Why it exists** — Without a standard config file, every kubectl command would need `--server`, `--certificate-authority`, `--client-certificate`, and `--client-key` flags. kubeconfig bundles all of this into named, switchable contexts.
- **What it is** — A YAML file (default `~/.kube/config`, override with `KUBECONFIG` env var) with three top-level lists: `clusters`, `users`, and `contexts`.
- **One-liner** — A portable credential + cluster address store that kubectl reads on every invocation.

#### Viewing and switching contexts

```bash
# View the entire kubeconfig (redacts cert data by default)
kubectl config view

# Show unredacted (includes base64 cert data)
kubectl config view --raw

# Show active context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context alice@prod

# Set a default namespace on a context
kubectl config set-context --current --namespace=dev
```

#### Adding a new cluster, user, and context manually

```bash
# Add a cluster entry
kubectl config set-cluster prod \
  --server=https://prod-api:6443 \
  --certificate-authority=/path/to/ca.crt \
  --embed-certs=true

# Add a user entry (client cert auth)
kubectl config set-credentials alice \
  --client-certificate=alice.crt \
  --client-key=alice.key \
  --embed-certs=true

# Add a context that binds cluster + user
kubectl config set-context alice@prod \
  --cluster=prod \
  --user=alice \
  --namespace=dev

# Activate the new context
kubectl config use-context alice@prod
```

#### kubeconfig file structure (annotated YAML)

```yaml
apiVersion: v1
kind: Config

# Which context is active right now
current-context: alice@prod

clusters:
- name: prod
  cluster:
    server: https://prod-api:6443
    certificate-authority-data: <base64-encoded CA cert>  # --embed-certs stores it inline

users:
- name: alice
  user:
    client-certificate-data: <base64-encoded client cert>
    client-key-data: <base64-encoded private key>
    # Alternatively use token: <bearer-token> for ServiceAccount auth

contexts:
- name: alice@prod
  context:
    cluster: prod
    user: alice
    namespace: dev   # optional; kubectl defaults here if no -n flag
```

#### Multiple kubeconfig files

```bash
# Merge multiple files at runtime (does not modify files)
KUBECONFIG=~/.kube/config:~/.kube/dev-config kubectl get nodes

# Flatten and write to a single file
kubectl config view --flatten > ~/.kube/merged-config
```

### Troubleshooting

### kubectl: no configuration has been provided
1. `KUBECONFIG` env var is unset and `~/.kube/config` does not exist.
2. Copy the admin kubeconfig from the control plane: `scp control-plane:/etc/kubernetes/admin.conf ~/.kube/config`.
3. Or set `export KUBECONFIG=/path/to/config`.

### Error: You must be logged in to the server (Unauthorized)
1. The client cert in kubeconfig may be expired. Check: `openssl x509 -in <cert> -noout -enddate`.
2. The CN in the client cert may not map to any RBAC subject. Verify with `kubectl auth can-i list pods --as=alice`.
3. Re-issue the cert via the CSR API if expired.

### CSR stays in Pending forever
1. An admin must explicitly run `kubectl certificate approve <name>`.
2. Check if any controller is auto-approving (some cluster setups do this for kubelet CSRs).

### context not found
1. Run `kubectl config get-contexts` to see available contexts.
2. Context name is case-sensitive — verify spelling.
