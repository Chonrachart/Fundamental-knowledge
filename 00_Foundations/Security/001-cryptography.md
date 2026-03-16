# Cryptography

- Cryptography transforms readable data (plaintext) into unreadable data (ciphertext) using algorithms and keys
- Encryption provides confidentiality; decryption restores the original data using the correct key
- Key strength (length and management) determines the practical security of any cryptographic system

# Architecture

```text
┌──────────────────────────────────────────────────────┐
│                  Cryptographic System                │
│                                                      │
│   Plaintext ──▶ [ Algorithm + Key ] ──▶ Ciphertext  │
│   Ciphertext ──▶ [ Algorithm + Key ] ──▶ Plaintext  │
│                                                      │
│   ┌──────────────┐  ┌─────────────┐  ┌────────────┐  │
│   │  Symmetric   │  │ Asymmetric  │  │   Hybrid   │  │
│   │  (1 key)     │  │ (key pair)  │  │ (both)     │  │
│   │  AES, ChaCha │  │ RSA, ECDSA  │  │ TLS, PGP   │  │
│   └──────────────┘  └─────────────┘  └────────────┘  │
│                                                      │
│   Block Cipher Modes: ECB │ CBC │ GCM                │
└──────────────────────────────────────────────────────┘
```

# Mental Model

```text
Step 1: Sender has plaintext data to protect
Step 2: Choose algorithm (AES, RSA) and generate key
Step 3: Encrypt: plaintext + key → ciphertext
Step 4: Transmit ciphertext (safe even if intercepted)
Step 5: Receiver decrypts: ciphertext + key → plaintext
```

Example: AES-256-GCM encryption with OpenSSL

```bash
# Encrypt a file with AES-256-GCM
openssl enc -aes-256-gcm -salt -in secret.txt -out secret.enc -pass pass:mypassword

# Decrypt
openssl enc -d -aes-256-gcm -in secret.enc -out secret.txt -pass pass:mypassword
```

# Core Building Blocks

### Plaintext and Ciphertext

- **Plaintext**: readable data before encryption (or after decryption)
- **Ciphertext**: encrypted data; unreadable without the key
- Encryption transforms plaintext to ciphertext; decryption reverses it

Related notes: [000-core](./000-core.md), [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Encryption

- Process of converting plaintext to ciphertext using an algorithm and a key
- Purpose: confidentiality; only parties with the key can read the data
- Two main types: symmetric (one key) and asymmetric (key pair)

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Decryption

- Process of converting ciphertext back to plaintext using the key
- Symmetric: same key for encrypt and decrypt
- Asymmetric: private key decrypts what public key encrypted (or vice versa for signatures)

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Key

- Secret value used by the cryptographic algorithm
- Key strength (length) affects security; longer keys are harder to brute-force
- Key management: generation, storage, rotation, distribution

| Algorithm | Key Size | Relative Strength |
| :-------- | :------- | :---------------- |
| AES-128   | 128 bits | Strong            |
| AES-256   | 256 bits | Stronger          |

**Key types:**

- **Symmetric key**: one secret; shared between sender and receiver
- **Public key**: can be shared; used to encrypt or verify
- **Private key**: must be kept secret; used to decrypt or sign

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md), [006-secrets-management](./006-secrets-management.md)

### Modes of Operation (Block Ciphers)

- Block ciphers (e.g. AES) encrypt fixed-size blocks
- Modes define how multiple blocks are processed:
  - **ECB** (Electronic Codebook): each block independently -- weak; identical plaintext blocks produce identical ciphertext; avoid
  - **CBC** (Cipher Block Chaining): each block depends on previous; needs initialization vector (IV)
  - **GCM** (Galois/Counter Mode): authenticated encryption; provides confidentiality + integrity; preferred for modern use

```text
ECB (avoid):  P1──▶E──▶C1    P2──▶E──▶C2    (identical blocks = identical output)

CBC:          P1⊕IV──▶E──▶C1    P2⊕C1──▶E──▶C2    (chained)

GCM:          Counter──▶E──▶⊕P──▶C + Auth Tag    (encrypt + authenticate)
```

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

---

# Practical Command Set (Core)

```bash
# Generate a random 256-bit key (hex)
openssl rand -hex 32

# Encrypt file with AES-256-CBC
openssl enc -aes-256-cbc -salt -in file.txt -out file.enc -pass pass:secret

# Decrypt file
openssl enc -d -aes-256-cbc -in file.enc -out file.txt -pass pass:secret

# Generate RSA key pair
openssl genrsa -out private.pem 4096
openssl rsa -in private.pem -pubout -out public.pem

# Encrypt with RSA public key (small data only)
openssl rsautl -encrypt -pubin -inkey public.pem -in msg.txt -out msg.enc
```

Note: RSA can only encrypt data smaller than the key size; use hybrid encryption for larger payloads.

# Troubleshooting Flow (Quick)

```text
Encryption not working?
  │
  ├─ Wrong key? ──▶ Verify key matches (symmetric: same key; asymmetric: correct pair)
  │
  ├─ Wrong algorithm/mode? ──▶ Ensure encrypt and decrypt use same algorithm + mode
  │
  ├─ Corrupted ciphertext? ──▶ Use GCM (authenticated) to detect tampering
  │
  ├─ Key too short? ──▶ Use AES-256 (minimum AES-128); RSA minimum 2048-bit
  │
  └─ Performance issue? ──▶ Use symmetric for bulk data; asymmetric only for key exchange
```

# Quick Facts (Revision)

- Plaintext = readable; ciphertext = encrypted; key = secret for the algorithm
- Symmetric: one key, fast, for bulk data (AES, ChaCha20)
- Asymmetric: key pair, slower, for key exchange and signatures (RSA, ECDSA)
- AES-128 is strong; AES-256 is stronger; both are considered secure today
- ECB mode is insecure (identical blocks); prefer GCM (authenticated encryption)
- Key management (generation, rotation, storage) is often the weakest link
- Hybrid encryption (asymmetric for key exchange + symmetric for data) is standard in TLS
