# HTTP (HyperText Transfer Protocol)

- HTTP is the protocol used for web communication.
- Request-response: client sends request, server sends response.
- Stateless: each request is independent; no built-in session memory.
- Runs over TCP, typically on port 80.

### HTTP Request

- Method: GET, POST, PUT, DELETE, etc.
- URL: path and query string
- Headers: metadata (Host, Content-Type, etc.)
- Body: optional (e.g. form data, JSON)

### HTTP Response

- Status code: 200 OK, 404 Not Found, 500 Server Error, etc.
- Headers: metadata
- Body: HTML, JSON, etc.

### HTTP Flow

```
Client → HTTP Request  → Server
Client ← HTTP Response ← Server
```

---

# HTTPS (HTTP Secure)

- HTTPS = HTTP over TLS.
- Encrypts data between client and server.
- Uses port 443; requires valid certificate.

### HTTP vs HTTPS

| HTTP       | HTTPS                    |
| :--------- | :----------------------- |
| Port 80    | Port 443                 |
| Plain text | Encrypted                |
| No auth    | Server certificate       |

### HTTPS Flow

```
Client → TCP Handshake → Server
Client → TLS Handshake → Server
Client → HTTP Request  → Server (encrypted)
Client ← HTTP Response ← Server (encrypted)
```

- See [06-TLS-and-SSL-cert-chain](./06-TLS-and-SSL-cert-chain.md) for TLS details.
