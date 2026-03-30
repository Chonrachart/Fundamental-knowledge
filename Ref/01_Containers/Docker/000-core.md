# Docker

# Overview

- **Why it exists** — Developers need a single platform to build, ship, and run containerized applications consistently across laptops, CI, and production.
- **What it is** — A client-server platform where the Docker CLI sends commands to the Docker daemon (`dockerd`), which manages images, containers, networks, and volumes through `containerd` and `runc`.
- **One-liner** — Docker is the toolchain that wraps the container runtime stack into a developer-friendly build, ship, and run workflow.

# Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  Developer Machine                                          │
│                                                             │
│  docker CLI  ──REST API──▶  dockerd (Docker daemon)         │
│                                  │                          │
│                        ┌─────────┼──────────┐               │
│                        ▼         ▼          ▼               │
│                     Images   Containers  Networks/Volumes    │
│                        │         │                          │
│                     Registry   containerd ──▶ runc           │
│                  (pull/push)   (lifecycle)   (create)        │
└─────────────────────────────────────────────────────────────┘
```

# Mental Model

```text
Dockerfile  ──build──▶  Image  ──run──▶  Container
                          │                  │
                        push/pull         logs/exec/stop/rm
                          │
                       Registry
                    (Docker Hub, ECR, GHCR)
```

- The CLI is the human interface; `dockerd` is the manager; `containerd`/`runc` do the actual work.
- Images are immutable artifacts stored in registries; containers are the running instances.
- `docker compose` orchestrates multiple containers on a single host using a YAML definition.

# Core Building Blocks

### Key Commands Reference

- **Why it exists** — A consistent command vocabulary across build, run, inspect, and clean operations.
- **What it is** — The core Docker CLI commands used in day-to-day development and operations.
- **One-liner** — Know these commands and you can manage the full container lifecycle from the terminal.

| Command | Purpose |
|---|---|
| `docker build -t <name>:<tag> .` | Build image from Dockerfile in current directory |
| `docker run -d -p host:ctr <image>` | Create and start container in detached mode |
| `docker ps` | List running containers |
| `docker ps -a` | List all containers including stopped |
| `docker images` | List local images |
| `docker exec -it <ctr> sh` | Open interactive shell in running container |
| `docker logs <ctr>` | View container stdout/stderr |
| `docker stop <ctr>` | Gracefully stop container (SIGTERM) |
| `docker rm <ctr>` | Remove stopped container |
| `docker rmi <image>` | Remove local image |
| `docker pull <image>:<tag>` | Pull image from registry |
| `docker push <image>:<tag>` | Push image to registry |
| `docker inspect <ctr/image>` | Show full JSON metadata |
| `docker compose up -d` | Start all services defined in compose file |
| `docker compose down` | Stop and remove compose services |

- Common flags: `-d` detached, `-p` publish port, `-v` volume mount, `-e` env var, `--name` container name.
- Use `docker system prune` to reclaim disk space from stopped containers, dangling images, and unused networks.

### Topic Map

- **Why it exists** — The Docker subfolder is split into focused files; this map shows what each covers and what order to read them.
- **What it is** — An index of all Docker notes from basic to advanced.
- **One-liner** — Start here, follow the links in order to build complete Docker knowledge.

| File | Topic |
|---|---|
| [001-docker-overview](./001-docker-overview.md) | Images, containers, Dockerfile, registry, full runtime stack |
| [002-running-containers-basics](./002-running-containers-basics.md) | `docker run`, `ps`, `logs`, `exec`, `stop`, `rm` |
| [003-dockerfile](./003-dockerfile.md) | Dockerfile instructions: FROM, RUN, COPY, CMD, ENTRYPOINT |
| [004-docker-network-volume](./004-docker-network-volume.md) | Networking modes, volumes, bind mounts |
| [005-images-layers-cache](./005-images-layers-cache.md) | Layers, build cache, `.dockerignore`, multi-stage builds |
| [006-registry-tagging-push-pull](./006-registry-tagging-push-pull.md) | Registry, tagging, digests, push/pull |
| [007-docker-run-advanced](./007-docker-run-advanced.md) | `docker run` flags, resource limits, env vars, restart policies |
| [008-security-user-best-practices](./008-security-user-best-practices.md) | Non-root user, secrets, image scanning |
| [009-compose-basics](./009-compose-basics.md) | Compose file structure, services, networks, volumes |
| [010-compose-production-patterns](./010-compose-production-patterns.md) | Healthchecks, profiles, scale, override files |
