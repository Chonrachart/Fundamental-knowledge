# API Authentication

- Authentication verifies the identity of an API caller; authorization determines what that caller is allowed to do.
- Methods range from simple API keys to OAuth 2.0 flows, each with different security and complexity tradeoffs.
- Cloud providers implement their own auth mechanisms, but the core principles (credentials, tokens, scopes, expiry) are universal.

# Architecture

```text
+----------+                                   +----------+
|          |   request + credentials            |          |
|  Client  |  --------------------------------> |  API     |
|          |   (API key / Bearer token / etc.)  |  Server  |
|          |                                    |          |
|          |  <-------------------------------  |          |
|          |   200 OK (authorized)              |          |
|          |   or 401/403 (rejected)            |          |
+----------+                                   +-----+----+
                                                      |
                                                      v
                                               +------------+
                                               | Auth Store |
                                               | (keys, DB, |
                                               |  IdP, IAM) |
                                               +------------+

Auth flow variations:

  API key:     Client --> API key in header/query --> Server validates
  Bearer:      Client --> token in Authorization header --> Server validates
  OAuth 2.0:   Client --> auth server (get token) --> API server (use token)
  Basic auth:  Client --> base64(user:pass) in header --> Server validates
```

# Mental Model

```text
Choosing an auth method:

  Is it a quick script or internal tool?
      |
      +-- yes --> API key (simplest)
      |
      +-- no
          |
          v
  Is it service-to-service (no human)?
      |
      +-- yes --> OAuth 2.0 client credentials grant
      |            or cloud provider service account
      |
      +-- no
          |
          v
  Is it a user-facing app that needs delegated access?
      |
      +-- yes --> OAuth 2.0 authorization code flow
      |
      +-- no
          |
          v
  Last resort / legacy system?
      +-- Basic auth over HTTPS
```

```bash
# test authentication with a bearer token
curl -s -H "Authorization: Bearer $TOKEN" \
  https://api.example.com/v1/me
```

# Core Building Blocks

### API Keys

- Simplest auth method: a static string passed in a header or query parameter.
- The server matches the key against a stored list; no cryptographic handshake.
- Easy to implement, but limited: no expiry by default, hard to scope, must be rotated manually.

```bash
# API key in a custom header (most common)
curl -s -H "X-API-Key: abc123def456" \
  https://api.example.com/v1/resources

# API key as query parameter (less secure -- visible in logs)
curl -s "https://api.example.com/v1/resources?api_key=abc123def456"
```

```text
Pros:                        Cons:
- Simple to implement        - No built-in expiry
- Easy to understand         - Hard to scope permissions
- Works everywhere           - If leaked, full access until revoked
                             - Visible in logs if sent as query param
```

Related notes: [001-rest-concepts](./001-rest-concepts.md)
- **Audit and monitor** API key usage; revoke unused credentials.

### Bearer Tokens and JWT

- Bearer tokens are passed in the Authorization header: `Authorization: Bearer <token>`.
- JWT (JSON Web Token) is a common token format: three base64-encoded parts separated by dots.
- Tokens have expiry (exp claim); the server can validate without a database call if using signed JWTs.

```text
JWT structure:

  eyJhbGciOi...   .   eyJzdWIiOi...   .   SflKxwRJSM...
  \____________/       \____________/       \____________/
     Header              Payload              Signature
   (algorithm)       (claims: sub, exp,     (cryptographic
                      iss, scope, ...)        signature)

Common claims:
  sub  -- subject (who the token represents)
  iss  -- issuer (who created the token)
  exp  -- expiry time (Unix timestamp)
  aud  -- audience (intended recipient)
  scope -- permissions granted
```

```bash
# use a bearer token
curl -s -H "Authorization: Bearer eyJhbGci..." \
  https://api.example.com/v1/resources

# decode a JWT payload (without verification)
echo "eyJzdWIi..." | base64 -d 2>/dev/null | jq .

# decode JWT from a full token (split on dots, take payload)
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq .

# check token expiry from JWT
echo "$TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '.exp | todate'
```

Related notes: [001-rest-concepts](./001-rest-concepts.md)

### OAuth 2.0

- OAuth 2.0 is an authorization framework; it delegates access without sharing credentials.
- For DevOps (service-to-service), the **client credentials grant** is the most relevant flow.
- The client authenticates with the auth server, receives an access token, then uses it against the API.

```text
Client Credentials Grant (service-to-service):

  +----------+                          +------------+
  |  Client  |  -- client_id +          |  Auth      |
  | (script, |     client_secret -->    |  Server    |
  |  CI/CD)  |                          |  (IdP)     |
  |          |  <-- access_token ---    |            |
  +----------+                          +------------+
       |
       |  Authorization: Bearer <access_token>
       v
  +----------+
  |  API     |
  |  Server  |
  +----------+
```

