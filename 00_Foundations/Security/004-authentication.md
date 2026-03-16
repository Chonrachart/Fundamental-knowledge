# Authentication

- Verifies identity: answers "Who are you?" before any access decision is made
- Works by validating a credential (password, key, token) against a trusted store or cryptographic proof
- Must occur before authorization; without confirmed identity, permissions cannot be enforced

# Architecture

```text
+----------+       credential        +-----------------+
|  Client  | ----------------------> | Auth Provider   |
| (user /  |                         | (IdP, SSH, DB)  |
|  app)    | <---------------------- |                 |
+----------+   accept / reject      +-----------------+
                                           |
                                     stores / verifies
                                           |
                                    +-------------+
                                    | Credential  |
                                    | Store       |
                                    | (hashes,    |
                                    |  keys, JWK) |
                                    +-------------+
```

# Mental Model

```text
1. Client presents credential (password, signed challenge, token)
2. Auth provider looks up expected value (hash, public key, signing key)
3. Provider compares / verifies cryptographic proof
4. Result: authenticated identity or rejection
```

Example -- SSH public key login:

```bash
# Client signs a challenge with private key
ssh -i ~/.ssh/id_rsa user@server

# Server verifies signature using ~/.ssh/authorized_keys (public key)
# If valid -> session authenticated as "user"
```

# Core Building Blocks

### Password Authentication

- Secret known only to user and system
- Stored as hash (with salt); never plaintext
- Weaknesses: weak passwords, reuse, phishing
- Mitigated with MFA (multi-factor authentication) -- combines something you know + something you have/are

Related notes: [hashing](./002-hashing.md), [secrets-management](./006-secrets-management.md)

### Public Key Authentication

- Uses asymmetric key pair instead of password
- Client sends proof of private key (e.g. signed challenge); server verifies with public key
- Used in SSH: `~/.ssh/id_rsa` (private), `~/.ssh/id_rsa.pub` (public)
- Stronger than password; no shared secret transmitted over network

Related notes: [symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Token-Based Authentication

- Token is a credential that represents an authenticated session or permission
- Types: session token, API token, bearer token
- Short-lived tokens reduce risk if stolen
- Commonly sent via `Authorization: Bearer <token>` header

Related notes: [secrets-management](./006-secrets-management.md)

### OAuth 2.0

- Protocol for delegated authorization; "log in with Google" etc.
- Allows app to access user's resources on another service without sharing password
- Flow: user authorizes -> app receives access token -> app uses token to call API

**Roles:**

- **Resource owner**: the user
- **Client**: application requesting access
- **Authorization server**: issues tokens (e.g. Google, GitHub)
- **Resource server**: holds the data (e.g. Gmail API)

**Authorization Code Flow:**

```text
User -> Client -> Authorization server (login + consent)
Client <- Authorization code <- Authorization server
Client -> Token request (code + client secret) -> Authorization server
Client <- Access token <- Authorization server
Client -> API call (Bearer token) -> Resource server
```

Related notes: [authorization](./005-authorization.md)

### JWT (JSON Web Token)

- Compact token format: `header.payload.signature`
- Payload contains claims (e.g. user ID, roles, expiry)
- Signed (HMAC or RSA) so recipient can verify integrity without calling the issuer

**Structure:**

- **Header**: algorithm (`alg`), type (`typ: JWT`)
- **Payload**: claims (`sub`, `exp`, `iat`, custom claims like roles)
- **Signature**: ensures payload has not been tampered with

**Use cases:**

- Stateless sessions; server does not store session state
- API authentication; client sends JWT in `Authorization: Bearer <token>`
- Cross-service identity propagation (e.g. microservices)

**Security rules:**

- Validate signature on every request; use HTTPS
- Keep payload small; do not store secrets in claims
- Short expiry (`exp`); use refresh tokens for long-lived access

Related notes: [cryptography](./001-cryptography.md), [hashing](./002-hashing.md)

---

# Troubleshooting Flow (Quick)

```text
Login fails
  |-> Wrong credentials? -> verify password / key path / token value
  |-> Key mismatch? -> compare public key on server vs local private key
  |-> Token expired? -> check exp claim / refresh token flow
  |-> MFA failure? -> verify TOTP clock sync / backup codes
  |-> OAuth error? -> check redirect_uri, client_id, scopes, grant_type
```

# Quick Facts (Revision)

- Authentication = identity ("who"); authorization = permissions ("what") -- authn always first
- Passwords must be hashed + salted; never stored in plaintext
- Public key auth transmits no secret -- client proves possession of private key
- OAuth 2.0 separates resource owner, client, auth server, and resource server
- JWT is stateless: `header.payload.signature`, signed with HMAC or RSA
- Short-lived tokens + refresh tokens balance security and usability
- MFA adds a second factor (TOTP, hardware key, biometric) on top of passwords
- Always validate JWT signatures server-side; never trust claims without verification
