# Docker

- Platform for developing, shipping, and running applications in containers.
- Uses client-server architecture: CLI talks to Docker daemon, daemon manages images/containers.
- Build once, run anywhere (dev, CI, production).

# Architecture

```text
 docker CLI ──REST API──▶ dockerd (daemon)
                              │
                    ┌─────────┼──────────┐
                    ▼         ▼          ▼
                 Images   Containers  Networks/Volumes
                    │         │
                 Registry   containerd ──▶ runc
              (pull/push)   (lifecycle)   (create)
```

# Mental Model

```text
Dockerfile  ──build──▶  Image  ──run──▶  Container
                          │                  │
                        push/pull         logs/exec/stop
                          │
                       Registry
                    (Docker Hub, ECR)
```

# Core Building Blocks

### Key Commands

| Command           | Purpose                |
| :---------------- | :--------------------- |
| `docker build`      | Build image from Dockerfile |
| `docker run`        | Create and start container  |
| `docker ps`         | List running containers     |
| `docker images`     | List images                 |
| `docker exec`       | Run command in running container |
| `docker logs`       | View container logs          |
| `docker rm` / `rmi`   | Remove container / image     |

- Docker uses client-server model: CLI -> daemon -> `containerd` -> `runc`.
- Image is immutable read-only layers; container adds a writable layer.
- Dockerfile builds image; `docker run` creates container from image.
- Registry stores and distributes images (Docker Hub is default).
- `-d` detached, `-p` publish port, `-v` volume, `-e` env var.
- `docker compose` for multi-container apps on single host.
- Use alpine/distroless bases for minimal image size and attack surface.

Related notes:
- [001-docker-overview](./001-docker-overview.md)
- [002-running-containers-basics](./002-running-containers-basics.md)

---

# Troubleshooting Guide

### "Cannot connect to the Docker daemon"
1. Check if Docker is running: `systemctl status docker`.
2. Start it: `sudo systemctl start docker`.
3. Check socket permission: user must be in `docker` group or use `sudo`.

### "docker: command not found"
1. Check installation: `which docker`.
2. Install Docker: follow official docs for your distro.
3. Check PATH: `echo $PATH`.

### "Error response from daemon: conflict"
1. A container with same name exists: `docker ps -a | grep <name>`.
2. Remove it: `docker rm <name>` or `docker rm -f <name>`.
3. Or use a different `--name`.

# Topic Map (basic to advanced)

- [001-docker-overview](./001-docker-overview.md) -- Images, containers, Dockerfile, registry
- [002-running-containers-basics](./002-running-containers-basics.md) -- run, ps, logs, exec, stop, rm
- [003-dockerfile](./003-dockerfile.md) -- Dockerfile instructions, FROM, RUN, COPY, CMD
- [004-docker-network-volume](./004-docker-network-volume.md) -- Networking, volumes
- [005-images-layers-cache](./005-images-layers-cache.md) -- Layers, cache, .dockerignore, multi-stage
- [006-registry-tagging-push-pull](./006-registry-tagging-push-pull.md) -- Registry, tag, digest, push/pull
- [007-docker-run-advanced](./007-docker-run-advanced.md) -- docker run flags, limits, env, restart
- [008-security-user-best-practices](./008-security-user-best-practices.md) -- Non-root, secrets, scanning
- [009-compose-basics](./009-compose-basics.md) -- Compose, services, networks, volumes
- [010-compose-production-patterns](./010-compose-production-patterns.md) -- Healthcheck, profiles, scale, override
