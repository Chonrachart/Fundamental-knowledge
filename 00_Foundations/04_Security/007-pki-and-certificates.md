# PKI and Certificates

- PKI (Public Key Infrastructure) is a framework of policies, roles, hardware, and software for creating, managing, distributing, and revoking digital certificates
- It binds public keys to identities via a Certificate Authority (CA) that digitally signs certificates, enabling trust chains
- Certificates are the foundation of TLS/SSL, code signing, email encryption (S/MIME), and mutual authentication

## Architecture

```text
                          ┌──────────────┐
                          │   Root CA    │  (offline, air-gapped)
                          │  self-signed │
                          └──────┬───────┘
                                 │ signs
                    ┌────────────┴────────────┐
                    │                         │
             ┌──────┴───────┐          ┌──────┴───────┐
             │ Intermediate │          │ Intermediate │
             │    CA #1     │          │    CA #2     │
             └──────┬───────┘          └──────────────┘
                    │ signs
         ┌──────────┼──────────┐
         │          │          │
    ┌────┴────┐ ┌───┴────┐ ┌──┴──────┐
    │ Server  │ │ Client │ │ Server  │
    │ Cert A  │ │ Cert   │ │ Cert B  │
    └─────────┘ └────────┘ └─────────┘

    ┌─────────────────────────────────────┐
    │         Supporting Services         │
    │                                     │
    │  RA ─── Registration Authority      │
    │         (verifies identity before   │
    │          CA signs)                  │
    │                                     │
    │  CRL ── Certificate Revocation List │
    │         (periodic list of revoked)  │
    │                                     │
    │  OCSP ─ Online Certificate Status   │
    │         Protocol (real-time check)  │
    │                                     │
    │  Cert Store ── local trust store    │
    │         (/etc/ssl/certs, keystore)  │
    └─────────────────────────────────────┘
```

## Mental Model

```text
  Key Pair       CSR            CA Signs         Deploy         Renew/Revoke
  Generation     Creation       Certificate      Certificate    Lifecycle
  ─────────► ──────────► ──────────────► ──────────────► ──────────────►

  1. Generate    2. Create CSR   3. CA validates  4. Install     5. Monitor
     RSA/EC         (includes      identity &       cert+key       expiry,
     key pair       public key     signs cert       on server      renew or
                    + subject)                                     revoke
```

Example: generate a key pair, create CSR, and get a self-signed certificate.

```bash
# 1. Generate private key (RSA 2048-bit)
openssl genrsa -out server.key 2048

# 2. Create CSR from the key
openssl req -new -key server.key -out server.csr \
  -subj "/C=US/ST=State/L=City/O=Org/CN=example.com"

# 3. Self-sign (acts as your own CA) — for dev/testing only
openssl req -x509 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj "/CN=example.com"
```

## Core Building Blocks

### PKI Components

- **Certificate Authority (CA)** — trusted entity that issues and signs certificates
  - Root CA: top of the chain, self-signed, kept offline
  - Intermediate CA: signed by root, issues end-entity certs (limits root exposure)
- **Registration Authority (RA)** — verifies the identity of certificate requestors before CA signs
- **Certificate Store** — local repository of trusted CA certs
  - Linux: `/etc/ssl/certs/`, `/etc/pki/tls/certs/`
  - Java: `$JAVA_HOME/lib/security/cacerts`
  - Update: `update-ca-certificates` (Debian) or `update-ca-trust` (RHEL)
- **CRL (Certificate Revocation List)** — periodic list of revoked certificate serial numbers, downloaded by clients
- **OCSP (Online Certificate Status Protocol)** — real-time single-certificate revocation check; OCSP stapling lets the server fetch and cache the response

