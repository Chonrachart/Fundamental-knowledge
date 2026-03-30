# docker run — Advanced Flags

# Overview

- **Why it exists** — A container's isolation, resource consumption, security posture, networking, and data persistence must all be configured at startup because the container's environment is immutable once running.
- **What it is** — `docker run [OPTIONS] IMAGE [COMMAND] [ARG...]` creates and starts a new container. Each flag maps to a Linux kernel mechanism: namespaces for isolation, cgroups for resource limits, capabilities for privilege control, and bind mounts or volumes for data.
- **One-liner** — `docker run` flags are the dials that tune exactly how much isolation, resources, and access a container gets.

# Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                     docker run [OPTIONS] IMAGE              │
│                                                             │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────────────┐ │
│  │  Lifecycle   │  │    Resource    │  │    Security     │ │
│  │              │  │    (cgroups)   │  │  (capabilities) │ │
│  │  -d / --rm   │  │  --memory      │  │  --user         │ │
│  │  --restart   │  │  --cpus        │  │  --read-only    │ │
│  │  --name      │  │  --cpuset-cpus │  │  --cap-drop     │ │
│  └──────────────┘  └────────────────┘  └─────────────────┘ │
│                                                             │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────────────┐ │
│  │  Networking  │  │     Data       │  │   Config        │ │
│  │ (namespaces) │  │  (bind/volume) │  │                 │ │
│  │  --network   │  │  -v / --mount  │  │  -e             │ │
│  │  -p / -P     │  │  --tmpfs       │  │  --env-file     │ │
│  │  --dns       │  │                │  │  --entrypoint   │ │
│  └──────────────┘  └────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

# Mental Model

```text
docker run [OPTIONS] IMAGE [CMD]
  │
  ├─ Isolation (namespaces)
  │    PID, NET, MNT, UTS, IPC, USER
  │
  ├─ Resource limits (cgroups)
  │    --memory, --cpus, --cpuset-cpus
  │
  ├─ Security
  │    --user, --cap-drop, --read-only
  │
  ├─ Connectivity
  │    --network, -p (ports), --dns
  │
  └─ Data
       -v (volumes), --tmpfs, --mount
```

- Namespaces provide process and network isolation between containers and the host.
- cgroups enforce CPU and memory limits so one container cannot starve others.
- Capabilities control which kernel operations a process may perform; dropping them follows least-privilege.
- Volumes and bind mounts are the only way to persist data beyond the container's lifetime.

# Core Building Blocks

### Detach and Auto-Remove (-d / --rm)

- **Why it exists** — Long-running services should not block the terminal, and one-off containers should not leave stale stopped containers behind.
- **What it is** — `-d` (detach) starts the container in the background and returns its ID immediately; logs are not printed to the terminal. `--rm` automatically removes the container filesystem once it exits. The two flags are often combined for ephemeral utility containers.
- **One-liner** — `-d` runs in the background; `--rm` cleans up automatically on exit.

```bash
# Run a service in the background
docker run -d --name web nginx:alpine

# Run a one-off command and auto-clean up
docker run --rm alpine echo "hello"

# Run interactively and clean up on exit
docker run --rm -it ubuntu bash
```

### Port Publishing (-p / -P)

- **Why it exists** — Containers have their own network namespace; ports must be explicitly mapped to make services reachable from the host or external network.
- **What it is** — `-p host_port:container_port` forwards traffic from a host port to a container port. Multiple `-p` flags are allowed. `-p 127.0.0.1:8080:80` restricts binding to localhost only. `-P` publishes all ports declared with `EXPOSE` in the image to random host ports.
- **One-liner** — `-p` maps a host port to a container port so the service is reachable from outside.

```bash
# Bind port 8080 on all interfaces to container port 80
docker run -d -p 8080:80 nginx

# Bind only on localhost
docker run -d -p 127.0.0.1:8080:80 nginx

# Publish all EXPOSEd ports to random host ports
docker run -d -P nginx

# Check which host port was assigned
docker port <container>
```

