# SSL (Secure Sockets Layer)

- SSL is a cryptographic protocol used to secure communication between a client and a server over a network.
- It ensures that data transmitted between both parties is encrypted, authenticated, and protected from interception.
- Today, SSL is **technically replaced** by Transport Layer Security (TLS), but the term “SSL” is still commonly used to refer to HTTPS encryption.
- HTTPS protocol mean `HTTP over TLS`
- `Client ⇄ Encrypted SSL/TLS Tunnel ⇄ TCP ⇄ Server`
### SSL provides three main security properties:
- Encryption
  - Data is encrypted before transmission.
  - Prevents attackers from reading traffic.
- Authentication
  - Verifies the identity of the server using a digital certificate.
- Integrity
  - Ensures data is not modified during transmission.
### How SSL Works (Simplified Flow)

1. Client Hello
   - Browser contacts the server.
   - Sends supported TLS versions, cipher suites, and a random value.
2. Server Hello
   - The server selects a cipher suite.  
   - Server sends its SSL certificate.
3. Certificate Verification
   - Browser verifies the certificate authority.
4. Key Exchange
   - Client and server generate a shared session key.
5. Encrypted Communication
   - All data is encrypted using the session key.

# TLS (Transport Layer Security)

- TLS (Transport Layer Security) is a cryptographic protocol used to secure communication over a network.
- It is the modern replacement for SSL.
- TLS provides encryption, authentication, and integrity for data transmitted between a client and a server.
- TLS is used in many protocols such as HTTPS, SMTPS, FTPS, and LDAPS.
### Improvements Over SSL
- TLS improves security compared to SSL:
  - Stronger encryption algorithms remove weak algorithms send it via cipher suite
  - Improved handshake process
  - Better protection against known attacks
  - More secure key exchange mechanisms
### TLS Handshake (Simplified)

1. Client Hello
   - Client sends supported TLS versions and cipher suites.
2. Server Hello
   - Server selects TLS version and cipher suite.
3. Certificate Exchange
   - Server sends its TLS certificate.
4. Key Exchange
   - Both sides generate a shared session key.
5. Secure Communication
   - Data is encrypted using the session key.

# Certificate 
- A certificate (digital certificate) is a cryptographic document used to verify the identity of a server, user, or organization in a network.

### Purpose of a Certificate
- A certificate mainly provides authentication.
- When a client connects to a server:
    1. The server sends its certificate.
    2. The client verifies the certificate.
    3. If trusted, the connection continues using encryption.
### An SSL/TLS certificate contains:
  - Server public key
  - Domain name
  - Certificate authority signature
  - Expiration date


# Certificate Authority (CA)

- Certificates are issued by trusted organizations called Certificate Authorities (CA).
- The CA digitally signs the certificate, which proves the certificate is valid.
- Browsers and operating systems maintain a trusted CA store.
### Example certificate authorities:
  - Let's Encrypt
  - DigiCert
  - GlobalSign

# Certificate Chain

- A certificate chain is the hierarchical trust path used to verify a server certificate.
- It links the server certificate to a trusted root certificate authority (CA) through one or more intermediate certificates.
- `Server Certificate → Intermediate CA → Root CA(trusted by browser / OS)`
 
### Purpose of a Certificate Chain

- The certificate chain allows a client (browser or application) to verify that a certificate is trusted.
- The client usually **does not directly trust the server certificate**. Instead, it trusts root certificate authorities installed in the operating system or browser.
- The chain provides a path of trust from the server certificate to that root.

### Components of a Certificate Chain
1. Server Certificate

- The certificate installed on the server.
- Contains:
  - Domain name
  - Server public key
  - CA signature

2. Intermediate Certificate

- An intermediate CA is used by the root CA to issue certificates indirectly.
- Purpose:
  - Protect the root CA from direct exposure
  - Allow CA infrastructure scaling

3. Root Certificate
- The top-level trusted certificate authority.
- Root certificates are stored in:
  - Operating systems
  - Browsers
  - Trust stores
  
### Certificate Chain Verification (Simplified)
- When a browser connects to a server:
1. Server sends its server certificate.
2. Server also sends intermediate certificate(s).
3. Browser checks:
   - Server certificate signed by intermediate CA
   - Intermediate signed by root CA
4. Browser checks if the root CA exists in its trusted store.
5. If valid → connection trusted.