# Running Containers Basics

### Overview

- **Why it exists** — An image sitting in a registry does nothing. You need a runtime command that takes that image, adds a writable layer, wires up networking, and starts the process — that is `docker run`.
- **What it is** — `docker run` is the primary command for creating and starting containers. It combines pull (if needed), create, and start into one step. Flags control detached mode, naming, port publishing, and cleanup. Supporting commands (`docker ps`, `docker logs`, `docker exec`, `docker stop`, `docker rm`) manage the container through its lifecycle.
- **One-liner** — `docker run` turns an image into a live, running container; the supporting commands let you observe and control it.

### Architecture

```text
┌─── docker CLI ──────────────────────────────────────────────────┐
│  docker run -d --name web -p 8080:80 nginx:alpine               │
└───────────────────────┬─────────────────────────────────────────┘
                        │ HTTP (Unix socket / TCP)
                        ▼
              ┌─── dockerd (daemon) ───────────────────────────┐
              │  - pulls image if not cached                   │
              │  - creates container config + writable layer   │
              │  - assigns name, sets port mapping             │
              └───────────────────┬────────────────────────────┘
                                  │
                                  ▼
                       containerd (runtime supervisor)
                                  │
                                  ▼
                         runc (OCI runtime)
                                  │
                    ┌─────────────┴──────────────┐
                 namespaces                   cgroups
                 (PID, net, mnt, uts)         (CPU, memory limits)
                                  │
                                  ▼
                    Container process (PID 1 inside container)
```

### Mental Model

```text
docker run nginx:alpine
        │
        ├─ Image cached locally? ──No──▶ docker pull nginx:alpine
        │         │
        │        Yes
        ▼
  Create container
  (copy-on-write writable layer + config)
        │
        ▼
  Start process (PID 1 inside container)
        │
        ├── foreground (default) ──▶ stdout/stderr printed to terminal
        │                            Ctrl+C stops the container
        │
        └── detached (-d) ──▶ container ID printed, terminal free
                               container keeps running in background
        │
        ▼
  Container exits when PID 1 exits → status "Exited"
```

- `docker run` = pull (if needed) + create + start in one command.
- Detached mode (`-d`) is the normal choice for long-running services.
- The container lives until PID 1 exits; `docker stop` triggers a graceful shutdown (SIGTERM → SIGKILL).

### Core Building Blocks

### Running a Container

- **Why it exists** — You need a single command that takes an image and turns it into a running process, handling image pulling, layer setup, and process start automatically.
- **What it is** — `docker run <image>` creates and starts a container. Without `-d` the container runs in the foreground and its stdout/stderr stream to your terminal. `Ctrl+C` stops it. With `-d` it runs in the background and Docker prints the container ID.
- **One-liner** — `docker run` is pull + create + start; add `-d` to run in the background.

```bash
# foreground — logs stream to terminal; Ctrl+C stops it
docker run nginx:alpine

# detached — returns container ID; container keeps running
docker run -d nginx:alpine
```

### Naming a Container

- **Why it exists** — Without a name, Docker assigns a random string (e.g. `sleepy_lovelace`). Every management command would need the full container ID. A name makes all follow-up commands readable and scriptable.
- **What it is** — The `--name` flag assigns a human-readable identifier to the container. The name must be unique among running and stopped containers on the host. Use it in `docker logs`, `docker exec`, `docker stop`, and `docker rm` instead of the ID.
- **One-liner** — `--name` gives the container a stable, human-readable handle for every follow-up command.

```bash
docker run -d --name web nginx:alpine

docker logs web
docker stop web
docker rm web
```

### Publishing Ports

- **Why it exists** — Containers have their own isolated network namespace. Without port publishing, nothing on the host (or outside) can reach the containerised service.
- **What it is** — The `-p host_port:container_port` flag instructs dockerd to listen on `host_port` and forward traffic to `container_port` inside the container. Multiple `-p` flags publish multiple ports. Without `-p`, the container is only reachable from Docker's internal network.
- **One-liner** — `-p 8080:80` maps host port 8080 to container port 80; without it the service is unreachable from the host.

```bash
docker run -d --name web -p 8080:80 nginx:alpine
curl http://localhost:8080

# multiple ports
docker run -d --name app -p 8080:80 -p 8443:443 nginx:alpine
```

### Listing and Inspecting Containers