### Environment Variables (-e / --env-file)

- **Why it exists** — Containers must receive runtime configuration (database URLs, API keys, feature flags) without baking secrets into the image.
- **What it is** — `-e KEY=value` injects a single environment variable into the container, overriding any `ENV` set in the Dockerfile. `--env-file path` reads `KEY=value` lines from a file on the host. Multiple `-e` flags are allowed. Values are visible in `docker inspect` output, so avoid using them for highly sensitive secrets in production.
- **One-liner** — `-e` and `--env-file` inject runtime configuration into the container at start.

```bash
# Single variable
docker run -e DB_HOST=db -e DB_PASS=secret myapp

# From a file
docker run --env-file .env myapp

# Verify inside the container
docker exec <ctr> env | grep DB_HOST
```

### Memory and CPU Limits

- **Why it exists** — Without limits a single container can exhaust all host CPU or memory, starving other containers and destabilizing the host.
- **What it is** — `--memory` (or `-m`) sets the maximum RAM a container may use; exceeding it causes the process to be OOM-killed. `--memory-swap` sets the combined memory + swap ceiling. `--cpus` limits total CPU time as a fraction of cores (e.g. `1.5` = 1.5 cores). `--cpuset-cpus` pins the container to specific CPU cores.
- **One-liner** — `--memory` and `--cpus` prevent a single container from monopolizing host resources.

```bash
# Limit to 512 MB RAM and 0.5 CPU cores
docker run -m 512m --cpus=0.5 myapp

# Disable swap (memory-swap == memory)
docker run -m 512m --memory-swap=512m myapp

# Pin to CPU cores 0 and 1
docker run --cpuset-cpus="0,1" myapp

# Check current limits
docker inspect <ctr> | grep -E "Memory|Cpu"
```

### Restart Policies (--restart)

- **Why it exists** — Services should survive crashes and host reboots without manual intervention.
- **What it is** — The restart policy controls what Docker does when a container exits. Policies are set at `docker run` time and managed by the Docker daemon (not the OS init system).
- **One-liner** — `--restart` tells Docker whether and when to automatically restart a container.

| Policy | Behavior |
|---|---|
| `no` (default) | Never restart |
| `always` | Restart on any exit; also starts on daemon restart |
| `on-failure[:N]` | Restart only on non-zero exit; optional max retries |
| `unless-stopped` | Like `always` but does not start if manually stopped before daemon restart |

```bash
# Restart on crash, max 3 times
docker run --restart=on-failure:3 myapp

# Always restart (suitable for services)
docker run -d --restart=always nginx

# Check restart policy
docker inspect <ctr> --format '{{.HostConfig.RestartPolicy.Name}}'
```

### User, Read-Only, and Capabilities (--user / --read-only / --cap-drop)

- **Why it exists** — Containers run as root by default, which is dangerous; least-privilege reduces the blast radius of a container escape or compromise.
- **What it is** — `--user` sets the UID:GID the container process runs as, preventing root escalation. `--read-only` mounts the root filesystem read-only, preventing writes to the container layer. `--cap-drop` removes Linux capabilities from the process; `--cap-add` adds specific ones back. The canonical hardening pattern is `--cap-drop=ALL --cap-add=<only what is needed>`.
- **One-liner** — `--user`, `--read-only`, and `--cap-drop` implement least-privilege for a container.

```bash
# Run as non-root UID 1000
docker run --user 1000:1000 myapp

# Read-only root fs; writable tmpfs for /tmp
docker run --read-only --tmpfs /tmp myapp

# Drop all capabilities, add back only what is needed
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myapp

# Run with no capabilities at all (for purely compute workloads)
docker run --cap-drop=ALL myapp
```

### Network and DNS (--network / --dns)

