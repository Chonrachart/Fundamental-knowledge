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
- Passwords must be hashed + salted; never stored in plaintext

### Public Key Authentication

- Uses asymmetric key pair instead of password
- Client sends proof of private key (e.g. signed challenge); server verifies with public key
- Used in SSH: `~/.ssh/id_rsa` (private), `~/.ssh/id_rsa.pub` (public)
- Stronger than password; no shared secret transmitted over network

Related notes: [symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)
- Cross-service identity propagation (e.g. microservices)
- Public key auth transmits no secret -- client proves possession of private key
- MFA adds a second factor (TOTP, hardware key, biometric) on top of passwords

### Token-Based Authentication

- Token is a credential that represents an authenticated session or permission
- Types: session token, API token, bearer token
- Short-lived tokens reduce risk if stolen
- Commonly sent via `Authorization: Bearer <token>` header

Related notes: [secrets-management](./006-secrets-management.md)
- Authentication = identity ("who"); authorization = permissions ("what") -- authn always first
- Short-lived tokens + refresh tokens balance security and usability

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
- Short expiry (`exp`); use refresh tokens for long-lived access
- OAuth 2.0 separates resource owner, client, auth server, and resource server

### JWT (JSON Web Token)

- Compact token format: `header.payload.signature` (Base64URL encoded, separated by dots).
- Signed (HMAC or RSA/ECDSA) so the recipient can verify integrity without calling the issuer.
- Stateless: server does not store session state — all information is in the token itself.

**Structure:**

```text
Header (algorithm + type):
  {"alg": "RS256", "typ": "JWT"}

Payload (claims):
  {
    "sub": "user123",       <-- subject (who the token represents)
    "iat": 1711411200,      <-- issued at (Unix timestamp)
    "exp": 1711414800,      <-- expiration (1 hour later)
    "nbf": 1711411200,      <-- not before (token not valid before this time)
    "aud": "api.example.com", <-- audience (intended recipient)
    "jti": "abc-123-def",   <-- JWT ID (unique identifier, prevents replay)
    "roles": ["admin"]      <-- custom claim
  }

Signature:
  HMAC-SHA256(base64(header) + "." + base64(payload), secret)
  OR
  RSA-SHA256(base64(header) + "." + base64(payload), private_key)
```

**JWT vs Session Cookies:**

| Property | JWT | Session Cookie |
|----------|-----|----------------|
| State | Stateless (self-contained) | Stateful (server stores session) |
| Storage | Client (localStorage or cookie) | Server (memory, DB, Redis) |
| Scalability | Easy (no shared state) | Harder (session store must be shared) |
| Revocation | Hard (valid until expiry) | Easy (delete server-side session) |
| Size | Larger (carries claims) | Small (just session ID) |
| Best for | APIs, microservices, SPAs | Traditional web apps |

**Token refresh pattern:**
- Access token: short-lived (15 min–1 hour) — used for API calls.
- Refresh token: long-lived (days–weeks) — used only to get a new access token.
- When access token expires, client sends refresh token to get a new access token without re-login.

**Common JWT vulnerabilities:**

| Vulnerability | What happens | Prevention |
|--------------|-------------|------------|
| `alg: none` | Attacker removes signature, server accepts unsigned token | Reject tokens with `alg: none`; whitelist allowed algorithms |
| Algorithm confusion | Server expects HMAC but attacker uses RSA public key as HMAC secret | Explicitly specify algorithm on verification, don't read from token header |
| Missing expiry validation | Expired tokens still accepted | Always validate `exp` claim server-side |
| Token in URL | Token logged in server access logs, browser history | Send tokens in `Authorization` header, never in query strings |
| Sensitive data in payload | JWT payload is Base64-encoded (NOT encrypted) — anyone can read it | Never put secrets, passwords, or PII in JWT claims |

```bash
# decode a JWT payload (not verified, just decoded)
echo "eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ1c2VyMTIzIn0.signature" | \
  cut -d. -f2 | base64 -d 2>/dev/null | python3 -m json.tool

# verify a JWT with a public key (using Python PyJWT)
python3 -c "
import jwt
token = 'your.jwt.token'
payload = jwt.decode(token, key=open('public.pem').read(), algorithms=['RS256'])
print(payload)
"
```

Related notes: [002-hashing](./002-hashing.md), [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Multi-Factor Authentication (MFA)

- Adds a second factor beyond passwords: TOTP codes, hardware security keys, push notifications.
- Critical for all privileged access — admin accounts, VPN, cloud consoles.
- WebAuthn/FIDO2 (hardware keys) is the strongest factor; SMS is the weakest.

Related notes: [010-mfa](./010-mfa.md)