- **Why it exists** — Once containers run in detached mode you need visibility into what is running, its status, and its port mappings without looking at raw daemon logs.
- **What it is** — `docker ps` lists running containers with columns for ID, image, command, created, status, ports, and name. `docker ps -a` includes stopped containers. `docker inspect <name>` returns full JSON (IP, mounts, env, config). `docker port <name>` shows the published port mappings only.
- **One-liner** — `docker ps` is the live view of running containers; add `-a` to see everything including stopped ones.

```bash
docker ps                    # running containers
docker ps -a                 # all containers (including stopped)
docker inspect web           # full JSON config
docker port web              # port mappings only
```

### Viewing Logs

- **Why it exists** — Containers run as isolated processes; you cannot simply `tail` a log file. You need a command that captures what the container's PID 1 writes to stdout/stderr.
- **What it is** — `docker logs <name>` prints all captured stdout/stderr output from the container. `-f` follows live output (equivalent to `tail -f`). `--tail N` limits to the last N lines. Logs persist as long as the container exists.
- **One-liner** — `docker logs -f <name>` streams live output from the container in real time.

```bash
docker logs web              # all logs
docker logs -f web           # follow (live)
docker logs --tail 100 web   # last 100 lines
```

### Running Commands Inside a Container

- **Why it exists** — You often need to inspect files, test connectivity, or run a one-off command inside a running container without stopping it or attaching to PID 1.
- **What it is** — `docker exec <name> <command>` spawns a new process inside the running container's namespaces. `-it` (`--interactive --tty`) is added when you want an interactive shell. The container continues running after you `exit` the shell — `exec` creates a side process, not PID 1.
- **One-liner** — `docker exec -it <name> sh` opens an interactive shell inside the container; the container keeps running when you exit.

```bash
docker exec web cat /etc/nginx/nginx.conf
docker exec web nginx -t                  # test nginx config
docker exec -it web sh                    # interactive shell
```

### Stopping and Removing

- **Why it exists** — You need controlled shutdown (not kill -9) and a way to clean up containers that are no longer needed, freeing name, writable-layer storage, and port allocations.
- **What it is** — `docker stop <name>` sends SIGTERM to PID 1 and waits up to 10 s; if still running it sends SIGKILL. The container still exists with status "Exited". `docker rm <name>` deletes the stopped container. `docker rm -f` force-stops then removes. `docker run --rm` auto-removes the container the moment it exits — ideal for one-off tasks.
- **One-liner** — `docker stop` gracefully shuts down; `docker rm` cleans it up; `--rm` auto-removes on exit.

```bash
docker stop web              # graceful stop (SIGTERM → SIGKILL)
docker rm web                # remove stopped container
docker rm -f web             # force stop + remove in one step

# one-off: auto-removed when done
docker run --rm alpine echo "hello"
```

### Essential Commands Summary

| Step | Command | What it does |
|------|---------|--------------|
| 1 | `docker run -d --name web -p 8080:80 nginx:alpine` | Create and start container in background |
| 2 | `docker ps` | List running containers |
| 3 | `docker logs -f web` | Follow live logs |
| 4 | `docker exec -it web sh` | Open interactive shell inside container |
| 5 | `docker stop web` | Gracefully stop the container |
| 6 | `docker rm web` | Remove the stopped container |

### Troubleshooting

### Container exits immediately after `docker run -d`

1. Check logs immediately: `docker logs <name>` — the process wrote an error before exiting.
2. Inspect exit code: `docker inspect <name> --format '{{.State.ExitCode}}'`.
3. Common causes: missing required environment variable, wrong command, missing config file.
4. Run interactively to debug: `docker run -it --name debug <image> sh` to explore the container.

### "port is already allocated"

1. Find what owns the host port: `ss -tlnp | grep <port>`.
2. Kill the conflicting process or pick a different host port: `-p 8081:80`.
3. Check for stopped containers still holding the binding: `docker ps -a` — remove them with `docker rm <name>`.

### `docker exec` fails with "is not running"

1. Confirm the container is actually running: `docker ps` (not just `docker ps -a`).
2. Start it: `docker start <name>`.
3. If it keeps exiting, read logs first: `docker logs <name>` — fix the root cause before retrying.

### `docker logs` shows nothing

1. The app may write to a file instead of stdout — `docker exec -it <name> sh` to check.
2. If the container restarted, use `docker logs --previous <name>` to see the previous run's output.
3. Confirm the logging driver is `json-file` (default): `docker inspect <name> --format '{{.HostConfig.LogConfig.Type}}'`.
