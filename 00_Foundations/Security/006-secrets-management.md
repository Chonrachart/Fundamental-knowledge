API keys
tokens
certificates
private keys

Vault
Kubernetes secrets
AWS secrets manager

---

# What Are Secrets

- Secrets are sensitive credentials: API keys, passwords, tokens, certificates, private keys.
- Must be stored and accessed securely; never in code or config files in plaintext.

# API Keys

- Key that identifies an application or user to an API.
- Often sent in headers: `X-API-Key` or `Authorization: Bearer <key>`.
- Rotate regularly; revoke if compromised.

# Tokens

- Short-lived credentials (OAuth access token, JWT).
- Stored in memory or secure storage; not in logs or URLs.

# Certificates and Private Keys

- TLS certificates and their private keys.
- Private keys must never be exposed; use file permissions, HSM, or secret store.

# HashiCorp Vault

- Centralized secrets management; stores and generates secrets.
- Dynamic secrets: creates short-lived DB credentials on demand.
- Encryption as a service: encrypt data without storing keys in app.

### Concepts

- **Secret engine**: Backend (KV, database, AWS, etc.).
- **Auth method**: How clients authenticate (token, LDAP, Kubernetes).
- **Policy**: What secrets a role can access.

### Example Flow

```
App → Authenticate to Vault (e.g. Kubernetes auth)
App → Request secret (e.g. database credentials)
Vault → Returns secret (or generates dynamic secret)
```

# Kubernetes Secrets

- Native Kubernetes resource for storing secrets.
- Base64-encoded (not encrypted at rest by default); use RBAC to limit access.
- Mounted as files or env vars in pods.

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

### Best Practices

- Enable encryption at rest (encryption config).
- Use external secret operators (e.g. External Secrets, CSI driver) to sync from Vault or cloud.

# AWS Secrets Manager

- Managed service for storing secrets (API keys, DB credentials, etc.).
- Automatic rotation for supported types (RDS, etc.).
- IAM controls who can read; audit via CloudTrail.

### vs Parameter Store

- Parameter Store: free for standard params; can store secrets.
- Secrets Manager: rotation, cross-account access; paid.

# Secrets Management Principles

- **Never commit** secrets to git.
- **Rotate** regularly; have a revocation process.
- **Least privilege**: apps get only the secrets they need.
- **Audit**: log access to secrets.
- **Encrypt at rest** and in transit.