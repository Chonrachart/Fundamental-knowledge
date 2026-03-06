hash
one-way function
collision
salt

SHA256
bcrypt
argon2

---

# Hash

- A hash is a fixed-size output from a one-way function.
- Same input always produces same output.
- Small change in input produces completely different output (avalanche effect).

# One-Way Function

- Cannot be reversed; given a hash, you cannot recover the original input.
- Used for: integrity checks, password storage, digital signatures.
- Brute-force or dictionary attacks are the main ways to attack hashed passwords.

# Collision

- When two different inputs produce the same hash.
- Good hash functions make collisions computationally infeasible.
- MD5 and SHA-1 are deprecated due to practical collision attacks.

# Salt

- Random data added to input before hashing.
- Prevents rainbow table attacks; same password has different hashes per user.
- Salt is stored alongside the hash (e.g. in database).

```
Hash(password + salt) → stored_hash
```

# SHA-256

- Cryptographic hash function; 256-bit output.
- Part of SHA-2 family; widely used for integrity, certificates, Bitcoin.
- Fast; suitable for checksums, not for password storage (too fast = easy brute-force).

```bash
echo -n "hello" | sha256sum
```

# bcrypt

- Password hashing function; designed to be slow.
- Built-in salt; configurable cost factor (work factor).
- Resistant to brute-force; good for password storage.

### How It Works

- Cost factor increases iterations; slows down attacks.
- Automatically generates and embeds salt in the output.

# Argon2

- Modern password hashing; winner of Password Hashing Competition.
- Resistant to GPU and ASIC attacks; tunable memory and time.
- Prefer over bcrypt for new systems.

### Argon2 Variants

- **Argon2d**: Data-dependent; faster, less resistant to side-channel.
- **Argon2i**: Data-independent; better for passwords.
- **Argon2id**: Hybrid; recommended default.

# When to Use Which

| Use case           | Use                          |
| :----------------- | :--------------------------- |
| File integrity     | SHA-256                      |
| Password storage   | bcrypt, Argon2               |
| Digital signatures | SHA-256 (or SHA-384, SHA-512)|