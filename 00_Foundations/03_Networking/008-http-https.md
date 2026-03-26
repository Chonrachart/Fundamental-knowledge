# HTTP and HTTPS

- HTTP is a stateless request-response protocol for web communication, running over TCP on port 80.
- HTTPS wraps HTTP inside a TLS-encrypted tunnel on port 443, adding encryption, authentication, and integrity.
- Every HTTP transaction consists of a request (method + URL + headers + optional body) and a response (status code + headers + body).

# Architecture

```text
                    HTTP (port 80)
  +--------+    ========================    +--------+
  | Client | ---[ plaintext request ]-----> | Server |
  |        | <--[ plaintext response ]----- |        |
  +--------+    ========================    +--------+

                   HTTPS (port 443)
  +--------+    ========================    +--------+
  | Client | ---[ TLS-encrypted req ]-----> | Server |
  |        | <--[ TLS-encrypted res ]------ |        |
  +--------+    ========================    +--------+
                     ^
                     |
              TLS layer provides:
              - encryption
              - server authentication (certificate)
              - data integrity
```

# Mental Model

```text
Client wants to reach https://example.com/api/data
  |
  v
1. DNS resolves example.com --> 93.184.216.34
  |
  v
2. TCP 3-way handshake (SYN, SYN-ACK, ACK) on port 443
  |
  v
3. TLS handshake (Client Hello, Server Hello, cert exchange, key exchange)
  |
  v
4. Client sends HTTP request inside encrypted tunnel
     GET /api/data HTTP/1.1
     Host: example.com
  |
  v
5. Server sends HTTP response inside encrypted tunnel
     HTTP/1.1 200 OK
     Content-Type: application/json
     {"result": "data"}
  |
  v
6. Connection closed or kept alive for reuse
```

Example request/response:

```bash
curl -v https://example.com/api/data

# > GET /api/data HTTP/1.1
# > Host: example.com
# > Accept: */*
# <
# < HTTP/1.1 200 OK
# < Content-Type: application/json
# < {"result": "data"}
```

# Core Building Blocks

### HTTP Request

- **Method** -- defines the action: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
- **URL** -- target resource path and query string (e.g., `/api/data?page=1`)
- **Headers** -- metadata key-value pairs (Host, Content-Type, Authorization, User-Agent)
- **Body** -- optional payload (form data, JSON, file upload); used with POST, PUT, PATCH
- HTTP request = method + URL + headers + optional body.

Related notes: [010-proxy-and-load-balancing](./010-proxy-and-load-balancing.md)

### HTTP Response

- **Status Code** -- indicates result of the request:
  - `1xx` -- informational
  - `2xx` -- success (200 OK, 201 Created, 204 No Content)
  - `3xx` -- redirection (301 Moved, 302 Found, 304 Not Modified)
  - `4xx` -- client error (400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found)
  - `5xx` -- server error (500 Internal Server Error, 502 Bad Gateway, 503 Service Unavailable)
- **Headers** -- metadata (Content-Type, Content-Length, Set-Cookie, Cache-Control)
- **Body** -- response payload (HTML, JSON, binary data)
- HTTP response = status code + headers + body.
- Status codes: 2xx success, 3xx redirect, 4xx client error, 5xx server error.

Related notes: [010-proxy-and-load-balancing](./010-proxy-and-load-balancing.md)

### HTTP Properties

- **Stateless** -- each request is independent; server retains no memory of previous requests
- **Session handling** -- achieved via cookies, tokens (JWT), or server-side session stores
- **Connection reuse** -- HTTP/1.1 keep-alive and HTTP/2 multiplexing reduce overhead
- HTTP is stateless; each request is independent with no built-in session memory.

Related notes: [006-dns](./006-dns.md)
- HTTP/2 adds multiplexing (multiple requests over one connection); HTTP/3 uses QUIC (UDP-based).

### HTTPS (HTTP Secure)