Related notes: [001-cryptography](./001-cryptography.md), [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### Certificate Lifecycle

- **Generate key pair** — private key stays on the server, never leaves
- **Create CSR** — contains public key, subject (CN, O, etc.), and requested SANs
- **CA signs** — CA verifies identity, issues certificate with validity period and serial number
- **Deploy** — install cert + key on the server, configure the service (Nginx, Apache, etc.)
- **Monitor** — track expiry dates, set alerts (e.g., 30 days before expiry)
- **Renew** — generate new CSR or use ACME for automated renewal
- **Revoke** — notify CA to add serial to CRL / OCSP; reasons include key compromise, change of affiliation

Related notes: [TLS and SSL cert chain](../03_Networking/006-TLS-and-SSL-cert-chain.md)

### Certificate Formats

| Format | Extension | Encoding | Contains | Common Use |
|--------|-----------|----------|----------|------------|
| PEM | `.pem`, `.crt`, `.key` | Base64 (ASCII) | Cert and/or key | Linux, Apache, Nginx |
| DER | `.der`, `.cer` | Binary | Single cert | Java, Windows |
| PKCS#12 | `.p12`, `.pfx` | Binary | Cert + key + chain | Windows, Java keystore import |
| PKCS#7 | `.p7b`, `.p7c` | Base64 | Cert chain (no key) | Windows, Java |

- PEM files have `-----BEGIN CERTIFICATE-----` / `-----BEGIN PRIVATE KEY-----` headers
- A PEM file can contain multiple certs concatenated (cert chain bundle)

Related notes: [001-cryptography](./001-cryptography.md)

### Let's Encrypt and ACME Protocol

- **ACME** (Automatic Certificate Management Environment) — protocol for automated certificate issuance and renewal
- **Let's Encrypt** — free, automated CA using ACME; issues DV (Domain Validation) certs only
- **Challenge types**:
  - `HTTP-01` — place a file at `http://domain/.well-known/acme-challenge/TOKEN`
  - `DNS-01` — create a `_acme-challenge.domain` TXT record (supports wildcards)
  - `TLS-ALPN-01` — respond on port 443 with a special self-signed cert
- Certbot automates the entire flow: request, validate, install, renew

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain cert with Nginx plugin
sudo certbot --nginx -d example.com -d www.example.com

# Obtain cert with DNS challenge (for wildcards)
sudo certbot certonly --manual --preferred-challenges dns \
  -d "*.example.com"

# Dry-run renewal test
sudo certbot renew --dry-run

# Certs stored at: /etc/letsencrypt/live/example.com/
#   fullchain.pem  — cert + intermediate
#   privkey.pem    — private key
#   chain.pem      — intermediate only
```

Related notes: [TLS and SSL cert chain](../03_Networking/006-TLS-and-SSL-cert-chain.md)

### Certificate Pinning

- Binds a specific certificate or public key to a host, rejecting any other valid cert for that domain
- Protects against rogue CA compromise or mis-issuance
- **HPKP** (HTTP Public Key Pinning) — deprecated due to risk of bricking sites
- Modern approach: pin in application code or use Certificate Transparency (CT) logs for monitoring
- CT logs are append-only public logs of all issued certificates; monitors watch for unauthorized issuance

Related notes: [003-symmetric-vs-asymmetric](./003-symmetric-vs-asymmetric.md)

### mTLS (Mutual TLS)

- Standard TLS: only the server presents a certificate; client verifies server identity
- mTLS: both client AND server present certificates; both sides verify each other
- Use cases: service-to-service auth (service mesh), API security, zero-trust networks

```text
  Client                              Server
    │                                    │
    │ ──── ClientHello ────────────────► │
    │ ◄─── ServerHello + ServerCert ──── │
    │ ◄─── CertificateRequest ────────── │  ← server asks for client cert
    │ ──── ClientCert + ClientKeyExch ─► │  ← client sends its cert
    │                                    │
    │   Both sides verify each other's   │
    │   certificate against trusted CA   │
    │                                    │
    │ ◄════ Encrypted channel ══════════►│
```

- In Nginx, enable with:
  - `ssl_client_certificate /path/to/ca.pem;`
  - `ssl_verify_client on;`

Related notes: [TLS and SSL cert chain](../03_Networking/006-TLS-and-SSL-cert-chain.md), [004-authentication](./004-authentication.md)

---

## Practical Command Set (Core)

```bash
# --- Key and CSR generation ---
openssl genrsa -out server.key 2048                          # RSA 2048 private key
openssl ecparam -genkey -name prime256v1 -out server-ec.key  # EC P-256 private key
openssl req -new -key server.key -out server.csr             # create CSR interactively
openssl req -new -key server.key -out server.csr \
  -subj "/CN=example.com/O=MyOrg"                           # create CSR non-interactively

# --- Self-signed certificate ---
openssl req -x509 -newkey rsa:2048 -keyout key.pem \
  -out cert.pem -days 365 -nodes                            # generate key + self-signed cert

# --- Inspect certificates ---
openssl x509 -in cert.pem -text -noout                      # view cert details
openssl x509 -in cert.pem -noout -dates                     # check validity dates
openssl x509 -in cert.pem -noout -subject -issuer           # subject and issuer
openssl req -in server.csr -text -noout                     # view CSR details
openssl s_client -connect example.com:443 -showcerts        # fetch remote cert chain

# --- Verify ---
openssl verify -CAfile ca.pem cert.pem                      # verify cert against CA
openssl verify -CAfile ca.pem -untrusted intermediate.pem cert.pem  # with intermediate

# --- Format conversion ---
openssl pkcs12 -export -out cert.pfx \
  -inkey key.pem -in cert.pem                               # PEM → PKCS12
openssl pkcs12 -in cert.pfx -out cert.pem -nodes            # PKCS12 → PEM
openssl x509 -in cert.pem -outform der -out cert.der        # PEM → DER
openssl x509 -in cert.der -inform der -out cert.pem         # DER → PEM

# --- Check key/cert match ---
openssl x509 -noout -modulus -in cert.pem | openssl md5     # cert modulus hash
openssl rsa -noout -modulus -in key.pem | openssl md5       # key modulus hash
# Both md5 outputs must match
```

Note: always use `-nodes` (no DES) in dev/test to skip passphrase; in production, protect private keys with passphrases or HSMs.

## Troubleshooting Guide

```text
  Certificate error?
    │
    ├─ "certificate has expired"
    │    └─► check dates: openssl x509 -in cert.pem -noout -dates
    │         └─► renew cert (certbot renew / request new from CA)
    │
    ├─ "unable to get local issuer certificate"
    │    └─► missing intermediate cert in chain
    │         └─► append intermediate to cert bundle (fullchain.pem)
    │              └─► verify: openssl verify -CAfile ca.pem -untrusted inter.pem cert.pem
    │
    ├─ "certificate signature failure"
    │    └─► cert was not signed by the CA you think
    │         └─► check issuer: openssl x509 -in cert.pem -noout -issuer
    │              └─► ensure correct CA cert in trust store
    │
    ├─ "key does not match certificate"
    │    └─► compare modulus hashes of key and cert (see commands above)
    │         └─► regenerate CSR with the correct key
    │
    └─ "certificate revoked"
         └─► cert is on CRL or OCSP returns "revoked"
              └─► request new certificate from CA
```

## Quick Facts (Revision)

- A certificate binds a public key to an identity; the CA's signature is the proof of that binding
- Root CAs are self-signed and kept offline; intermediate CAs handle day-to-day issuance
- CSR contains the public key + subject info; the private key never leaves the server
- PEM is Base64-encoded ASCII (most common on Linux); PKCS#12 bundles key + cert in binary (common for import/export)
- Let's Encrypt certs are valid for 90 days; certbot auto-renews via systemd timer or cron
- OCSP stapling is preferred over CRL because it is real-time and reduces CA load
- mTLS requires both client and server to present and verify certificates — used heavily in service meshes (Istio, Linkerd)
- Certificate Transparency (CT) logs provide public auditability of all issued certificates
