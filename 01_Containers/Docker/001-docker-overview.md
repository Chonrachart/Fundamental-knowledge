Docker
image
container
Dockerfile
registry

---

# Docker

- Platform for developing, shipping, and running applications in containers.
- Build once, run anywhere (dev, CI, production).

# Image

- Read-only template; built from Dockerfile or pulled from registry (Docker Hub, etc.).
- Layered: each instruction adds a layer; layers are cached.

```bash
docker build -t myapp:1.0 .
docker pull nginx:alpine
```

# Container

- Running instance of an image; has its own filesystem, network, process tree.
- Ephemeral unless data is in volumes or bind mounts.

```bash
docker run -d --name web -p 8080:80 nginx:alpine
docker ps
docker stop web
```

# Dockerfile

- Text file with instructions to build an image.
- Common instructions: `FROM`, `RUN`, `COPY`, `ADD`, `WORKDIR`, `EXPOSE`, `CMD`, `ENTRYPOINT`.

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

# Registry

- Store and distribute images (Docker Hub, GHCR, ECR, private registry).
- `docker push`, `docker pull` use registry.

# Key Commands

| Command           | Purpose                |
| :---------------- | :--------------------- |
| docker build      | Build image from Dockerfile |
| docker run        | Create and start container  |
| docker ps         | List running containers     |
| docker images     | List images                 |
| docker exec       | Run command in running container |
| docker logs       | View container logs          |
| docker rm / rmi   | Remove container / image     |
