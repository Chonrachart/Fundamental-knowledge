# TLS, SSL, and Certificate Chain

- SSL/TLS are cryptographic protocols that secure communication between client and server, providing encryption, authentication, and integrity.
- TLS is the modern successor to SSL; the term "SSL" persists colloquially, but all current implementations use TLS (1.2 or 1.3).
- Certificates form a hierarchical trust chain (server cert -> intermediate CA -> root CA) that lets clients verify server identity.

# Architecture

```text
+--------+                              +--------+
| Client |  <== TLS Encrypted Tunnel ==>| Server |
+--------+                              +--------+
    |                                       |
    |  Verifies certificate chain:          |  Presents:
    |                                       |
    |  Root CA (in trust store)             |  Server Certificate
    |    |                                  |    + Intermediate Cert(s)
    |    v                                  |
    |  Intermediate CA                      |
    |    |                                  |
    |    v                                  |
    |  Server Certificate                   |
    |    (domain, public key, CA sig)       |
    |                                       |
    +---------------------------------------+

Protocol stack:
  Application Data (HTTP, SMTP, etc.)
        |
      TLS / SSL
        |
       TCP
        |
       IP
```

# Mental Model

```text
Client connects to https://example.com
  |
  v
1. TCP handshake (SYN / SYN-ACK / ACK)
  |
  v
2. Client Hello
   - sends supported TLS versions, cipher suites, random value
  |
  v
3. Server Hello
   - selects TLS version and cipher suite
   - sends server certificate + intermediate cert(s)
  |
  v
4. Certificate Verification (client-side)
   - server cert signed by intermediate CA?
   - intermediate signed by root CA?
   - root CA in local trust store?
   - domain matches CN/SAN?
   - cert not expired?
  |
  v
5. Key Exchange
   - client and server derive shared session key
   - (ECDHE in TLS 1.3 for forward secrecy)
  |
  v
6. Encrypted Communication
   - all data encrypted with symmetric session key
```

Example: inspecting a certificate chain:

```bash
openssl s_client -connect example.com:443 -showcerts </dev/null 2>/dev/null | \
  openssl x509 -noout -subject -issuer -dates

# subject=CN = example.com
# issuer=C = US, O = DigiCert Inc, CN = DigiCert SHA2 Extended Validation Server CA
# notBefore=Nov 28 00:00:00 2024 GMT
# notAfter=Dec  2 23:59:59 2025 GMT
```

# Core Building Blocks

### Three Security Properties

- **Encryption** -- data is encrypted before transmission; prevents eavesdropping
- **Authentication** -- server identity verified via digital certificate; prevents impersonation
- **Integrity** -- message authentication codes ensure data is not modified in transit

Related notes: [005-http-https](./005-http-https.md), [008-ipsec-vpn](./008-ipsec-vpn.md)

### SSL vs TLS

- SSL (Secure Sockets Layer) -- original protocol; all versions (SSLv2, SSLv3) are deprecated and insecure.
- TLS (Transport Layer Security) -- modern replacement; TLS 1.2 and 1.3 are current standards.
- HTTPS means "HTTP over TLS" (not "HTTP over SSL").
- TLS is used in many protocols: HTTPS, SMTPS, FTPS, LDAPS.

Improvements of TLS over SSL:
- Stronger encryption algorithms; weak ciphers removed
- Improved handshake process (TLS 1.3 is 1-RTT instead of 2-RTT)
- Better protection against known attacks (POODLE, BEAST, etc.)
- More secure key exchange mechanisms (forward secrecy with ECDHE)

Related notes: [005-http-https](./005-http-https.md)

### TLS Handshake

```text
Client                              Server
  |                                    |
  |--- Client Hello ------------------>|  (TLS versions, cipher suites, random)
  |                                    |
  |<-- Server Hello -------------------|  (selected version, cipher, random)
  |<-- Certificate --------------------|  (server cert + intermediates)
  |<-- Server Key Exchange ------------|  (ECDHE parameters)
  |                                    |
  |--- Client Key Exchange ----------->|  (client ECDHE parameters)
  |--- Change Cipher Spec ------------>|
  |--- Finished ---------------------->|
  |                                    |
  |<-- Change Cipher Spec -------------|
  |<-- Finished -----------------------|
  |                                    |
  |==== Encrypted application data ====|
```

- TLS 1.3 simplifies this to a single round trip (1-RTT).
- Session resumption can achieve 0-RTT in TLS 1.3.

