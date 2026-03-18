# Symmetric vs Asymmetric Encryption

- Symmetric encryption uses one shared key for both encrypt and decrypt; fast, used for bulk data
- Asymmetric encryption uses a key pair (public + private); slower, used for key exchange and digital signatures
- Modern protocols (TLS) combine both: asymmetric for handshake, symmetric for session data (hybrid encryption)

# Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    Encryption Types                          │
│                                                             │
│  ┌──────────────────────┐    ┌────────────────────────────┐ │
│  │     Symmetric        │    │       Asymmetric           │ │
│  │                      │    │                            │ │
│  │  Key: shared secret  │    │  Keys: public + private    │ │
│  │  Speed: fast         │    │  Speed: slower             │ │
│  │  Use: bulk data      │    │  Use: key exchange, sigs   │ │
│  │                      │    │                            │ │
│  │  AES, ChaCha20       │    │  RSA, ECDSA, DH/ECDH      │ │
│  └──────────┬───────────┘    └──────────┬─────────────────┘ │
│             │                           │                   │
│             └──────────┬────────────────┘                   │
│                        ▼                                    │
│               ┌────────────────┐                            │
│               │  Hybrid (TLS)  │                            │
│               │  Asymmetric →  │                            │
│               │  key exchange  │                            │
│               │  Symmetric →   │                            │
│               │  session data  │                            │
│               └────────────────┘                            │
└─────────────────────────────────────────────────────────────┘
```

# Mental Model

```text
Symmetric:
  Alice ──shared key──▶ Bob
  Both use SAME key to encrypt and decrypt
  Problem: how to share the key securely?

Asymmetric:
  Alice ──Bob's public key──▶ encrypt
  Bob ──Bob's private key──▶ decrypt
  No shared secret needed; private key never leaves owner

Hybrid (TLS):
  Step 1: Asymmetric handshake (authenticate + exchange key)
  Step 2: Derive shared symmetric key
  Step 3: Symmetric encryption for all session data
```

Example: TLS 1.3 simplified handshake

```text
Client                              Server
  │                                    │
  │──── ClientHello + ECDH share ────▶│
  │                                    │
  │◀─── ServerHello + ECDH share ─────│
  │     + Certificate + Verify         │
  │                                    │
  │  (both derive shared secret)       │
  │                                    │
  │◀════ Symmetric encrypted data ════▶│
```

# Core Building Blocks

### Symmetric Encryption

- One key for both encryption and decryption
- Fast; suitable for bulk data (TLS session data, file encryption, disk encryption)
- Challenge: key distribution; both parties must share the secret securely
- Examples: AES (Advanced Encryption Standard), ChaCha20

Related notes: [001-cryptography](./001-cryptography.md)

### Asymmetric Encryption

- Key pair: public key (shared freely) and private key (kept secret)
- Public key encrypts; private key decrypts (or vice versa for signatures)
- No shared secret needed for encryption; private key never leaves owner
- Slower than symmetric; often used to exchange a symmetric key, then symmetric for data

Related notes: [001-cryptography](./001-cryptography.md), [007-pki-and-certificates](./007-pki-and-certificates.md)

### RSA

- Widely used asymmetric algorithm based on difficulty of factoring large numbers
- Key sizes: 2048, 4096 bits (1024 deprecated)
- Used for: TLS, digital signatures, encryption of small data (e.g. symmetric keys)
- Public key = (n, e); private key = (n, d)
- Encrypt with public key; decrypt with private key

Related notes: [007-pki-and-certificates](./007-pki-and-certificates.md)

### ECDSA

- Elliptic Curve Digital Signature Algorithm
- Smaller keys than RSA for equivalent security (256-bit EC ~ 3072-bit RSA)
- Used for: TLS, Bitcoin, code signing
- Shorter keys and faster operations with same security and less computational cost

Related notes: [007-pki-and-certificates](./007-pki-and-certificates.md)

### Diffie-Hellman (DH / ECDH)

- Key exchange protocol; allows two parties to establish a shared secret over an insecure channel
- Does not encrypt data; only agrees on a shared key
- Often combined with authentication (TLS uses DH or ECDH for key exchange)
- ECDH variant uses elliptic curves for better performance

```text
Diffie-Hellman Key Exchange:

