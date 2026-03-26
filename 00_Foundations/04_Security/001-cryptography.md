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

```bash
# Encrypt file with AES-256-CBC (symmetric)
openssl enc -aes-256-cbc -salt -in file.txt -out file.enc -pass pass:secret

# Encrypt with RSA public key (small data only — max keysize minus padding bytes)
openssl rsautl -encrypt -pubin -inkey public.pem -in msg.txt -out msg.enc
```

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Decryption

- Process of converting ciphertext back to plaintext using the key
- Symmetric: same key for encrypt and decrypt
- Asymmetric: private key decrypts what public key encrypted (or vice versa for signatures)

```bash
# Decrypt file with AES-256-CBC
openssl enc -d -aes-256-cbc -in file.enc -out file.txt -pass pass:secret
```

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Key

- Secret value used by the cryptographic algorithm
- Key strength (length) affects security; longer keys are harder to brute-force
- Key management: generation, storage, rotation, distribution

| Algorithm | Key Size | Relative Strength |
| :-------- | :------- | :---------------- |
| AES-128   | 128 bits | Strong            |
| AES-256   | 256 bits | Stronger          |

```bash
# Generate a random 256-bit key (hex)
openssl rand -hex 32

# Generate RSA key pair (4096-bit)
openssl genrsa -out private.pem 4096
openssl rsa -in private.pem -pubout -out public.pem
```

**Key types:**

- **Symmetric key**: one secret; shared between sender and receiver
- **Public key**: can be shared; used to encrypt or verify
- **Private key**: must be kept secret; used to decrypt or sign

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md), [006-secrets-management](./006-secrets-management.md)

### Modes of Operation (Block Ciphers)
```text
ECB (avoid):  P1──▶E──▶C1    P2──▶E──▶C2    (identical blocks = identical output)

CBC:          P1⊕IV──▶E──▶C1    P2⊕C1──▶E──▶C2    (chained)

GCM:          Counter──▶E──▶⊕P──▶C + Auth Tag    (encrypt + authenticate)
```

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)
- Block ciphers (e.g. AES) encrypt fixed-size blocks
- Modes define how multiple blocks are processed:
  - **ECB** (Electronic Codebook): each block independently -- weak; identical plaintext blocks produce identical ciphertext; avoid
  - **CBC** (Cipher Block Chaining): each block depends on previous; needs initialization vector (IV)
  - **GCM** (Galois/Counter Mode): authenticated encryption; provides confidentiality + integrity; preferred for modern use

# Troubleshooting Guide

### Decryption fails or produces garbage output
1. Verify the key matches: symmetric requires the same key; asymmetric requires the correct key pair.
2. Verify algorithm and mode match: encrypt and decrypt must use the same algorithm (e.g., AES-256-GCM on both sides).
3. Check the IV/nonce: CBC requires the same IV; GCM requires the same nonce. Mismatched IV = garbage output.
4. Check for corrupted ciphertext: use GCM (authenticated encryption) to detect tampering — it will fail with an auth error instead of producing garbage.

### Key-related issues
1. Key too short: use AES-256 (minimum AES-128); RSA minimum 2048-bit (prefer 4096).
2. Key not found: check file path and permissions: `ls -la /path/to/key.pem`.
3. Key format mismatch: ensure PEM vs DER format matches what the tool expects: `openssl rsa -in key.pem -check`.

### Performance issues with encryption
1. Symmetric encryption (AES) is fast — use it for bulk data.
2. Asymmetric encryption (RSA) is slow — use it only for key exchange or signing small data.
3. If encrypting large files with RSA: switch to hybrid approach (RSA encrypts an AES key, AES encrypts the data).
4. Use hardware acceleration if available: `openssl speed aes-256-gcm` to check throughput.