- **Why it exists** — Different containers need different network isolation levels; some must share a network namespace with the host, others must be completely isolated or on a custom overlay.
- **What it is** — `--network` attaches the container to a network driver: `bridge` (default, isolated), `host` (shares host network namespace), `none` (no network), or a user-defined network name. `--dns` overrides the DNS server used inside the container. `--add-host` injects static entries into `/etc/hosts`. `--hostname` sets the container's hostname.
- **One-liner** — `--network` controls which network a container joins; `--dns` controls name resolution inside it.

```bash
# Attach to a user-defined bridge network
docker run --network my-net myapp

# Use host networking (no isolation; highest performance)
docker run --network host nginx

# Custom DNS
docker run --dns 8.8.8.8 myapp

# Static host entry
docker run --add-host=db:10.0.0.5 myapp
```

### Volumes and Mounts (-v / --mount / --tmpfs)

- **Why it exists** — Container filesystems are ephemeral; data written inside a container is lost when it is removed unless it is stored in a volume or bind mount.
- **What it is** — `-v host_path:container_path[:options]` is the shorthand for bind mounts and named volumes. `--mount` is the explicit, verbose form with `type=bind|volume|tmpfs`, `source`, and `target` keys — preferred in scripts for clarity. `--tmpfs path` mounts a temporary in-memory filesystem at the given path, which is fast and automatically cleaned up on exit.
- **One-liner** — `-v` and `--mount` persist or share data; `--tmpfs` provides fast ephemeral scratch space.

```bash
# Named volume (managed by Docker)
docker run -v mydata:/app/data myapp

# Bind mount (host directory into container)
docker run -v /host/config:/app/config:ro myapp

# Explicit --mount syntax (recommended in scripts)
docker run --mount type=bind,source=/host/config,target=/app/config,readonly myapp

# In-memory tmpfs for /tmp
docker run --tmpfs /tmp myapp

# List volumes
docker volume ls
```

### Entrypoint Override (--entrypoint)

- **Why it exists** — The image's default `ENTRYPOINT` may not be what is needed for debugging, testing, or alternative workflows; overriding it avoids rebuilding the image.
- **What it is** — `--entrypoint` replaces the `ENTRYPOINT` defined in the Dockerfile entirely. Any arguments after the image name become the new `CMD` passed to the overridden entrypoint. A common pattern is `--entrypoint sh` to open a shell inside a running image for debugging.
- **One-liner** — `--entrypoint` overrides the image's default startup command without rebuilding.

```bash
# Open a shell instead of the default entrypoint
docker run --rm -it --entrypoint sh myapp

# Run a different binary inside the image
docker run --rm --entrypoint printenv myapp

# Pass arguments to the overridden entrypoint
docker run --rm --entrypoint python myapp script.py
```

### Common Flags Summary

| Flag | Short | Purpose |
|---|---|---|
| `--detach` | `-d` | Run container in background |
| `--rm` | | Remove container automatically on exit |
| `--publish` | `-p` | Map host port to container port |
| `-P` | | Publish all EXPOSEd ports to random host ports |
| `--env` | `-e` | Set environment variable |
| `--env-file` | | Load environment variables from file |
| `--memory` | `-m` | Maximum RAM the container may use |
| `--cpus` | | Fraction of CPU cores available to container |
| `--restart` | | Restart policy (no/always/on-failure/unless-stopped) |
| `--name` | | Assign a name to the container |
| `--user` | `-u` | Run process as specified UID:GID |
| `--read-only` | | Mount root filesystem read-only |
| `--cap-drop` | | Remove Linux capability |
| `--cap-add` | | Add Linux capability |
| `--network` | | Connect container to a network |
| `--dns` | | Override DNS server inside container |
| `--volume` | `-v` | Bind mount or named volume |
| `--mount` | | Explicit mount (bind/volume/tmpfs) |
| `--tmpfs` | | Mount in-memory tmpfs at path |
| `--entrypoint` | | Override image ENTRYPOINT |
