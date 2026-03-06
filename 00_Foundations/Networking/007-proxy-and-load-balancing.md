# Proxy

- A proxy is an intermediary server that sits between a client and a destination server.
- The client sends requests to the proxy; the proxy forwards them to the target and returns the response.
- Proxies can provide caching, filtering, anonymity, or access control.

### Forward Proxy

- Client uses proxy to reach external servers.
- Client knows it is using a proxy.
- Use cases:
  - Bypass restrictions
  - Hide client IP
  - Corporate web filtering
  - Caching

```
Client → Forward Proxy → Internet → Server
```

### Reverse Proxy

- Sits in front of one or more servers.
- Client does not know backend servers exist.
- Client thinks it talks directly to the proxy.
- Use cases:
  - Load balancing
  - SSL termination
  - Caching
  - Hiding backend topology

```
Client → Reverse Proxy → Backend Server(s)
```

### Proxy vs Reverse Proxy

| Forward Proxy              | Reverse Proxy                 |
| :------------------------- | :---------------------------- |
| Client-side                | Server-side                   |
| Hides client identity      | Hides server identity         |
| Client configures proxy    | Server admin configures       |
| Access control, filtering  | Load balancing, SSL, caching  |

---

# Load Balancing

- Load balancing distributes incoming traffic across multiple servers.
- Purpose: improve availability, scalability, and performance.
- Usually implemented as a reverse proxy in front of backend servers.

### How Load Balancing Works

```
Client → Load Balancer → Backend 1
                       → Backend 2
                       → Backend 3
```

- Client sends request to load balancer.
- Load balancer selects a backend using an algorithm.
- Response may go back through the load balancer or directly (depending on mode).

### Load Balancing Algorithms

- Round Robin
  - Sends each request to the next server in order.
  - Simple, even distribution.
- Least Connections
  - Sends to the server with fewest active connections.
  - Good when requests have different durations.
- IP Hash
  - Same client IP → same backend.
  - Useful for session affinity.
- Weighted Round Robin / Weighted Least Connections
  - Servers have different capacities; assign more traffic to stronger ones.

### Health Checks

- Load balancer periodically checks if backends are alive.
- Unhealthy servers are removed from the pool.
- Common checks: HTTP, TCP, or custom scripts.

### Components

- Load Balancer (reverse proxy)
- Backend pool (multiple servers)
- Health check configuration
- Algorithm selection