Related notes: [005-http-https](./005-http-https.md)

### Certificates

- A digital certificate is a cryptographic document used to verify the identity of a server, user, or organization.
- When a client connects, the server sends its certificate; the client verifies it before proceeding.

An SSL/TLS certificate contains:
- **Server public key** -- used in key exchange
- **Domain name** -- CN (Common Name) or SAN (Subject Alternative Name)
- **Certificate Authority signature** -- proves the cert was issued by a trusted CA
- **Expiration date** -- cert is invalid after this date
- **Serial number** -- unique identifier

Related notes: [005-http-https](./005-http-https.md)

### Certificate Authority (CA)

- Certificates are issued by trusted organizations called Certificate Authorities.
- The CA digitally signs the certificate, proving it is valid.
- Browsers and operating systems maintain a built-in trusted CA store.

Example CAs:
- **Let's Encrypt** -- free, automated, widely used
- **DigiCert** -- commercial, enterprise
- **GlobalSign** -- commercial, enterprise

Related notes: [007-proxy-and-load-balancing](./007-proxy-and-load-balancing.md)

### Certificate Chain

- A certificate chain is the hierarchical trust path from server certificate to trusted root CA.
- The chain links through one or more intermediate certificates.

```text
Server Certificate          (issued by Intermediate CA)
       |
       v
Intermediate CA Certificate (issued by Root CA)
       |
       v
Root CA Certificate         (self-signed, in browser/OS trust store)
```

**Components:**

1. **Server Certificate** -- installed on the server; contains domain, public key, CA signature
2. **Intermediate Certificate** -- issued by root CA to delegate signing; protects root from direct exposure; enables CA infrastructure scaling
3. **Root Certificate** -- top-level trust anchor; stored in OS, browser, and application trust stores

**Chain Verification Process:**
1. Server sends its server certificate + intermediate certificate(s).
2. Client checks: server cert signed by intermediate CA?
3. Client checks: intermediate signed by root CA?
4. Client checks: root CA exists in local trusted store?
5. If all valid, connection is trusted.

Related notes: [005-http-https](./005-http-https.md)

---

# Practical Command Set (Core)

```bash
# View certificate details for a remote server
openssl s_client -connect example.com:443 </dev/null 2>/dev/null | \
  openssl x509 -noout -text

# Show certificate chain
openssl s_client -connect example.com:443 -showcerts </dev/null

# Check certificate expiration
openssl s_client -connect example.com:443 </dev/null 2>/dev/null | \
  openssl x509 -noout -dates

# Verify certificate chain against CA bundle
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt server.crt

# Check which TLS versions a server supports
nmap --script ssl-enum-ciphers -p 443 example.com

# Test TLS connection with specific version
openssl s_client -connect example.com:443 -tls1_2
openssl s_client -connect example.com:443 -tls1_3

# View local CA trust store (Debian/Ubuntu)
ls /etc/ssl/certs/
update-ca-certificates --fresh
```

# Troubleshooting Guide

```text
TLS connection failing?
  |
  +--> Certificate error?
  |       |
  |       +--> Expired? --> check dates: openssl x509 -noout -dates
  |       +--> Wrong domain? --> check CN/SAN: openssl x509 -noout -subject -ext subjectAltName
  |       +--> Untrusted CA? --> check chain: openssl s_client -showcerts
  |       +--> Missing intermediate? --> server must send full chain
  |
  +--> Handshake failure?
  |       |
  |       +--> Protocol mismatch? --> try -tls1_2 / -tls1_3 with openssl s_client
  |       +--> Cipher mismatch? --> check supported ciphers on both ends
  |
  +--> Connection refused on 443?
          |
          +--> Firewall blocking? --> check with telnet/nc to port 443
          +--> Service not listening? --> check server config (nginx/apache)
```

# Quick Facts (Revision)

- SSL is deprecated; TLS 1.2 and 1.3 are current standards.
- TLS provides three properties: encryption, authentication, integrity.
- TLS 1.3 handshake completes in 1 round trip (1-RTT); supports 0-RTT resumption.
- Certificate chain: Server Cert -> Intermediate CA -> Root CA (in trust store).
- The server must send its certificate and all intermediates; the root is already trusted locally.
- HTTPS = HTTP over TLS; uses port 443.
- Forward secrecy (ECDHE) ensures past sessions cannot be decrypted even if the server key is later compromised.
- Use `openssl s_client -connect host:443` to debug TLS issues from the command line.
