plaintext
ciphertext
encryption
decryption
key

---

# Plaintext and Ciphertext

- **Plaintext**: Readable data before encryption (or after decryption).
- **Ciphertext**: Encrypted data; unreadable without the key.
- Encryption transforms plaintext → ciphertext; decryption reverses it.

# Encryption

- Process of converting plaintext to ciphertext using an algorithm and a key.
- Purpose: confidentiality; only parties with the key can read the data.
- Two main types: symmetric (one key) and asymmetric (key pair).

# Decryption

- Process of converting ciphertext back to plaintext using the key.
- Symmetric: same key for encrypt and decrypt.
- Asymmetric: private key decrypts what public key encrypted (or vice versa for signatures).

# Key

- Secret value used by the cryptographic algorithm.
- Key strength (length) affects security; longer keys are harder to brute-force.
- Key management: generation, storage, rotation, distribution.

### Key Length (Symmetric)

| Algorithm | Key size | Relative strength |
| :-------- | :------- | :----------------- |
| AES-128   | 128 bits | Strong             |
| AES-256   | 256 bits | Stronger           |

### Key Types

- **Symmetric key**: One secret; shared between sender and receiver.
- **Public key**: Can be shared; used to encrypt or verify.
- **Private key**: Must be kept secret; used to decrypt or sign.

# Encryption Flow

```
Plaintext + Key → Encryption algorithm → Ciphertext
Ciphertext + Key → Decryption algorithm → Plaintext
```

# Modes of Operation (Block Ciphers)

- Block ciphers (e.g. AES) encrypt fixed-size blocks.
- Modes define how multiple blocks are processed:
  - **ECB**: Each block independently (weak; avoid).
  - **CBC**: Each block depends on previous; needs IV.
  - **GCM**: Authenticated encryption; provides confidentiality + integrity.