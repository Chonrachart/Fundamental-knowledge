# Proxy and Load Balancing

- A proxy is an intermediary server between client and destination that can provide caching, filtering, anonymity, or access control.
- A forward proxy acts on behalf of clients; a reverse proxy acts on behalf of servers (hiding backends, terminating SSL, load balancing).
- Load balancing distributes traffic across multiple backend servers using algorithms like round robin, least connections, or IP hash.

# Architecture
![proxy](./pic/proxy.png)

```text
Forward Proxy:
  +--------+     +---------------+     +----------+     +--------+
  | Client | --> | Forward Proxy | --> | Internet | --> | Server |
  +--------+     +---------------+     +----------+     +--------+
  (knows proxy)   (hides client)

Reverse Proxy / Load Balancer:
                                        +------------+
                                   +--> | Backend #1 |
  +--------+     +---------------+ |    +------------+
  | Client | --> | Reverse Proxy |-+
  +--------+     | (Load Balancer)|-+    +------------+
  (sees proxy    +---------------+ +--> | Backend #2 |
   as server)                      |    +------------+
                                   |
                                   |    +------------+
                                   +--> | Backend #3 |
                                        +------------+
```

# Mental Model

```text
Client request arrives
  |
  v
Is there a proxy?
  |
  +--> Forward proxy (client-side)
  |       |
  |       v
  |     Proxy evaluates: allowed? cached?
  |       |
  |       +--> blocked --> return error to client
  |       +--> cached  --> return cached response
  |       +--> forward --> send to destination server
  |
  +--> Reverse proxy (server-side)
          |
          v
        Terminate SSL? --> yes --> decrypt, then forward plain HTTP to backend
          |
          v
        Select backend (load balancing algorithm)
          |
          v
        Health check: backend alive?
          |
          +--> yes --> forward request
          +--> no  --> pick next healthy backend
          |
          v
        Return response to client
```

Example: nginx as reverse proxy with load balancing:

```nginx
upstream backends {
    least_conn;
    server 10.0.0.1:8080;
    server 10.0.0.2:8080;
    server 10.0.0.3:8080;
}

server {
    listen 443 ssl;
    server_name example.com;

    ssl_certificate     /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    location / {
        proxy_pass http://backends;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

# Core Building Blocks

### Forward Proxy

- Client explicitly configures the proxy (browser settings, `http_proxy` env var).
- Client knows it is using a proxy.
- Use cases:
  - Hide client IP / anonymity
  - Bypass geo-restrictions
  - Corporate web filtering and access control
  - Caching frequently accessed content
- Examples: Squid, corporate HTTP proxies

```text
Client --> Forward Proxy --> Internet --> Server
```

Related notes: [008-http-https](./008-http-https.md), [011-vpn-technologies](./011-vpn-technologies.md)

### Reverse Proxy

- Sits in front of one or more backend servers.
- Client does not know backend servers exist; it sees the proxy as the server.
- Use cases:
  - Load balancing across backends
  - SSL/TLS termination
  - Caching and compression
  - Hiding backend topology and IPs
  - Rate limiting, WAF
- Examples: nginx, HAProxy, Envoy, Traefik

```text
Client --> Reverse Proxy --> Backend Server(s)
```

Related notes: [008-http-https](./008-http-https.md), [009-tls-and-ssl-cert-chain](./009-tls-and-ssl-cert-chain.md)
- Reverse proxy: server-side, hides backend servers, client is unaware.
- SSL termination at the reverse proxy offloads encryption from backends.
- nginx, HAProxy, Envoy, and Traefik are common reverse proxy / load balancer tools.

### Forward vs Reverse Proxy

| Forward Proxy              | Reverse Proxy                |
| :------------------------- | :--------------------------- |
| Client-side                | Server-side                  |
| Hides client identity      | Hides server identity        |
| Client configures proxy    | Server admin configures      |
| Access control, filtering  | Load balancing, SSL, caching |
| Client aware of proxy      | Client unaware of backends   |

Related notes: [011-vpn-technologies](./011-vpn-technologies.md)
- Forward proxy: client-side, hides client identity, client is aware.

### Load Balancing Algorithms

- **Round Robin** — sends each request to the next server in order; simple, even distribution. Best when all servers are similar and requests are roughly equal.
- **Weighted Round Robin** — assigns more traffic to more powerful servers based on configured weights. Server with weight 3 gets 3x traffic of weight 1.
- **Least Connections** — sends to the server with fewest active connections. Best when request durations vary (some fast, some slow).
- **Weighted Least Connections** — like least connections but accounts for server capacity via weights.
- **IP Hash** — hashes client IP to determine backend; same client always hits same server. Provides basic session affinity without cookies.
- **Consistent Hashing** — distributes requests across backends using a hash ring. When a backend is added or removed, only a small fraction of requests are redistributed (unlike IP hash which reshuffles everything).
- **Sticky Sessions (Session Affinity)** — routes a client to the same backend for the duration of a session, tracked via cookies or headers. Required when backends store session state locally.
- **Response-Time Based (Least Response Time)** — routes to the backend with the fastest recent response time. Automatically adapts to backend performance.

When to use which:

| Algorithm | Best for |
|-----------|----------|
| Round Robin | Stateless services, equal-capacity servers |
| Weighted Round Robin | Mixed-capacity servers |
| Least Connections | Long-lived or variable-duration requests |
| IP Hash | Simple session affinity without cookies |
| Consistent Hashing | Caching layers (minimizes cache misses on scaling) |
| Sticky Sessions | Stateful apps that store session data on the backend |
| Response-Time Based | Backends with varying performance characteristics |

Related notes: [008-http-https](./008-http-https.md)

### Health Checks

- Load balancer periodically probes backends to verify they are alive.
- Unhealthy servers are removed from the pool; re-added when healthy.
- Common check types:
  - **HTTP** -- request a health endpoint, expect 200 OK
  - **TCP** -- verify port is open and accepting connections
  - **Custom script** -- run application-specific checks

Related notes: [008-http-https](./008-http-https.md)
- Health checks remove unhealthy backends from the pool automatically.

### Load Balancer Components
- **Load balancer** -- reverse proxy that distributes traffic
- **Backend pool** -- group of servers receiving traffic
- **Health check configuration** -- probe interval, timeout, thresholds
- **Algorithm selection** -- determines how requests are distributed
- A load balancer is typically implemented as a reverse proxy.
