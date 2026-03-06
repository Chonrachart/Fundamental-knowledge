Symmetric
Asymmetric
RSA
ECDSA
Diffie-Hellman

---

# Symmetric Encryption

- One key for both encryption and decryption.
- Fast; suitable for bulk data (e.g. TLS session data, file encryption).
- Challenge: key distribution; both parties must share the secret securely.

### Examples

- AES (Advanced Encryption Standard)
- ChaCha20

# Asymmetric Encryption

- Key pair: public key (shared) and private key (secret).
- Public key encrypts; private key decrypts (or vice versa for signatures).
- No shared secret needed for encryption; private key never leaves owner.
- Slower than symmetric; often used to exchange a symmetric key, then use symmetric for data.

# RSA

- Widely used asymmetric algorithm.
- Key sizes: 2048, 4096 bits (1024 deprecated).
- Used for: TLS, digital signatures, encryption of small data (e.g. symmetric keys).

### How It Works

- Based on difficulty of factoring large numbers.
- Public key = (n, e); private key = (n, d).
- Encrypt with public; decrypt with private.

# ECDSA

- Elliptic Curve Digital Signature Algorithm.
- Smaller keys than RSA for same security (e.g. 256-bit EC ≈ 3072-bit RSA).
- Used for: TLS, Bitcoin, code signing.

### Benefits

- Shorter keys, faster operations.
- Same security with less computational cost.

# Diffie-Hellman

- Key exchange protocol; allows two parties to establish a shared secret over an insecure channel.
- No encryption of data; only agreement on a shared key.
- Often combined with authentication (e.g. TLS uses DH or ECDH for key exchange).

### Flow

```
Alice and Bob agree on public parameters (g, p)
Alice: a (secret) → sends g^a mod p
Bob: b (secret) → sends g^b mod p
Shared secret: g^(ab) mod p (both compute)
```

# Symmetric vs Asymmetric

| Symmetric           | Asymmetric                |
| :------------------- | :------------------------ |
| One key              | Key pair                 |
| Fast                 | Slower                   |
| Key distribution hard| Public key can be shared |
| Bulk data            | Key exchange, signatures |

# Typical Hybrid Use (e.g. TLS)

1. Asymmetric: authenticate server, exchange shared secret.
2. Symmetric: encrypt actual data with that secret.