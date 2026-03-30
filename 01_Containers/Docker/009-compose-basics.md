# Docker Compose Basics

# Overview

- **Why it exists** — Running multiple containers that must work together (app, database, cache) by hand with individual `docker run` commands is error-prone and hard to share; Compose codifies the entire multi-container setup as a single versioned file.
- **What it is** — A tool that reads a `docker-compose.yml` (or `compose.yaml`) YAML file and manages the full lifecycle of a multi-service application — creating networks, volumes, and containers in the correct order with a single command.
- **One-liner** — Compose is `docker run` for multi-container apps, expressed as declarative YAML and executed with `docker compose up`.

# Architecture

```text
docker-compose.yml
       │
  docker compose up
       │
  ┌────┴────────────────────────────────┐
  │      Project Network (auto-created) │
  │                                     │
  │  ┌──────────┐      ┌──────────┐     │
  │  │   web    │─DNS─▶│   db     │     │
  │  │ :8080:80 │      │  :5432   │     │
  │  └──────────┘      └────┬─────┘     │
  │                         │           │
  │                   ┌─────┴──────┐    │
  │                   │  dbdata    │    │
  │                   │ (volume)   │    │
  │                   └────────────┘    │
  └─────────────────────────────────────┘
```

# Mental Model

```text
compose.yaml ──parse──▶  Project
                            │
               ┌────────────┼────────────┐
               ▼            ▼            ▼
           Networks      Volumes     Services
         (auto bridge)  (named/bind) (containers)
               │                        │
               └──────────attached──────┘
                                        │
                              start in depends_on order
                              service name = DNS hostname
```

- Each service in the YAML becomes a container; the service name is its DNS hostname on the project network.
- Compose creates one bridge network per project automatically — services reach each other by name without exposing ports to the host.
- `docker compose up` is idempotent — run it again and Compose only recreates changed services.

# Core Building Blocks

### YAML Structure (services / networks / volumes)

- **Why it exists** — All configuration for the multi-container application must live in one place so any developer can reproduce the full stack with a single command.
- **What it is** — The `compose.yaml` file has three top-level keys: `services` (container definitions), `networks` (custom bridge networks), and `volumes` (named persistent volumes).
- **One-liner** — `services` defines containers, `networks` defines connectivity, `volumes` declares persistent storage.

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

networks:
  default:           # auto-created; listed here only to customise

volumes:
  dbdata:            # named volume persists across down/up cycles
```

### Service Definition (image / build / ports / environment / depends_on)

- **Why it exists** — Each service needs to describe what image to use, how to reach it from the host, and what configuration its process needs.
- **What it is** — A service block under `services:` is a single container specification; the most common fields are `image` (pre-built), `build` (path to Dockerfile), `ports` (host:container), `environment` (env vars), and `depends_on` (start ordering).
- **One-liner** — A service block is a `docker run` command written as YAML.

```yaml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.prod
    image: myapp:latest        # names the built image
    ports:
      - "8080:80"
    environment:
      APP_ENV: production
      DB_URL: postgres://db/app
    depends_on:
      - db
    restart: unless-stopped
```

- `build` and `image` can coexist — `build` builds it, `image` names the result.
- `restart: unless-stopped` restarts the container on failure and after daemon restart, but respects a manual `docker compose stop`.

### Default Project Network and DNS

- **Why it exists** — Containers need to reach each other by a stable name without hardcoding IP addresses that change on every restart.
- **What it is** — Compose automatically creates one bridge network named `<project>_default` and attaches every service to it; each container is reachable on that network using its service name as a DNS hostname.
- **One-liner** — On the Compose network, `web` can reach `db` at hostname `db` — no IP, no extra config.

```yaml
# web container can connect to postgres at host "db", port 5432
services:
  web:
    environment:
      - DATABASE_URL=postgres://db:5432/app   # "db" resolves via Compose DNS
  db:
    image: postgres:16-alpine
```

- Custom networks can be defined to isolate service groups (e.g. `frontend` and `backend` networks).
- Only ports listed under `ports:` are exposed to the host; everything else stays internal.

### Volume Types in Compose (named / bind / tmpfs)

- **Why it exists** — Different services have different persistence needs: databases need durable storage, dev environments need live code reload, and caches can use ephemeral memory.
- **What it is** — Compose supports three volume types: named volumes (managed by Docker, persist across `down/up`), bind mounts (host path mapped into container, useful for dev), and tmpfs (in-memory, no persistence).
- **One-liner** — Use named volumes for databases, bind mounts for live dev code, and tmpfs for ephemeral scratch space.

```yaml
services:
  db:
    volumes:
      - dbdata:/var/lib/postgresql/data      # named volume

  web:
    volumes:
      - ./src:/app/src                       # bind mount (dev live-reload)
      - /app/node_modules                    # anonymous volume (protects node_modules)

  cache:
    volumes:
      - type: tmpfs
        target: /data                        # in-memory, lost on stop

volumes:
  dbdata:    # declare named volumes at top level
```

- `docker compose down` removes containers and networks but NOT named volumes — data is safe.
- `docker compose down -v` removes named volumes too — use with caution.

### depends_on (Start Order vs service_healthy)

- **Why it exists** — Services have dependencies; starting an app before its database is ready causes connection errors on startup.
- **What it is** — `depends_on` controls container start order; by default it only waits for the dependency container to be *started* (not ready). With `condition: service_healthy` it waits until the dependency passes its `healthcheck`.
- **One-liner** — `depends_on` controls start order; add `condition: service_healthy` to wait for readiness, not just startup.

```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s

  app:
    build: .
    depends_on:
      db:
        condition: service_healthy   # waits until db passes healthcheck
```

- Without `condition: service_healthy`, the app starts as soon as the db *container* starts — the database process may not be ready.
- An alternative for simple cases is an entrypoint script using `wait-for-it.sh db:5432`.

### Key Compose Commands

- **Why it exists** — Managing the full lifecycle (start, stop, logs, exec, status) of all services should be possible without memorising container IDs.
- **What it is** — A set of `docker compose` subcommands that operate on the entire project or on specific services by name.
- **One-liner** — `up` starts everything, `down` tears it down, `logs`, `ps`, and `exec` are your day-to-day inspection tools.

```bash
# Start all services in the background
docker compose up -d

# Stop and remove containers and networks (keeps volumes)
docker compose down

# Show running containers for this project
docker compose ps

# Follow logs for a specific service
docker compose logs -f web

# Open a shell in a running service container
docker compose exec web sh

# Run a one-off command in a new container (does not start the service)
docker compose run --rm web python manage.py migrate

# Rebuild images and recreate containers
docker compose up -d --build

# Stop services without removing them
docker compose stop
```