Alice and Bob agree on public parameters (g, p)
  │
Alice: picks secret a ──▶ sends A = g^a mod p
Bob:   picks secret b ──▶ sends B = g^b mod p
  │
Alice computes: B^a mod p = g^(ab) mod p  ──┐
Bob   computes: A^b mod p = g^(ab) mod p  ──┤
                                             ▼
                              Shared secret: g^(ab) mod p
                              (eavesdropper sees A, B but cannot compute secret)
```

Related notes: [001-cryptography](./001-cryptography.md)

### Comparison Table

| Property             | Symmetric              | Asymmetric                |
| :------------------- | :--------------------- | :------------------------ |
| Keys                 | One shared key         | Key pair (public/private) |
| Speed                | Fast                   | Slower                    |
| Key distribution     | Hard (must share key)  | Easy (public key is open) |
| Primary use          | Bulk data encryption   | Key exchange, signatures  |
| Examples             | AES, ChaCha20          | RSA, ECDSA, DH            |
| Key size (equiv.)    | 128 / 256 bits         | 2048 / 4096 bits (RSA)    |

### Hybrid Use in TLS

1. **Asymmetric phase**: authenticate server (certificate), exchange shared secret (ECDH)
2. **Symmetric phase**: encrypt actual application data with the derived symmetric key
- This combines the security of asymmetric (no pre-shared secret needed) with the speed of symmetric

Related notes: [001-cryptography](./001-cryptography.md), [000-core](./000-core.md)

---

# Practical Command Set (Core)

```bash
# Generate RSA 4096-bit key pair
openssl genrsa -out rsa_private.pem 4096
openssl rsa -in rsa_private.pem -pubout -out rsa_public.pem

# Generate ECDSA key pair (P-256 curve)
openssl ecparam -genkey -name prime256v1 -out ec_private.pem
openssl ec -in ec_private.pem -pubout -out ec_public.pem

# Sign a file with RSA private key
openssl dgst -sha256 -sign rsa_private.pem -out file.sig file.txt

# Verify signature with RSA public key
openssl dgst -sha256 -verify rsa_public.pem -signature file.sig file.txt

# Encrypt file with AES-256 symmetric key
openssl enc -aes-256-cbc -salt -in data.txt -out data.enc -pass pass:secret
```

Note: in production, use proper key management; never pass passwords on the command line.

# Troubleshooting Guide

```text
Encryption/signing issue?
  │
  ├─ "wrong key" error? ──▶ Verify key pair matches (public ↔ private)
  │                         openssl rsa -in priv.pem -check
  │
  ├─ Signature invalid? ──▶ Ensure same hash algorithm on sign and verify
  │                         └─ Data modified after signing? ──▶ Re-sign
  │
  ├─ RSA "data too large"? ──▶ RSA encrypts max (keysize - padding) bytes
  │                             └─ Use hybrid: RSA wraps AES key, AES encrypts data
  │
  ├─ Key size too small? ──▶ RSA minimum 2048-bit; EC minimum 256-bit
  │
  └─ Performance slow? ──▶ Switch to ECDSA/ECDH (smaller keys, faster math)
                           └─ Use symmetric for bulk data, asymmetric only for handshake
```

# Quick Facts (Revision)

- Symmetric = 1 key, fast, bulk data; Asymmetric = key pair, slower, key exchange + signatures
- AES-256 and ChaCha20 are the standard symmetric ciphers today
- RSA security relies on factoring large primes; minimum 2048-bit keys
- ECDSA 256-bit provides equivalent security to RSA 3072-bit with smaller keys
- Diffie-Hellman enables shared secret over insecure channel without pre-sharing keys
- TLS uses hybrid: ECDH key exchange (asymmetric) then AES-GCM (symmetric) for session
- Never use RSA to encrypt bulk data directly; wrap a symmetric key instead
- Key distribution is the fundamental problem that asymmetric crypto solves
