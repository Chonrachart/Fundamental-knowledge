# Running Containers Basics

- `docker run` creates and starts a container from an image; if image not local, Docker pulls it.
- Containers run in foreground by default; add `-d` for background (detached) mode.
- Use `--name`, `-p`, `docker logs`, `docker exec` to manage container lifecycle.

# Architecture

```text
  docker CLI ──▶ dockerd ──▶ containerd ──▶ runc
  (docker run)   (API)      (runtime)     (spawn)
                               │
                          ┌────┴────┐
                       namespaces  cgroups
                       (isolation) (limits)
```

- CLI sends `run` request to daemon; daemon delegates to containerd; containerd uses runc to create the container process.
- Namespaces isolate PID, network, mount, etc.; cgroups enforce resource limits.

# Mental Model

```text
docker run nginx:alpine
  │
  ├─ Image locally? ──No──▶ docker pull nginx:alpine
  │       │
  │      Yes
  ▼
  Create container (writable layer + config)
  │
  ▼
  Start process (PID 1 inside container)
  │
  ▼
  Attach stdout/stderr (foreground) or detach (-d)
```

- `docker run` = pull (if needed) + create + start in one command.
- Container runs until PID 1 exits; then status becomes "Exited".

# Core Building Blocks

### Running Your First Container

- `docker run image` -- create and start a container from an image.
- `docker run nginx:alpine` -- runs in foreground; logs to terminal; Ctrl+C stops the container.
- Add `-d` to run in background (detached); you get the container ID back and your terminal is free.
- `docker run` creates and starts a container; `-d` for background mode.

```bash
docker run nginx:alpine
# foreground; stop with Ctrl+C

docker run -d nginx:alpine
# background; returns container ID
```

### Giving the Container a Name

- `--name myweb` -- name the container so you can use `myweb` instead of long ID.
- Without `--name`, Docker assigns a random name; named containers are easier for `docker logs myweb`, `docker stop myweb`.
- `--name` gives the container a human-readable name.

```bash
docker run -d --name web nginx:alpine
```

### Exposing Ports

- Container has its own network; to reach the app from your machine you publish a port.
- `-p 8080:80` -- host port 8080 maps to container port 80; open http://localhost:8080.
- Format: `-p host_port:container_port`; you can use multiple `-p` for several ports.
- `-p host:container` publishes ports; without it, the container is only reachable from its network.

```bash
docker run -d --name web -p 8080:80 nginx:alpine
curl http://localhost:8080
```

Related notes:
- [004-docker-network-volume](./004-docker-network-volume.md)

### Listing and Inspecting Containers

- `docker ps` -- list running containers; `docker ps -a` -- list all (including stopped).
- Columns: container ID, image, command, status, ports, names.
- `docker inspect web` -- full JSON details (IP, mounts, config); `docker port web` -- show port mappings.

### Viewing Logs

- `docker logs web` -- stdout/stderr of the container; `docker logs -f web` -- follow (like `tail -f`).
- `docker logs --tail 100 web` -- last 100 lines; useful when the container is running and you're debugging.
- `docker logs -f` follows container output in real time.

### Running a Command Inside a Running Container

- `docker exec web command` -- run a command in the existing container.
- `docker exec -it web sh` -- interactive shell (`-it` = interactive + TTY); type `exit` to leave (container keeps running).
- Use to debug, check files, or run one-off commands (e.g. `docker exec web nginx -t` to test config).
- `docker exec -it <ctr> sh` opens an interactive shell inside a running container.

```bash
docker exec web cat /etc/nginx/nginx.conf
docker exec -it web sh
```

### Stopping and Removing

- `docker stop web` -- stop the container (SIGTERM then SIGKILL); container still exists, status "Exited".
- `docker rm web` -- remove the container; must be stopped first (or use `docker rm -f` to force stop + remove).
- `docker run --rm` -- automatically remove the container when it exits; good for one-off runs.
- `docker stop` sends SIGTERM then SIGKILL; `docker rm` removes the stopped container.
- `docker run --rm` auto-removes the container on exit.

```bash
docker stop web
docker rm web
# or
docker rm -f web
```

### Essential Commands Summary

| Step | Command | What it does |
|------|---------|--------------|
| 1 | docker run -d --name web -p 8080:80 nginx:alpine | Create and start container in background |
| 2 | docker ps | See running containers |
| 3 | docker logs -f web | View logs |
| 4 | docker exec -it web sh | Open shell inside container |
| 5 | docker stop web | Stop container |
| 6 | docker rm web | Remove container |

Related notes:
- [001-docker-overview](./001-docker-overview.md)
- [007-docker-run-advanced](./007-docker-run-advanced.md)

---

# Troubleshooting Guide

### Container exits immediately after `docker run -d`
For "container exits immediately" troubleshooting, see [../000-core](../000-core.md)

### "port is already allocated"
1. Another process uses the host port: `ss -tlnp | grep <port>`.
2. Kill the process or choose a different host port: `-p 8081:80`.
3. Check for stopped containers still holding the port: `docker ps -a`.

### `docker exec` fails with "is not running"
1. Container must be running: `docker ps` -- not in `docker ps -a` only.
2. Start it: `docker start <container>`.
3. If it keeps exiting, check logs first: `docker logs <container>`.