- HTTPS = HTTP over TLS; same request/response model, encrypted in transit.
- Requires a valid TLS certificate on the server.
- Uses port 443 by default.
- HTTP uses port 80 (plaintext); HTTPS uses port 443 (TLS-encrypted).
- HTTPS = HTTP + TLS; same protocol, wrapped in encryption.

| HTTP               | HTTPS                        |
| :------------------ | :--------------------------- |
| Port 80             | Port 443                     |
| Plaintext           | Encrypted (TLS)              |
| No server auth      | Server certificate required  |
| Susceptible to MITM | Protected against MITM       |

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)

### HTTPS Connection Flow

```text
Client                           Server
  |---- TCP SYN ------------------->|
  |<--- TCP SYN-ACK ---------------|
  |---- TCP ACK ------------------->|
  |                                 |
  |---- TLS Client Hello ---------->|
  |<--- TLS Server Hello ----------|
  |<--- Certificate + Key Share ---|
  |---- Key Share + Finished ------>|
  |<--- Finished ------------------|
  |                                 |
  |==== Encrypted HTTP traffic ====|
```
Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)
- TLS handshake happens after TCP handshake, before any HTTP data flows.

### HTTP Version Evolution

- HTTP/1.1 (1997): one request at a time per connection. Browsers open 6-8 parallel connections to work around this.
  - Head-of-line blocking: if one request is slow, it blocks all requests behind it on that connection.
  - Keep-alive: reuses connections to avoid repeated TCP handshakes, but still one-request-at-a-time.

- HTTP/2 (2015): multiplexing — many requests and responses flow over a single TCP connection simultaneously.
  - Header compression (HPACK): reduces overhead for repeated headers (cookies, user-agent).
  - Server push: server can proactively send resources the client will need (e.g., CSS, JS).
  - Binary framing: more efficient than HTTP/1.1 text parsing.
  - Still uses TCP — so TCP-level head-of-line blocking remains (one lost packet stalls all streams).

- HTTP/3 (2022): replaces TCP with QUIC (built on UDP) to eliminate TCP-level head-of-line blocking.
  - 0-RTT connection setup: can send data on the first packet (resuming previous connection).
  - Connection migration: survives network changes (e.g., switching from Wi-Fi to mobile) without reconnecting.
  - Per-stream loss recovery: one lost packet only stalls that stream, not all streams.
  - Built-in TLS 1.3: encryption is mandatory and integrated into the protocol.

| Feature | HTTP/1.1 | HTTP/2 | HTTP/3 |
|---------|----------|--------|--------|
| Transport | TCP | TCP | QUIC (UDP) |
| Multiplexing | No (1 req/conn) | Yes | Yes |
| Head-of-line blocking | Yes (HTTP + TCP) | Partial (TCP only) | No |
| Header compression | No | HPACK | QPACK |
| Connection setup | TCP + TLS (2-3 RTT) | TCP + TLS (2-3 RTT) | 1 RTT (or 0-RTT) |
| Encryption | Optional | Optional (but nearly universal) | Mandatory (TLS 1.3) |

```bash
# check which HTTP version a server supports
curl -sI --http2 https://example.com | head -1
# HTTP/2 200

# check HTTP/3 support (requires curl compiled with HTTP/3)
curl --http3 -sI https://example.com | head -1
```

Related notes: [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md), [005-transport-layer](./005-transport-layer.md)

---

# Troubleshooting Guide

```text
Cannot reach HTTPS site?
  |
  +--> DNS resolves? --> dig example.com
  |       |
  |       +--> no --> DNS issue (see 006-dns)
  |
  +--> TCP connects? --> curl -v https://example.com (check "Connected to")
  |       |
  |       +--> no --> firewall / port 443 blocked / server down
  |
  +--> TLS handshake succeeds?
  |       |
  |       +--> certificate error --> check cert validity, chain, CN/SAN match
  |       +--> protocol mismatch --> check supported TLS versions
  |
  +--> HTTP response code?
          |
          +--> 4xx --> client-side issue (auth, path, method)
          +--> 5xx --> server-side issue (check server logs)
          +--> 3xx --> follow redirects with curl -L
```
