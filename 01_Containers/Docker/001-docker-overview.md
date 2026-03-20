# Docker Overview

- Docker packages applications as images and runs them as containers with isolated filesystems, networks, and processes.
- Core workflow: write Dockerfile, build image, push to registry, run container.
- Images are immutable and layered; containers are ephemeral running instances.

# Core Building Blocks

### Image

- Read-only template for a container; built from Dockerfile or pulled from registry.
- Layered: each Dockerfile instruction adds a layer; layers are cached and shared.
- Immutable; tag for version (e.g. `nginx:1.24`), digest for exact content.

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

Related notes:
- [006-registry-tagging-push-pull](./006-registry-tagging-push-pull.md)

---

# Troubleshooting Guide

### Image not found when running container
1. Check image exists locally: `docker images | grep <name>`.
2. Pull from registry: `docker pull <image>:<tag>`.
3. Verify image name and tag spelling.

### Container exits immediately
1. Check exit code: `docker ps -a` (STATUS column).
2. Check logs: `docker logs <container>`.
3. Common cause: CMD finishes immediately (e.g. `echo`); use a long-running process.
4. Debug: `docker run -it --entrypoint sh <image>`.

### Dockerfile build fails
1. Check syntax: each instruction must be on its own line.
2. Check build context: files referenced by COPY must exist relative to context.
3. Check `.dockerignore` is not excluding needed files.

---

# Quick Facts (Revision)

- Image = read-only template; Container = running instance of an image.
- Dockerfile defines how to build an image layer by layer.
- Registry stores images; Docker Hub is the default public registry.
- `docker build` creates image; `docker run` creates container; `docker push` uploads to registry.
- Tags label image versions; digests pin exact content by hash.
- Containers are ephemeral; use volumes for persistent data.
