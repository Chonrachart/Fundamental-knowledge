# Security Foundations

- Security protects systems and data through confidentiality, integrity, and availability (CIA Triad)
- Combines cryptographic primitives (encryption, hashing, signatures) with access control (authentication, authorization)
- Every security architecture layers these building blocks: prevent, detect, respond

# Architecture

```text
                        ┌───────────────────────────┐
                        │     Security Goals        │
                        │  Confidentiality          │
                        │  Integrity                │
                        │  Availability             │
                        └────────────┬──────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
     ┌────────▼────────┐   ┌────────▼─────────┐   ┌────────▼────────┐
     │   Cryptography  │   │  Access Control  │   │   Trust Chain   │
     │                 │   │                  │   │                 │
     │ - Encryption    │   │ - Authentication │   │ - Certificates  │
     │ - Hashing       │   │ - Authorization  │   │ - PKI / CA      │
     │ - Signatures    │   │ - RBAC / ABAC    │   │ - Digital Sigs  │
     └─────────────────┘   └─────────────────-┘   └─────────────────┘
```

# Mental Model

```text
Request arrives
  │
  ▼
Authentication ── "Who are you?" ── verify identity
  │
  ▼
Authorization ─── "What can you do?" ── check permissions
  │
  ▼
Encryption ────── protect data in transit / at rest
  │
  ▼
Integrity ─────── hash / sign to detect tampering
  │
  ▼
Audit ─────────── non-repudiation, logging
```

Example: HTTPS request flow

```text
Client ──TLS handshake──▶ Server
  1. Server presents certificate (trust chain)
  2. Client verifies CA signature (authentication)
  3. Diffie-Hellman key exchange (asymmetric → shared secret)
  4. Symmetric encryption for session data (confidentiality)
  5. HMAC on each record (integrity)
```

# Core Building Blocks

### CIA Triad

- **Confidentiality**: data is hidden from unauthorized parties
  - Achieved through encryption; only those with the key can read
- **Integrity**: data is not altered in transit or at rest
  - Achieved through hashing, digital signatures, HMAC
- **Availability**: systems and data are accessible when needed
  - Achieved through redundancy, backups, DDoS mitigation

Related notes: [001-cryptography](./001-cryptography.md), [002-hashing](./002-hashing.md)

### Authentication

- Verifies **who** you are
- Proves identity before granting access
- Methods: passwords, public keys, tokens, biometrics

Related notes: [004-authentication](./004-authentication.md)

### Authorization

- Determines **what** you can do after authentication
- Enforces permissions and access control
- Models: RBAC, ABAC, ACL

Related notes: [005-authorization](./005-authorization.md)

### Non-repudiation

- Prevents denial of an action (e.g. "I didn't send that")
- Achieved through digital signatures; only the holder of the private key could have signed
- Used in contracts, transactions, audit logs

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Encryption

- Converts plaintext to ciphertext so only authorized parties can read
- Uses a key; same key (symmetric) or key pair (asymmetric)
- Two categories: symmetric (fast, bulk data) and asymmetric (key exchange, signatures)

Related notes: [001-cryptography](./001-cryptography.md), [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Hashing

- One-way function; produces fixed-size output from any input
- Used for integrity (checksums), password storage (with salt)
- Not reversible; cannot get plaintext from hash

Related notes: [002-hashing](./002-hashing.md)

### Digital Signature

- Proves authenticity and integrity of a message
- Sender signs with private key; anyone can verify with public key
- Combines hashing (integrity) with asymmetric crypto (authenticity)

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md), [007-pki-and-certificates](./007-pki-and-certificates.md)

### Certificates

- Bind a public key to an identity (domain, person, org)
- Signed by a Certificate Authority (CA); trusted chain
- Used in TLS/HTTPS, code signing, email (S/MIME)

Related notes: [007-pki-and-certificates](./007-pki-and-certificates.md), [TLS and SSL cert chain](../03_Networking/009-tls-and-ssl-cert-chain.md)

### Multi-Factor Authentication (MFA)

- Requires two or more independent factors: something you know + something you have/are
- TOTP (time-based codes), WebAuthn (hardware keys), push notifications, SMS (weakest)
- Critical for all privileged access — admin accounts, VPN, cloud consoles

Related notes: [010-mfa](./010-mfa.md)

### Incident Response

- Structured process for handling security incidents: detect, contain, eradicate, recover, learn
- Follows NIST 6-phase lifecycle; evidence preservation throughout all phases
- Preparation (runbooks, tools, drills) determines how well you respond when it happens

Related notes: [011-incident-response](./011-incident-response.md)
# Topic Map

- [001-cryptography](./001-cryptography.md) — Encryption, decryption, keys, block cipher modes
- [002-hashing](./002-hashing.md) — Hash functions, salt, collision, bcrypt, Argon2
- [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md) — RSA, ECDSA, Diffie-Hellman, hybrid TLS
- [004-authentication](./004-authentication.md) — Passwords, tokens, OAuth, JWT
- [005-authorization](./005-authorization.md) — RBAC, ABAC, ACL
- [006-secrets-management](./006-secrets-management.md) — Vault, Kubernetes secrets
- [007-pki-and-certificates](./007-pki-and-certificates.md) — PKI, CSR, OpenSSL, cert formats, Let's Encrypt
- [008-linux-security-hardening](./008-linux-security-hardening.md) — SSH, SELinux/AppArmor, auditd, sysctl
- [009-network-security](./009-network-security.md) — Defense in depth, zero trust, IDS/IPS, segmentation
- [010-mfa](./010-mfa.md) — TOTP, WebAuthn/FIDO2, push, SMS, MFA attacks
- [011-incident-response](./011-incident-response.md) — IR phases, forensics, evidence preservation, post-mortem