```bash
# obtain an access token (client credentials grant)
curl -s -X POST \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "scope=read:resources" \
  https://auth.example.com/oauth/token

# use the returned token
TOKEN=$(curl -s -X POST ... | jq -r '.access_token')
curl -s -H "Authorization: Bearer $TOKEN" \
  https://api.example.com/v1/resources
```

Related notes: [001-rest-concepts](./001-rest-concepts.md)

### Basic Auth

- Encodes username:password in base64 and sends in the Authorization header.
- NOT encryption -- base64 is trivially reversible; only use over HTTPS.
- Common in legacy systems, internal tools, and some CI/CD integrations.

```bash
# basic auth with curl (-u flag handles encoding)
curl -s -u "admin:secret123" https://api.example.com/v1/resources

# equivalent manual encoding
curl -s -H "Authorization: Basic $(echo -n 'admin:secret123' | base64)" \
  https://api.example.com/v1/resources
```

```text
WARNING: base64 is encoding, NOT encryption
  echo -n 'admin:secret123' | base64    --> YWRtaW46c2VjcmV0MTIz
  echo 'YWRtaW46c2VjcmV0MTIz' | base64 -d  --> admin:secret123
  Always use HTTPS with basic auth.
```

Related notes: [001-rest-concepts](./001-rest-concepts.md)

### Cloud Provider Auth

- Each cloud provider has its own authentication mechanism, but patterns are similar.

```text
AWS:
  - Access Key ID + Secret Access Key (long-lived, avoid in production)
  - STS (Security Token Service) for temporary credentials
  - IAM roles for EC2/Lambda/ECS (no keys needed, best practice)
  - Request signing: AWS Signature V4 (HMAC-based)

Azure:
  - Service Principal (client_id + client_secret + tenant_id)
  - Managed Identity (no secrets, attached to Azure resources)
  - Uses OAuth 2.0 client credentials against Azure AD
  - az cli handles token management automatically

GCP:
  - Service Account Key (JSON file, long-lived, avoid if possible)
  - Workload Identity (no keys, best practice for GKE)
  - Application Default Credentials (ADC) -- checks env, metadata, key file
  - gcloud auth handles token management automatically
```

```bash
# AWS -- use environment variables (never hardcode)
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="wJalr..."
aws s3 ls

# AWS -- assume a role for temporary credentials
aws sts assume-role --role-arn arn:aws:iam::123456:role/MyRole \
  --role-session-name my-session

# Azure -- authenticate as service principal
az login --service-principal \
  -u "$CLIENT_ID" -p "$CLIENT_SECRET" --tenant "$TENANT_ID"

# GCP -- activate service account
gcloud auth activate-service-account --key-file=sa-key.json

# verify current identity in each cloud
aws sts get-caller-identity          # AWS
az account show                      # Azure
gcloud auth list                     # GCP
```

Related notes: [000-core](./000-core.md)

### Best Practices
```text
Credential hierarchy (most to least preferred):

  [1] Managed identity / workload identity  (no secrets at all)
  [2] Short-lived tokens via OAuth / STS    (auto-expire)
  [3] API keys stored in secret manager     (encrypted, audited)
  [4] API keys in environment variables     (better than code)
  [5] Hardcoded credentials in code         (NEVER do this)
```

Related notes: [000-core](./000-core.md)
- **Never hardcode credentials** in source code, config files, or container images.
- **Use environment variables** or secret management tools (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault).
- **Rotate keys regularly** -- automate rotation where possible.
- **Use short-lived tokens** over long-lived API keys when available.
- **Apply least privilege** -- request only the scopes/permissions needed.
- **Use managed identities** (AWS IAM roles, Azure Managed Identity, GCP Workload Identity) to avoid keys entirely.

# Troubleshooting Guide

```text
Problem: API returns 401 Unauthorized or 403 Forbidden
    |
    v
[1] Is the credential present in the request?
    curl -v ... (check outgoing Authorization header)
    |
    +-- missing --> set the header or env var
    |
    v
[2] Is the credential valid?
    - API key: not revoked, not expired?
    - Token: not expired? (decode JWT, check exp claim)
    - Basic auth: correct username/password?
    |
    +-- expired --> refresh token or generate new key
    |
    v
[3] 401 vs 403?
    - 401 = identity not verified (wrong or missing credentials)
    - 403 = identity verified but lacks permission (scope/role issue)
    |
    +-- 403 --> check scopes, roles, or policies
    |
    v
[4] Is the credential for the right environment?
    - Staging key used against production?
    - Wrong tenant/project/account?
    |
    v
[5] Check API documentation for required auth method
    Some endpoints require specific auth (e.g., OAuth only, no API keys)
```
