# Hashing

- A hash function maps arbitrary-length input to a fixed-size output (digest) using a one-way function
- Same input always produces the same hash; a tiny change in input produces a completely different output (avalanche effect)
- Hashing is not encryption -- it is irreversible by design, used for integrity verification and password storage

# Architecture

```text
┌────────────────────────────────────────────────────────┐
│                   Hash Functions                       │
│                                                        │
│   Input (any size) ──▶ [ Hash Algorithm ] ──▶ Digest  │
│                          (fixed size)                  │
│                                                        │
│   ┌──────────────────┐    ┌──────────────────────┐     │
│   │  Fast Hashes     │    │  Slow Hashes         │     │
│   │  (integrity)     │    │  (password storage)  │     │
│   │                  │    │                      │     │
│   │  SHA-256         │    │  bcrypt              │     │
│   │  SHA-384         │    │  Argon2              │     │
│   │  SHA-512         │    │  scrypt              │     │
│   └──────────────────┘    └──────────────────────┘     │
│                                                        │
│   Deprecated: MD5, SHA-1 (collision attacks found)     │
└────────────────────────────────────────────────────────┘
```

# Mental Model

```text
Step 1: Take input data (file, password, message)
Step 2: Feed into hash function
Step 3: Get fixed-size digest (e.g. 256 bits for SHA-256)
Step 4: Compare digests to verify integrity or authenticate

Key property: cannot go backwards (digest → input)
```

Example: verifying file integrity with SHA-256

```bash
# Generate hash of a file
sha256sum important-file.tar.gz
# Output: a1b2c3d4...  important-file.tar.gz

# Verify against known hash
echo "a1b2c3d4...  important-file.tar.gz" | sha256sum --check
# Output: important-file.tar.gz: OK
```

# Core Building Blocks

### Hash Properties

- **Deterministic**: same input always produces same output
- **Fixed size**: output length is constant regardless of input size
- **Avalanche effect**: small change in input produces completely different output
- **One-way**: given a hash, you cannot recover the original input
- **Collision resistant**: computationally infeasible to find two inputs with same hash
- Brute-force or dictionary attacks are the main ways to attack hashed passwords

Related notes: [001-cryptography](./001-cryptography.md)

### Collision

- When two different inputs produce the same hash
- Good hash functions make collisions computationally infeasible
- MD5 and SHA-1 are deprecated due to practical collision attacks
- SHA-256 and SHA-3 have no known practical collisions

Related notes: [001-cryptography](./001-cryptography.md)

### Salt

- Random data added to input before hashing
- Prevents rainbow table attacks; same password has different hashes per user
- Salt is stored alongside the hash (e.g. in database)
- Each user should have a unique salt

```text
Without salt:  Hash("password123") → always same digest (rainbow table vulnerable)

With salt:     Hash("password123" + "x9f2k") → unique digest per user
               Salt "x9f2k" stored alongside hash
```

Related notes: [004-authentication](./004-authentication.md)

### SHA-256

- Cryptographic hash function; 256-bit (32-byte) output
- Part of SHA-2 family; widely used for integrity checks, certificates, blockchain
- Fast; suitable for checksums but not for password storage (too fast = easy brute-force)

```bash
echo -n "hello" | sha256sum
# 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
```

Related notes: [001-cryptography](./001-cryptography.md), [007-pki-and-certificates](./007-pki-and-certificates.md)

### bcrypt

- Password hashing function; designed to be intentionally slow
- Built-in salt; configurable cost factor (work factor)
- Resistant to brute-force; good default for password storage
- Cost factor increases iterations exponentially; slows down attacks
- Automatically generates and embeds salt in the output string

```text
bcrypt output format:
$2b$12$salt22characters.hash31characters
 │   │   │                 └─ hash
 │   │   └─ embedded salt
 │   └─ cost factor (2^12 = 4096 iterations)
 └─ algorithm version
```

Related notes: [004-authentication](./004-authentication.md)

### Argon2

- Modern password hashing; winner of the Password Hashing Competition (2015)
- Resistant to GPU and ASIC attacks; tunable memory, time, and parallelism
- Prefer over bcrypt for new systems

**Variants:**

- **Argon2d**: data-dependent memory access; faster, less resistant to side-channel attacks
- **Argon2i**: data-independent memory access; better side-channel resistance, suitable for passwords
- **Argon2id**: hybrid of d and i; recommended default for most use cases

Related notes: [004-authentication](./004-authentication.md)

### When to Use Which

| Use Case           | Recommended              | Why                                  |
| :----------------- | :----------------------- | :----------------------------------- |
| File integrity     | SHA-256                  | Fast, collision-resistant            |
| Password storage   | Argon2id (or bcrypt)     | Intentionally slow, salted           |
| Digital signatures  | SHA-256 / SHA-384        | Fast hash + asymmetric signing       |
| HMAC               | SHA-256                  | Keyed hash for message authentication|

Related notes: [001-cryptography](./001-cryptography.md), [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

---

# Practical Command Set (Core)

```bash
# SHA-256 hash of a string
echo -n "hello" | sha256sum

# SHA-256 hash of a file
sha256sum myfile.tar.gz

# Verify checksums from a file
sha256sum --check checksums.txt

# Generate MD5 (legacy, not for security)
md5sum myfile.tar.gz

# Hash a password with openssl (SHA-512 with salt)
openssl passwd -6 -salt randomsalt "mypassword"
```

Note: for password storage in applications, use bcrypt or Argon2 libraries, not command-line SHA.

# Troubleshooting Guide

```text
Hash mismatch?
  │
  ├─ File corrupted in transit? ──▶ Re-download + re-check sha256sum
  │
  ├─ Wrong algorithm? ──▶ Ensure sender and verifier use same hash function
  │
  ├─ Encoding issue? ──▶ Check for trailing newline (echo vs echo -n)
  │
  ├─ Passwords not matching? ──▶ Verify salt is stored and applied correctly
  │
  └─ Using MD5/SHA-1? ──▶ Upgrade to SHA-256 or SHA-3 (deprecated for security)
```

# Quick Facts (Revision)

- Hash = fixed-size, one-way, deterministic digest of any input
- Avalanche effect: 1-bit input change flips ~50% of output bits
- MD5 and SHA-1 are broken (practical collision attacks); use SHA-256+
- Salt = random data prepended/appended to input before hashing; defeats rainbow tables
- bcrypt: slow by design, built-in salt, cost factor controls speed
- Argon2id: modern default for password hashing; resists GPU/ASIC attacks
- Fast hashes (SHA-256) for integrity; slow hashes (bcrypt/Argon2) for passwords
- HMAC = keyed hash; provides both integrity and authentication
