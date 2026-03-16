# Secrets Management

- Secrets are sensitive credentials (API keys, passwords, tokens, certificates, private keys) that grant access to systems and data
- Managed through centralized stores that handle storage, access control, rotation, and audit logging
- Core principle: secrets must never exist in plaintext in code, config files, or logs

# Architecture

```text
+-------------+     auth      +------------------+     store/retrieve     +---------------+
| Application | -----------> | Secrets Manager  | <------------------->  | Encrypted     |
| (pod, VM,   |              | (Vault, AWS SM,  |                        | Backend       |
|  pipeline)  | <----------- | K8s Secrets)     |                        | (disk, KMS,   |
+-------------+   secret     +------------------+                        |  etcd)        |
                  value             |                                    +---------------+
                                    |
                              +------------+
                              | Audit Log  |
                              | (who, when,|
                              |  what)     |
                              +------------+
```

# Mental Model

```text
1. Application authenticates to secrets manager (token, IAM role, K8s SA)
2. Application requests a specific secret by path/name
3. Secrets manager checks policy (is this identity allowed?)
4. Secret is returned (or dynamically generated) with a TTL
5. Application uses secret; secret expires or is rotated on schedule
```

Example -- Vault dynamic database credentials:

```bash
# App authenticates to Vault via Kubernetes auth
vault login -method=kubernetes role=my-app

# App requests dynamic DB credentials
vault read database/creds/my-role
# Returns: username=v-my-app-abc123, password=xyz789, lease_duration=1h

# Credentials auto-expire after 1 hour; no manual rotation needed
```

# Core Building Blocks

### API Keys

- Key that identifies an application or user to an API
- Often sent in headers: `X-API-Key` or `Authorization: Bearer <key>`
- Rotate regularly; revoke immediately if compromised
- Treat as secrets -- never embed in client-side code or commit to git

Related notes: [authentication](./004-authentication.md)

### Tokens

- Short-lived credentials (OAuth access token, JWT)
- Stored in memory or secure storage; never in logs or URLs
- Expiry limits blast radius if leaked

Related notes: [authentication](./004-authentication.md)

### Certificates and Private Keys

- TLS certificates authenticate servers (and optionally clients) in encrypted connections
- Private keys must never be exposed; protect with file permissions (0600), HSM, or secret store
- Rotate before expiry; automate with tools like cert-manager or ACME/Let's Encrypt

Related notes: [cryptography](./001-cryptography.md), [symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### HashiCorp Vault

- Centralized secrets management; stores, generates, and leases secrets
- Dynamic secrets: creates short-lived credentials (DB, AWS, etc.) on demand -- no static passwords
- Encryption as a service: encrypt data without storing keys in the application

**Key concepts:**

- **Secret engine**: backend that manages a secret type (KV, database, AWS, PKI)
- **Auth method**: how clients prove identity (token, LDAP, Kubernetes, AppRole)
- **Policy**: HCL rules defining what secrets a role can read/write

**Request flow:**

```text
App -> Authenticate to Vault (e.g. Kubernetes SA token)
App -> Request secret (e.g. database/creds/my-role)
Vault -> Checks policy for this identity
Vault -> Returns secret (or generates dynamic credential with TTL)
```

Related notes: [authorization](./005-authorization.md)

### Kubernetes Secrets

- Native Kubernetes resource for storing sensitive data
- Base64-encoded by default -- not encrypted at rest unless encryption config is enabled
- Consumed by pods as mounted files or environment variables
- Access controlled via Kubernetes RBAC

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
type: Opaque
data:
  username: <base64>
  password: <base64>
```

**Best practices:**

- Enable encryption at rest (EncryptionConfiguration with KMS provider)
- Use external secret operators (External Secrets Operator, Secrets Store CSI Driver) to sync from Vault or cloud
- Avoid env vars for secrets when possible -- mounted files are harder to leak via process inspection

Related notes: [authorization](./005-authorization.md)

### AWS Secrets Manager

- Managed service for storing and rotating secrets (API keys, DB credentials, etc.)
- Automatic rotation for supported types (RDS, Redshift, DocumentDB) via Lambda
- IAM controls who can read/write; all access audited via CloudTrail

**vs AWS Systems Manager Parameter Store:**

| Feature          | Secrets Manager         | Parameter Store (SecureString) |
| :--------------- | :---------------------- | :----------------------------- |
| Rotation         | Built-in (Lambda)       | Manual                         |
| Cross-account    | Yes                     | Limited                        |
| Cost             | Paid per secret/call    | Free (standard tier)           |
| Best for         | Secrets needing rotation| Config values, simple secrets  |

Related notes: [authorization](./005-authorization.md)

### Secrets Management Principles

- **Never commit** secrets to git (use `.gitignore`, pre-commit hooks, secret scanning)
- **Rotate** regularly; have a documented revocation process
- **Least privilege**: applications get only the secrets they need
- **Audit**: log all access to secrets (who read what, when)
- **Encrypt at rest** and in transit (TLS for network, KMS for storage)
- **Prefer dynamic secrets** over static ones when the secrets manager supports it

Related notes: [authentication](./004-authentication.md), [authorization](./005-authorization.md)

---

# Practical Command Set (Core)

```bash
# --- Vault ---
vault status                                    # check Vault seal status
vault login -method=kubernetes role=my-app      # authenticate via K8s SA
vault kv get secret/myapp/config                # read KV secret
vault kv put secret/myapp/config key=value      # write KV secret
vault read database/creds/my-role               # get dynamic DB creds

# --- Kubernetes Secrets ---
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=s3cret               # create secret imperatively
kubectl get secret db-creds -o jsonpath='{.data.password}' | base64 -d
                                                # decode and read a secret

# --- AWS Secrets Manager ---
aws secretsmanager create-secret \
  --name myapp/db --secret-string '{"user":"admin","pass":"s3cret"}'
aws secretsmanager get-secret-value --secret-id myapp/db
aws secretsmanager rotate-secret --secret-id myapp/db
```

> Use `vault`, `kubectl`, and `aws` CLIs for quick secret operations; automate rotation in CI/CD pipelines.

# Troubleshooting Flow (Quick)

```text
Secret not accessible
  |-> Auth failure? -> verify identity (SA token, IAM role, Vault token)
  |-> Permission denied? -> check policy (Vault policy, K8s RBAC, IAM policy)
  |-> Secret not found? -> verify path/name (vault kv get, kubectl get secret)
  |-> Secret expired? -> check lease TTL / rotation status
  |-> Base64 issue (K8s)? -> ensure value is properly base64-encoded
  |-> Rotation broken? -> check Lambda logs (AWS) / lease config (Vault)
```

# Quick Facts (Revision)

- Secrets = API keys, passwords, tokens, certificates, private keys -- all must be protected
- Never commit secrets to version control; use pre-commit hooks and secret scanning
- Vault provides dynamic secrets with automatic expiry -- eliminates static credential sprawl
- Kubernetes Secrets are base64-encoded, not encrypted; enable encryption at rest with KMS
- AWS Secrets Manager supports automatic rotation via Lambda for RDS and other services
- Least privilege: each app should only access the secrets it needs
- Audit all secret access; use CloudTrail (AWS), audit logs (Vault), or K8s audit policy
- Prefer short-lived / dynamic secrets over long-lived static credentials
