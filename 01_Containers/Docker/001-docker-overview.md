# Docker Overview

- Docker packages applications as images and runs them as containers with isolated filesystems, networks, and processes.
- Core workflow: write Dockerfile, build image, push to registry, run container.
- Images are immutable and layered; containers are ephemeral running instances. Related notes: [005-images-layers-cache](./005-images-layers-cache.md) for image layer details

# Architecture

```text
  docker CLI ──REST API──▶ dockerd (daemon)
                                │
                      ┌─────────┼──────────┐
                      ▼         ▼          ▼
                   Images   Containers  Networks/Volumes
                      │         │
                   Registry   containerd ──▶ runc
                (pull/push)   (manages)     (spawns)
```

- **docker CLI**: User-facing tool; sends commands to daemon via REST API.
- **dockerd**: Daemon; manages images, containers, networks, volumes.
- **containerd**: Container runtime; manages container lifecycle (create, start, stop).
- **runc**: Low-level OCI runtime; creates the actual Linux container (namespaces, cgroups).

# Mental Model

```text
Dockerfile ──build──▶ Image ──run──▶ Container
   (recipe)          (artifact)      (process)
                        │               │
                     push/pull      logs/exec/stop/rm
                        │
                     Registry
```

- Write a Dockerfile (recipe), `docker build` produces an image (immutable artifact).
- `docker run` creates a container (running process) from the image.
- `docker push/pull` moves images to/from registries.

# Core Building Blocks

### Image

- Read-only template for a container; built from Dockerfile or pulled from registry.
- Layered: each instruction adds a layer; see [005-images-layers-cache](./005-images-layers-cache.md) for details.
- Immutable; tag for version (e.g. `nginx:1.24`), digest for exact content.
- Image = read-only template; Container = running instance of an image.
- `docker build` creates image; `docker run` creates container; `docker push` uploads to registry.
- Tags label image versions; digests pin exact content by hash.

```bash
docker build -t myapp:1.0 .
docker pull nginx:alpine
docker images
```

Related notes:
- [005-images-layers-cache](./005-images-layers-cache.md)

### Container

- Running instance of an image; has its own filesystem, network, process tree.
- Ephemeral by default -- data is lost when removed unless stored in volumes or bind mounts.
- Lightweight: shares host kernel, starts in milliseconds.
- Containers are ephemeral; use volumes for persistent data.

```bash
docker run -d --name web -p 8080:80 nginx:alpine
docker ps
docker stop web
docker rm web
```

Related notes:
- [002-running-containers-basics](./002-running-containers-basics.md)

### Dockerfile

- Text file with instructions to build an image, layer by layer.
- Common instructions: `FROM`, `RUN`, `COPY`, `ADD`, `WORKDIR`, `EXPOSE`, `CMD`, `ENTRYPOINT`.
- Dockerfile defines how to build an image layer by layer.

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Related notes:
- [003-dockerfile](./003-dockerfile.md)

### Registry

- Server that stores and distributes images (Docker Hub, GHCR, ECR, private).
- `docker push` uploads; `docker pull` downloads.
- Default registry is Docker Hub (`docker.io`).
- Registry stores images; Docker Hub is the default public registry.

Related notes:
- [006-registry-tagging-push-pull](./006-registry-tagging-push-pull.md)

---

# Troubleshooting Guide

### Image not found when running container
1. Check image exists locally: `docker images | grep <name>`.
2. Pull from registry: `docker pull <image>:<tag>`.
3. Verify image name and tag spelling.

### Container exits immediately
For "container exits immediately" troubleshooting, see [../000-core](../000-core.md)

### Dockerfile build fails
1. Check syntax: each instruction must be on its own line.
2. Check build context: files referenced by COPY must exist relative to context.
3. Check `.dockerignore` is not excluding needed files.
