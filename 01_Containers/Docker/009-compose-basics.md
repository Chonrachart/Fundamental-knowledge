# Docker Compose

- Define and run multi-container apps with a YAML file (`docker-compose.yml`).
- One project per directory; `docker compose up` starts all services.
- Use for local dev, integration tests; production often uses Kubernetes or similar.

### How Compose Works

```text
docker-compose.yml
       │
  docker compose up
       │
  ┌────┴─────────────────────┐
  │  Project Network (auto)  │
  │                          │
  │  ┌─────┐    ┌─────┐     │
  │  │ web │───▶│ db  │     │
  │  │:8080│    │:5432│     │
  │  └─────┘    └──┬──┘     │
  │                │        │
  │           ┌────┴────┐   │
  │           │ dbdata  │   │
  │           │(volume) │   │
  │           └─────────┘   │
  └──────────────────────────┘
```

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

Related notes: [010-compose-production-patterns](./010-compose-production-patterns.md), [004-docker-network-volume](./004-docker-network-volume.md)

---

# Troubleshooting Guide

### "service web depends on db which is undefined"
1. Check indentation in YAML — `depends_on` must list valid service names.
2. Verify service name spelling matches exactly.

### Containers start but app can't connect to DB
1. `depends_on` only waits for container start, not readiness.
2. Add `healthcheck` on DB + `condition: service_healthy` on app.
3. Or use entrypoint script that waits: `wait-for-it.sh db:5432`.

### "network xxx not found" after down/up
1. Run `docker compose down` to clean up old networks.
2. Then `docker compose up -d` to recreate.
3. Check for orphan containers: `docker compose down --remove-orphans`.

### Volume data lost after `docker compose down`
1. `down` removes containers and networks but NOT named volumes.
2. `down -v` removes volumes too — avoid unless intended.
3. Use named volumes (declared in top-level `volumes:`) for persistence.
