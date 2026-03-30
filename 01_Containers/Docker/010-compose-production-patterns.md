# Docker Compose Production Patterns

# Overview

- **Why it exists** — A bare `docker-compose.yml` written for local development is not safe or flexible enough for production; override files, healthchecks, profiles, and variable substitution fill those gaps without duplicating the whole file.
- **What it is** — A set of patterns — override file merging, healthcheck-gated startup, `--scale`, profiles, and `.env`/`env_file` variable substitution — that make Compose configs environment-aware and production-resilient on a single host.
- **One-liner** — Production Compose patterns layer environment-specific config on top of a base file instead of duplicating it.

# Architecture

```text
.env (variable substitution)
      │
compose.yaml          ← base: shared across all environments
      │
docker-compose.override.yml   ← auto-merged (dev defaults)
      │
docker-compose.prod.yml       ← explicit: -f flag for production

docker compose -f compose.yaml -f docker-compose.prod.yml up -d
      │
      ├─ Resolve variables from .env
      ├─ Merge file layers (later file wins on same key)
      ├─ Pull / build images
      ├─ Create networks and volumes
      └─ Start services in depends_on + healthcheck order
```

# Mental Model

```text
compose.yaml (base)
  +
docker-compose.prod.yml (overrides)
  │
  ├── resource limits added
  ├── restart: unless-stopped
  ├── healthcheck configured
  └── debug/dev services removed (no profile match)
        │
        ▼
   docker compose up -d
        │
        ├── db starts first
        │     └── healthcheck loop: pg_isready every 5s
        │           └── becomes healthy after start_period
        │
        └── app starts after db: condition: service_healthy
              └── guaranteed DB is ready before first connection
```

- Think of the base file as the skeleton and override files as environment-specific flesh.
- Healthchecks turn `depends_on` from "container started" into "service ready".
- Profiles keep optional services (debug tools, seeders) out of the default `up`.

# Core Building Blocks

### Compose in Production vs Kubernetes

- **Why it exists** — Teams need to know when Compose is sufficient and when to reach for a full orchestrator to avoid under-engineering or over-engineering infrastructure.
- **What it is** — Docker Compose runs on a single host with no built-in scheduling, multi-node networking, or rolling update primitives; Kubernetes runs across many nodes with HA, auto-scaling, and self-healing across machines.
- **One-liner** — Use Compose for single-node stacks; use Kubernetes when you need multi-node, HA, or automated scheduling.

| Concern | Docker Compose | Kubernetes |
|---|---|---|
| Nodes | Single host | Multi-node cluster |
| High availability | Manual (restart policy) | Built-in (ReplicaSet) |
| Rolling updates | Recreate only | Rolling / canary / blue-green |
| Auto-scaling | `--scale` (manual) | HPA / VPA |
| Secret management | env files / Docker Secrets | Kubernetes Secrets + CSI |
| Good for | Dev, staging, small prod | Production at scale |

### Override Files (-f Merging)

- **Why it exists** — Dev, staging, and production environments share the same services but differ in image tags, resource limits, volume mounts, and restart policies; duplicating the entire file is fragile.
- **What it is** — `docker-compose.override.yml` is merged automatically when running `docker compose up`; additional files are layered with `-f`; for any key that exists in both files the later file wins, and arrays are merged.
- **One-liner** — Split per-environment differences into override files and merge them with `-f` instead of duplicating the base.

```yaml
# compose.yaml  (base — committed, shared)
services:
  web:
    build: .
    ports:
      - "8080:80"
  db:
    image: postgres:16-alpine
```

```yaml
# docker-compose.override.yml  (dev — auto-merged, gitignored or committed)
services:
  web:
    volumes:
      - .:/app              # live code reload in dev
    environment:
      - DEBUG=true
```

```yaml
# docker-compose.prod.yml  (production — explicit -f)
services:
  web:
    image: registry.example.com/myapp:${TAG}
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 512m
          cpus: "0.5"
  db:
    restart: unless-stopped
```

```bash
# Development (override.yml auto-applied)
docker compose up -d

# Production (explicit merge)
docker compose -f compose.yaml -f docker-compose.prod.yml up -d

# Preview the merged result before applying
docker compose -f compose.yaml -f docker-compose.prod.yml config
```

### Healthcheck in Compose (test / interval / timeout / start_period / retries)

- **Why it exists** — Docker needs a way to determine whether a service is genuinely ready to serve traffic, not just that its process started.
- **What it is** — The `healthcheck` block in a service definition runs a command on a configurable schedule; Docker tracks the result and marks the container `healthy`, `unhealthy`, or `starting` during the `start_period`.
- **One-liner** — Healthcheck tells Docker and Compose when a service is ready, not just running.

