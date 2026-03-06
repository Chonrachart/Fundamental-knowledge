Compose
production
override
env file
healthcheck
dependency
scale
profiles

---

# Compose in Production — When and When Not

- **docker compose** is suitable for **single-node** stacks (e.g. small app + DB + cache); same host, simple networking.
- For **multi-node**, **high availability**, **scheduling**, use **Kubernetes** or other orchestrator; Compose does not replace them.
- Use Compose for **staging**, **dev**, **CI**; or production only if single server is acceptable.

# Override and Multiple Files

- **docker-compose.yml** + **docker-compose.override.yml**: Override is merged automatically (later file wins for same key).
- **-f a.yml -f b.yml**: Merge in order; use for **prod** vs **dev** (e.g. docker-compose.yml + docker-compose.prod.yml).
- **env_file** in compose: Load env vars from file into container; **.env** in project dir is loaded by Compose for variable substitution in the compose file itself (e.g. ${VAR}).

# Healthcheck in Compose

- **healthcheck** in service: **test** (command or CMD-SHELL), **interval**, **timeout**, **start_period**, **retries**.
- **depends_on: condition: service_healthy** (Compose v2.1+): Start service only when dependency is healthy; use for "wait for DB ready".
- **restart: unless-stopped** or **always** so Compose restarts unhealthy containers (Docker uses health status).

```yaml
services:
  db:
    image: postgres:16
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5
      start_period: 10s
  app:
    depends_on:
      db:
        condition: service_healthy
```

# Dependency and Startup Order

- **depends_on**: Only **start order**; does not wait for app to be "ready" unless **condition: service_healthy**.
- For "wait for DB to accept connections": use **healthcheck** on DB + **condition: service_healthy** on app; or use **entrypoint** script in app that waits (e.g. wait-for-it, custom loop).
- **condition: service_started** (default): Start after dependency container has started (no readiness).

# Scale and Replicas

- **deploy.replicas** (Compose v3): e.g. **deploy: replicas: 3**; requires **docker compose up** with Swarm mode or Compose v2 deploy; **docker compose up** without Swarm runs **one** container per service.
- **docker compose up -d --scale web=3**: Scale service at runtime (no Swarm); multiple containers, one service name (DNS round-robin on same network).

# Profiles

- **profiles: [debug]**: Service is only started when you pass **--profile debug** (e.g. docker compose --profile debug up).
- Use for optional services (debug sidecar, dev-only tools); default **up** without profile does not start them.
- Reduces resource use when you don't need those services.

# Variable Substitution and .env

- **.env** file (in project dir): **KEY=value**; used for **${KEY}** in compose file (image tag, port, env_file path).
- **env_file** in service: Passed **into** container as env vars; **.env** for compose file is **not** automatically passed to containers unless you **env_file: .env**.
- **environment** with **${VAR}**: Substituted from host env or .env; use for overrides per environment.
