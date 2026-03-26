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

---

# Troubleshooting Guide

### Data exposed or leaked

1. Check whether encryption is applied at rest and in transit: `openssl s_client -connect host:443` for TLS verification.
2. Identify scope of exposure: review access logs and affected data stores.
3. If a key is compromised, rotate keys immediately and re-encrypt affected data.
4. Audit key management practices and revoke any leaked credentials.

### Unauthorized access detected

1. Check authentication mechanism: verify identity provider logs and token validity.
2. Review access logs for the unauthorized session: `journalctl -u sshd` or application auth logs.
3. If valid credentials were stolen, revoke the compromised credentials immediately.
4. Enforce MFA on all affected accounts and review authorization policies.

### Data tampered or integrity violation

1. Verify data integrity with hashes or signatures: `sha256sum <file>` against known-good values.
2. Check HMAC or digital signature validation on the affected data or messages.
3. If no integrity check exists, add HMAC or signing to the data pipeline.
4. Investigate the source and timeline of the tampering via audit logs.

### Service unavailable (availability issue)

1. Check system and service status: `systemctl status <service>`.
2. Review resource utilization: `top`, `free -h`, `df -h` for CPU, memory, and disk.
3. If DDoS is suspected, check traffic patterns: `ss -s` and firewall logs.
4. Apply rate limiting, enable CDN caching, or deploy WAF rules to mitigate.

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
