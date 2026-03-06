Compose
docker-compose
service
network
depends_on

---

# Docker Compose

- Define and run multi-container apps with a YAML file (`docker-compose.yml`).
- One project per directory; `docker compose up` starts all services.
- Use for local dev, integration tests; production often uses Kubernetes or similar.

# Service

- One container definition; can specify image, build, ports, env, volumes, etc.
- Service name becomes hostname for other services on same network.

```yaml
services:
  web:
    build: .
    ports:
      - "8080:80"
    environment:
      - DB_HOST=db
    depends_on:
      - db
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - dbdata:/var/lib/postgresql/data

volumes:
  dbdata:
```

# Build and Image

- **build**: Build from Dockerfile; path and optional context/dockerfile.
- **image**: Use pre-built image; if both, image names the built image.
- **restart**: `no`, `always`, `on-failure` — when to restart container.

# Network

- By default Compose creates one network per project; all services join it and resolve each other by service name.
- **networks**: Define custom networks; attach services with `networks: [front]`.
- **ports**: Publish host:container; only publish what you need.

# Volumes

- **volumes**: Named or anonymous; persist data; list under top-level `volumes:` to name them.
- **bind mount**: Host path:container path; e.g. `.:/app` for live code.
- **tmpfs**: In-memory; no persistence.

```yaml
volumes:
  - ./config:/app/config:ro
  - cache:/app/cache
```

# depends_on

- Start order only; does not wait for service to be "ready" (e.g. DB accepting connections).
- For health-based ordering use condition: `depends_on: db: condition: service_healthy` with healthcheck on db.

# Commands

```bash
docker compose up -d
docker compose down
docker compose ps
docker compose logs -f web
docker compose exec web sh
```
