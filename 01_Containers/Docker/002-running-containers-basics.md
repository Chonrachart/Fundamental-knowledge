# Running Your First Container

- **docker run image** — create and start a container from an image; if image not local, Docker pulls it.
- **docker run nginx:alpine** — runs in **foreground**; logs to terminal; Ctrl+C stops the container.
- Add **-d** to run in **background** (detached); you get the container ID back and your terminal is free.

```bash
docker run nginx:alpine
# foreground; stop with Ctrl+C

docker run -d nginx:alpine
# background; returns container ID
```

# Giving the Container a Name

- **--name myweb** — name the container so you can use **myweb** instead of long ID.
- Without **--name**, Docker assigns a random name; named containers are easier for **docker logs myweb**, **docker stop myweb**.

```bash
docker run -d --name web nginx:alpine
```

# Exposing Ports — -p

- Container has its own network; to reach the app from your machine you **publish** a port.
- **-p 8080:80** — host port **8080** maps to container port **80**; open http://localhost:8080.
- Format: **-p host_port:container_port**; you can use multiple **-p** for several ports.

```bash
docker run -d --name web -p 8080:80 nginx:alpine
curl http://localhost:8080
```

# Listing and Inspecting Containers

- **docker ps** — list **running** containers; **docker ps -a** — list all (including stopped).
- Columns: container ID, image, command, status, ports, names.
- **docker inspect web** — full JSON details (IP, mounts, config); **docker port web** — show port mappings.

# Viewing Logs

- **docker logs web** — stdout/stderr of the container; **docker logs -f web** — follow (like tail -f).
- **docker logs --tail 100 web** — last 100 lines; useful when the container is running and you're debugging.

# Running a Command Inside a Running Container

- **docker exec web command** — run a command in the existing container.
- **docker exec -it web sh** — interactive shell (**-it** = interactive + TTY); type **exit** to leave (container keeps running).
- Use to debug, check files, or run one-off commands (e.g. **docker exec web nginx -t** to test config).

```bash
docker exec web cat /etc/nginx/nginx.conf
docker exec -it web sh
```

# Stopping and Removing

- **docker stop web** — stop the container (SIGTERM then SIGKILL); container still exists, status "Exited".
- **docker rm web** — remove the container; must be stopped first (or use **docker rm -f** to force stop + remove).
- **docker run --rm** — automatically remove the container when it exits; good for one-off runs.

```bash
docker stop web
docker rm web
# or
docker rm -f web
```

# Summary — Essential Commands (Basic Order)

| Step | Command | What it does |
|------|---------|--------------|
| 1 | docker run -d --name web -p 8080:80 nginx:alpine | Create and start container in background |
| 2 | docker ps | See running containers |
| 3 | docker logs -f web | View logs |
| 4 | docker exec -it web sh | Open shell inside container |
| 5 | docker stop web | Stop container |
| 6 | docker rm web | Remove container |

Related notes: [001-docker-overview](./001-docker-overview.md), [007-docker-run-advanced](./007-docker-run-advanced.md)

---

# Troubleshooting Guide

### Container exits immediately after `docker run -d`
1. Check exit code: `docker ps -a` — look at STATUS (e.g. Exited(1)).
2. Check logs: `docker logs <container>`.
3. Common: CMD runs a command that finishes (e.g. `echo`); use a long-running process.
4. Debug interactively: `docker run -it --entrypoint sh <image>`.

### "port is already allocated"
1. Another process uses the host port: `ss -tlnp | grep <port>`.
2. Kill the process or choose a different host port: `-p 8081:80`.
3. Check for stopped containers still holding the port: `docker ps -a`.

### `docker exec` fails with "is not running"
1. Container must be running: `docker ps` — not in `docker ps -a` only.
2. Start it: `docker start <container>`.
3. If it keeps exiting, check logs first: `docker logs <container>`.
