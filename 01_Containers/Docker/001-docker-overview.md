# Image

- Read-only template for a container; built from Dockerfile or pulled from registry.
- Layered: each Dockerfile instruction adds a layer; layers are cached and shared.
- Immutable; tag for version (e.g. `nginx:1.24`), digest for exact content.

```bash
docker build -t myapp:1.0 .
docker pull nginx:alpine
docker images
```

# Container

- Running instance of an image; has its own filesystem, network, process tree.
- Ephemeral by default — data is lost when removed unless stored in volumes or bind mounts.
- Lightweight: shares host kernel, starts in milliseconds.

```bash
docker run -d --name web -p 8080:80 nginx:alpine
docker ps
docker stop web
docker rm web
```

# Dockerfile

- Text file with instructions to build an image, layer by layer.
- Common instructions: `FROM`, `RUN`, `COPY`, `ADD`, `WORKDIR`, `EXPOSE`, `CMD`, `ENTRYPOINT`.

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

# Registry

- Server that stores and distributes images (Docker Hub, GHCR, ECR, private).
- `docker push` uploads; `docker pull` downloads.
- Default registry is Docker Hub (`docker.io`).

Related notes: [002-running-containers-basics](./002-running-containers-basics.md), [003-dockerfile](./003-dockerfile.md), [006-registry-tagging-push-pull](./006-registry-tagging-push-pull.md)