```yaml
services:
  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 5s        # how often to run the check
      timeout: 3s         # time before check is considered failed
      retries: 5          # consecutive failures before unhealthy
      start_period: 10s   # grace period before failures count

  redis:
    image: redis:7-alpine
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 5s
```

- During `start_period` failures do not count toward `retries` — gives slow-starting services time to initialise.
- `test` accepts `["CMD", ...]` (exec form, no shell) or `["CMD-SHELL", "..."]` (runs via `/bin/sh`).
- Check health status with: `docker inspect --format='{{.State.Health.Status}}' <container>`.

### depends_on with condition: service_healthy

- **Why it exists** — Restarting an app repeatedly while its database initialises wastes resources and pollutes logs; waiting for a healthy signal solves the root cause.
- **What it is** — Setting `condition: service_healthy` under a `depends_on` entry tells Compose to wait until the dependency's healthcheck reports `healthy` before starting the dependent service.
- **One-liner** — `condition: service_healthy` makes Compose wait for readiness, not just container start.

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
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
        condition: service_healthy    # blocks until db is healthy
    environment:
      DATABASE_URL: postgres://postgres:${DB_PASSWORD}@db:5432/app
```

- `condition: service_started` (default) — wait for container start only.
- `condition: service_healthy` — wait for healthcheck to pass.
- `condition: service_completed_successfully` — wait for a one-shot container (migration, seed) to exit 0.

### Scaling with --scale

- **Why it exists** — A single container handling all traffic is a single point of failure; running multiple replicas spreads load and improves resilience on a single host.
- **What it is** — `docker compose up --scale <service>=N` starts N containers for a service; Compose assigns each a unique name and Docker's internal DNS returns all IPs for round-robin load balancing on the project network.
- **One-liner** — `--scale web=3` runs three replicas of a service behind DNS round-robin on the Compose network.

```bash
# Start three replicas of the web service
docker compose up -d --scale web=3

# Check all replicas
docker compose ps

# Scale down
docker compose up -d --scale web=1
```

- Do not publish a fixed host port (`"8080:80"`) when scaling — multiple containers cannot all bind the same host port; use a reverse proxy (nginx, Traefik) as the single entry point.
- `deploy.replicas` in compose.yaml requires Docker Swarm mode; `--scale` works without Swarm.

### Profiles for Optional Services

- **Why it exists** — Debug tools, seeders, and admin UIs should be available in the compose file but not start automatically on every `docker compose up`.
- **What it is** — Adding `profiles: [<name>]` to a service means it only starts when that profile is explicitly activated with `--profile <name>`; omitting the flag leaves those services stopped.
- **One-liner** — Profiles keep optional services out of the default `up` without removing them from the file.

```yaml
services:
  app:
    build: .                   # no profiles — always started

  db:
    image: postgres:16-alpine  # no profiles — always started

  adminer:
    image: adminer
    ports:
      - "8090:8080"
    profiles:
      - debug                  # only starts with --profile debug

  db-seed:
    build: ./seed
    depends_on:
      db:
        condition: service_healthy
    profiles:
      - seed                   # only starts with --profile seed
```

```bash
# Normal start — adminer and db-seed do NOT start
docker compose up -d

# Start with debug tools
docker compose --profile debug up -d

# Run seed job, then stop it
docker compose --profile seed run --rm db-seed
```

### Variable Substitution (.env vs env_file)

- **Why it exists** — Hardcoding image tags, passwords, and hostnames in compose.yaml makes it impossible to reuse the same file across environments.
- **What it is** — `.env` (a file of `KEY=value` pairs in the project directory) feeds `${VAR}` placeholders inside the compose.yaml file itself at parse time; `env_file` in a service block passes variables into the container's environment at runtime — these are two different mechanisms.
- **One-liner** — `.env` fills placeholders in compose.yaml; `env_file` injects env vars into the running container.

```bash
# .env  (project root — feeds compose.yaml substitution)
TAG=1.4.2
DB_PASSWORD=supersecret
POSTGRES_USER=app
```

```yaml
# compose.yaml — uses .env for substitution
services:
  web:
    image: registry.example.com/myapp:${TAG}   # substituted from .env
    env_file:
      - .env.runtime          # injected into container environment
    environment:
      APP_VERSION: ${TAG}     # also substituted from .env
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
```

```bash
# .env.runtime  (passed into the container via env_file)
LOG_LEVEL=info
FEATURE_FLAGS=payments,notifications
```

- `.env` is loaded automatically by Compose for substitution; it is not automatically passed into containers unless you also add `env_file: .env`.
- Override a single variable without editing `.env`: `TAG=2.0.0 docker compose up -d`.
- Never commit `.env` files containing real secrets; commit a `.env.example` with placeholder values.
