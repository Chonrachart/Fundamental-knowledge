password
public key auth
token
OAuth
JWT

---

# Authentication

- Verifies identity: "Who are you?"
- Must occur before authorization; system needs to know who is making the request.

# Password

- Secret known only to user and system.
- Stored as hash (with salt); never plaintext.
- Weaknesses: weak passwords, reuse, phishing; use MFA when possible.

# Public Key Authentication

- Uses asymmetric key pair instead of password.
- Client sends proof of private key (e.g. signed challenge); server verifies with public key.
- Used in SSH: `~/.ssh/id_rsa` (private), `~/.ssh/id_rsa.pub` (public).
- Stronger than password; no shared secret over network.

# Token

- Token is a credential that represents an authenticated session or permission.
- Types: session token, API token, bearer token.
- Short-lived tokens reduce risk if stolen.

# OAuth

- Protocol for delegated authorization; "log in with Google" etc.
- Allows app to access user's resources on another service without sharing password.
- Flow: user authorizes → app receives access token → app uses token to call API.

### OAuth Roles

- **Resource owner**: User.
- **Client**: Application requesting access.
- **Authorization server**: Issues tokens (e.g. Google, GitHub).
- **Resource server**: Holds the data (e.g. Gmail API).

### OAuth 2.0 Flow (Authorization Code)

```
User → Client → Authorization server (login)
Client ← Authorization code ← Authorization server
Client → Token request (code + client secret) → Authorization server
Client ← Access token ← Authorization server
Client → API call (Bearer token) → Resource server
```

# JWT (JSON Web Token)

- Compact token format: header.payload.signature.
- Payload contains claims (e.g. user ID, roles, expiry).
- Signed (HMAC or RSA) so recipient can verify integrity.

### Structure

- **Header**: Algorithm, type (JWT).
- **Payload**: Claims (sub, exp, iat, etc.).
- **Signature**: Ensures payload not tampered.

### Use Cases

- Stateless sessions; server does not store session.
- API authentication; client sends JWT in `Authorization: Bearer <token>`.
- Cross-service identity (e.g. microservices).

### Security Notes

- Validate signature; use HTTPS.
- Keep payload small; do not store secrets.
- Short expiry; use refresh tokens for long-lived access.