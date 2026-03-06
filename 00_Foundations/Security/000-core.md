overview of

    Confidentiality
    Integrity
    Availability
    Authentication
    Authorization
    Non-repudiation
    Encryption
    Hashing
    Digital signature
    Certificates

---

# CIA Triad

- **Confidentiality**: Data is hidden from unauthorized parties.
  - Achieved through encryption; only those with the key can read.
- **Integrity**: Data is not altered in transit or at rest.
  - Achieved through hashing, digital signatures, HMAC.
- **Availability**: Systems and data are accessible when needed.
  - Achieved through redundancy, backups, DDoS mitigation.

# Authentication

- Verifies **who** you are.
- Proves identity before granting access.
- Methods: passwords, public keys, tokens, biometrics.
- See [004-authentication](./004-authentication.md).

# Authorization

- Determines **what** you can do after authentication.
- Enforces permissions and access control.
- Models: RBAC, ABAC, ACL.
- See [005-authorization](./005-authorization.md).

# Non-repudiation

- Prevents denial of an action (e.g. "I didn't send that").
- Achieved through digital signatures; only the holder of the private key could have signed.
- Used in contracts, transactions, audit logs.

# Encryption

- Converts plaintext to ciphertext so only authorized parties can read.
- Uses a key; same key (symmetric) or key pair (asymmetric).
- See [001-cryptography](./001-cryptography.md), [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md).

# Hashing

- One-way function; produces fixed-size output from any input.
- Used for integrity (checksums), password storage (with salt).
- Not reversible; cannot get plaintext from hash.
- See [002-hashing](./002-hashing.md).

# Digital Signature

- Proves authenticity and integrity of a message.
- Sender signs with private key; anyone can verify with public key.
- Combines hashing (integrity) with asymmetric crypto (authenticity).

# Certificates

- Bind a public key to an identity (domain, person, org).
- Signed by a Certificate Authority (CA); trusted chain.
- Used in TLS/HTTPS, code signing, email (S/MIME).
- See [06-TLS-and-SSL-cert-chain](../Networking/06-TLS-and-SSL-cert-chain.md).

# Topic Map

- [001-cryptography](./001-cryptography.md) — Encryption, decryption, keys
- [002-hashing](./002-hashing.md) — Hash functions, salt, collision
- [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md) — RSA, ECDSA, Diffie-Hellman
- [004-authentication](./004-authentication.md) — Passwords, tokens, OAuth, JWT
- [005-authorization](./005-authorization.md) — RBAC, ABAC, ACL
- [006-secrets-management](./006-secrets-management.md) — Vault, Kubernetes secrets