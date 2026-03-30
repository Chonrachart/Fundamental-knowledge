# Docker Overview

# Overview

- **Why it exists** — Teams need a reproducible way to package applications with all their dependencies and run them identically in development, CI, and production.
- **What it is** — Docker is a platform built on the container runtime stack (dockerd → containerd → runc) that provides image building via Dockerfiles, image distribution via registries, and container execution via the Docker CLI and daemon.
- **One-liner** — Docker turns a Dockerfile into a runnable container through a layered image format, a content-addressable registry, and a client-server runtime.

# Architecture

```text
  docker CLI  ──REST API──▶  dockerd (Docker daemon)
                                  │
                        ┌─────────┼──────────┐
                        ▼         ▼          ▼
                     Images   Containers  Networks/Volumes
                        │         │
                     Registry   containerd ──▶ runc
                  (pull/push)   (lifecycle)   (create)
```

- `docker CLI` — User-facing binary; translates commands into REST calls to the daemon.
- `dockerd` — Daemon process; owns image storage, container state, networks, and volumes.
- `containerd` — Container lifecycle manager; pulls images, creates snapshots, starts/stops containers.
- `runc` — OCI-compliant low-level runtime; calls Linux `clone`/`unshare` to create namespaced processes.

# Mental Model

```text
Dockerfile ──build──▶ Image ──run──▶ Container
  (recipe)           (artifact)      (process)
                         │               │
                      push/pull      logs/exec/stop/rm
                         │
                      Registry
                   (Docker Hub, ECR, GHCR)
```

- `docker build` reads the Dockerfile top-to-bottom and produces a layered, immutable image.
- `docker push` / `docker pull` move images between the local daemon and a remote registry.
- `docker run` creates a new container (writable layer) from an image and starts the main process.
- Each container is isolated: its own filesystem view, network namespace, and process tree.

# Core Building Blocks

### Image

- **Why it exists** — Applications and their dependencies must be bundled into a single portable artifact that produces identical behavior on any Docker host.
- **What it is** — A read-only, layered filesystem snapshot built from a Dockerfile. Each instruction adds a content-addressed layer. Images are stored locally by the daemon and in remote registries. Tags (e.g. `nginx:1.25`) are human-readable pointers; digests (e.g. `nginx@sha256:...`) pin exact content.
- **One-liner** — An image is the immutable blueprint from which containers are created.

```bash
docker build -t myapp:1.0 .
docker pull nginx:alpine
docker images
docker inspect myapp:1.0
```

- Layers are cached; only changed layers and everything after them are rebuilt.
- Alpine base images are ~5 MB; distroless images exclude shells and package managers entirely.
- `docker image prune` removes dangling (untagged) images to reclaim disk space.

Related notes:
- [005-images-layers-cache](./005-images-layers-cache.md)

### Container

- **Why it exists** — An image is static; a container is the live, running instance that actually does work.
- **What it is** — A running (or stopped) instance of an image. Docker adds a thin writable layer on top of the image layers. The container has its own network namespace, PID namespace, and mount namespace. Data written inside the container is lost when it is removed unless persisted to a volume or bind mount.
- **One-liner** — A container is an isolated, ephemeral process spawned from an image.

```bash
docker run -d --name web -p 8080:80 nginx:alpine
docker ps
docker exec -it web sh
docker stop web
docker rm web
```

- `-d` runs in background; `-p host:ctr` publishes a port; `-v` mounts a volume; `-e` sets env var.
- Containers are ephemeral by default; use volumes for any data that must survive restarts.
- `docker inspect <container>` shows IP, mounts, environment, and state in full JSON.

Related notes:
- [002-running-containers-basics](./002-running-containers-basics.md)

### Dockerfile

- **Why it exists** — Image builds must be reproducible, version-controlled, and reviewable as code.
- **What it is** — A plain-text file with ordered instructions that `docker build` executes top-to-bottom to produce an image. Each instruction creates a new layer. The final image is the stack of all layers.
- **One-liner** — A Dockerfile is the source code for a Docker image.

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

- `FROM` sets the base image; every Dockerfile starts here.
- `RUN` executes a command and commits the result as a new layer.
- `COPY` / `ADD` bring files from the build context into the image.
- `CMD` / `ENTRYPOINT` define the default command when the container starts.
- Order instructions from least- to most-frequently-changed to maximize cache reuse.

Related notes:
- [003-dockerfile](./003-dockerfile.md)

### Registry

- **Why it exists** — Images must be stored centrally so they can be shared across teams, machines, and deployment environments.
- **What it is** — A server (Docker Hub, GHCR, ECR, GCR, or self-hosted) that stores and serves Docker images over HTTPS. Images are identified by `registry/repository:tag`. `docker push` uploads; `docker pull` downloads. The Docker daemon defaults to Docker Hub (`docker.io`) when no registry host is specified.
- **One-liner** — A registry is the distribution system for Docker images.

```bash
# Login to a private registry
docker login registry.company.com

# Tag and push
docker tag myapp:1.0 registry.company.com/team/myapp:1.0
docker push registry.company.com/team/myapp:1.0

# Pull on another host
docker pull registry.company.com/team/myapp:1.0
```

- Use image digests (`image@sha256:...`) in production to pin exact content instead of mutable tags.
- Private registries require `docker login` before push or pull.
- ECR images expire unless a lifecycle policy is configured.

Related notes:
- [006-registry-tagging-push-pull](./006-registry-tagging-push-pull.md)
