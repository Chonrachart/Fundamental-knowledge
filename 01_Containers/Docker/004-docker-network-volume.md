# Docker Networking and Volumes

# Overview

- **Why it exists** — Containers are isolated by default; networking modes and volume types give you precise control over how containers communicate with each other, the host, and the outside world, and how data persists beyond a container's lifetime.
- **What it is** — Docker networking provides several drivers (bridge, host, none, user-defined) that determine how a container's network namespace connects to the host or other containers. Docker volumes provide three storage types (named volume, bind mount, tmpfs) that determine where and how data lives.
- **One-liner** — Networking controls who a container can talk to; volumes control where a container's data lives.

# Architecture

```text
┌────────────────────────────────────────────────────────────────────┐
│                          Docker Host                               │
│                                                                    │
│  ┌──────────────────────┐   ┌──────────────────────────────────┐  │
│  │   Default Bridge     │   │       User-Defined Bridge        │  │
│  │   (docker0)          │   │       (my-network)               │  │
│  │                      │   │                                  │  │
│  │ 172.17.0.1 (gateway) │   │ Automatic DNS by container name  │  │
│  │  ┌────┐  ┌────┐      │   │  ┌────────┐  ┌────────┐         │  │
│  │  │ C1 │  │ C2 │      │   │  │  web   │  │   db   │         │  │
│  │  └────┘  └────┘      │   │  └────────┘  └────────┘         │  │
│  │  no DNS by name      │   │  ping db ──▶ resolved by DNS     │  │
│  └──────────────────────┘   └──────────────────────────────────┘  │
│                                                                    │
│  ┌──────────────────────┐   ┌──────────────────────────────────┐  │
│  │   Host Network       │   │       None Network               │  │
│  │                      │   │                                  │  │
│  │  Container shares    │   │  Loopback only (lo)              │  │
│  │  host network stack  │   │  No external connectivity        │  │
│  │  No port mapping     │   │  Maximum isolation               │  │
│  │  needed              │   │                                  │  │
│  └──────────────────────┘   └──────────────────────────────────┘  │
│                                                                    │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                        Volumes                                │ │
│  │                                                               │ │
│  │  Named Volume            Bind Mount           tmpfs           │ │
│  │  /var/lib/docker/    ◄── /host/path       ── RAM only        │ │
│  │  volumes/myvol/          mounted into         lost on stop   │ │
│  │  managed by Docker       container            no disk write  │ │
│  └───────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

# Mental Model

```text
Container starts
      │
      ▼
What network driver?
      │
      ├──▶ bridge (default) ──▶ docker0 virtual switch, NAT to host NIC
      │                          port mapping with -p host:container
      │
      ├──▶ user-defined ──────▶ same virtual switch model BUT
      │                          containers resolve each other by name
      │                          via Docker's embedded DNS (127.0.0.11)
      │
      ├──▶ host ──────────────▶ container uses host's eth0 directly
      │                          no isolation, no port mapping needed
      │
      └──▶ none ──────────────▶ only loopback, fully air-gapped


Container writes data
      │
      ▼
What volume type?
      │
      ├──▶ named volume ──▶ Docker manages path, survives container delete
      │
      ├──▶ bind mount ───▶ you choose host path, live sync for dev
      │
      └──▶ tmpfs ─────────▶ in RAM, never hits disk, lost on stop
```

- Default bridge uses IP-only communication; no automatic hostname resolution between containers.
- User-defined networks add embedded DNS so containers talk by name (`ping db` instead of `ping 172.17.0.3`).
- Host mode removes the network namespace entirely — useful for performance-sensitive workloads, dangerous for multi-tenant environments.
- Named volumes survive `docker rm`; bind mounts are just a directory on the host — Docker does not manage them.
- `-p 8080:80` means "listen on host port 8080, forward to container port 80".

# Core Building Blocks

### Bridge Network (Default)

- **Why it exists** — Containers need outbound internet access and optional inbound access via port mapping without sharing the host's network namespace.
- **What it is** — Docker creates a virtual switch called `docker0` on the host. Each container gets a `veth` pair: one end in the container's namespace, one end attached to `docker0`. NAT (via iptables masquerade) gives containers outbound internet access. Containers on the default bridge can only reach each other by IP, not by name.
- **One-liner** — The default bridge is an isolated virtual switch with NAT, accessed from outside via explicit port mapping.

```bash
# Run a container on the default bridge and expose port 80
docker run -d -p 8080:80 nginx

# Inspect which bridge a container is on
docker inspect <container> --format '{{.NetworkSettings.Networks}}'

# See docker0 interface on host
ip addr show docker0
```

### User-Defined Bridge Network

- **Why it exists** — Services in the same application need to discover each other by name, not by IP, because IPs change every time a container restarts.
- **What it is** — A custom bridge network created with `docker network create`. Docker's embedded DNS server (127.0.0.11) resolves container names and network-scoped aliases automatically. Containers on different user-defined networks are fully isolated from each other even on the same host.
- **One-liner** — User-defined bridges give containers automatic DNS-based discovery within an application.

```bash
# Create a named network
docker network create my-app

# Attach containers — they can now reach each other by name
docker run -d --name db  --network my-app postgres
docker run -d --name web --network my-app nginx

# Inside web: DNS resolves "db" automatically
docker exec web ping db

# Connect a running container to an additional network
docker network connect my-app <existing-container>
```

| Feature               | Default Bridge | User-Defined Bridge |
|-----------------------|----------------|---------------------|
| DNS by container name | No             | Yes                 |
| Isolation             | Shared         | Per network         |
| `--link` needed       | Yes (legacy)   | No                  |
| Recommended           | No             | Yes                 |

### Host Network

- **Why it exists** — Some workloads need maximum network performance or must bind to specific host ports without NAT overhead (e.g., monitoring agents, network tools).
- **What it is** — The container shares the host's network namespace completely. There is no virtual interface, no NAT, and no port mapping — the container's processes bind directly to the host's NIC. Only works on Linux; ignored on Docker Desktop (macOS/Windows).
- **One-liner** — Host mode removes network isolation entirely so the container and host share the same network stack.

```bash
# Run on host network — no -p needed, nginx binds directly to host :80
docker run -d --network host nginx

# Verify — container ports appear as host ports
ss -tlnp | grep :80
```

### None Network

- **Why it exists** — Batch jobs, cryptographic operations, or security-sensitive workloads need to run with zero network exposure.
- **What it is** — Docker creates the network namespace but only adds the loopback interface (`lo`). No `veth`, no external connectivity whatsoever. The container cannot reach the internet, the host, or any other container.
- **One-liner** — None mode creates a fully air-gapped container with only localhost.

```bash
docker run --network none alpine ping google.com
# ping: bad address 'google.com'  (no connectivity)
```

### Port Mapping (-p)

- **Why it exists** — Containers on bridge networks are on an internal subnet; external clients cannot reach them without an explicit rule mapping a host port to a container port.
- **What it is** — The `-p` flag instructs Docker to add an iptables DNAT rule forwarding traffic arriving on a host port to the container's IP and port. Multiple `-p` flags map multiple ports. `-P` publishes all `EXPOSE`d ports to random host ports.
- **One-liner** — `-p host_port:container_port` punches a hole from the host into the container.

```bash
# Map host 8080 → container 80
docker run -p 8080:80 nginx

# Bind to a specific host IP (loopback only — not reachable externally)
docker run -p 127.0.0.1:8080:80 nginx

# Publish all EXPOSE'd ports to random host ports
docker run -P nginx

# See all active port mappings for a container
docker port <container>
```

### Named Volume

- **Why it exists** — Application data (databases, uploads, logs) must survive container restarts, upgrades, and even `docker rm` without the developer managing host paths manually.
- **What it is** — Docker manages the storage location (`/var/lib/docker/volumes/<name>/_data` on Linux). The volume lifecycle is independent of the container — it persists until explicitly removed with `docker volume rm`. Volume drivers allow mounting remote storage (NFS, cloud block storage) transparently.
- **One-liner** — A named volume is Docker-managed persistent storage that outlives its container.

```bash
# Create and use a named volume inline
docker run -v pgdata:/var/lib/postgresql/data postgres

# Explicitly create, then use
docker volume create pgdata
docker run -v pgdata:/var/lib/postgresql/data postgres

# Inspect where data lives on the host
docker volume inspect pgdata

# Remove all unused volumes
docker volume prune
```

### Bind Mount

- **Why it exists** — Developers need to inject local source code or config files into a container at runtime without rebuilding the image.
- **What it is** — A host path is mounted directly into the container. Docker does not manage the lifecycle — you own both the host directory and its cleanup. Changes on the host are immediately visible in the container and vice versa. Requires an absolute path on the host.
- **One-liner** — A bind mount maps an exact host filesystem path into a container for live, bidirectional access.

```bash
# Mount current source directory into container for live development
docker run -v "$(pwd)/src":/app/src node:18 npm run dev

# Read-only bind mount (container cannot write back)
docker run -v "$(pwd)/config":/etc/myapp:ro myapp

# Using --mount syntax (more explicit, preferred in scripts)
docker run --mount type=bind,source="$(pwd)/data",target=/data myapp
```

### tmpfs Mount

- **Why it exists** — Sensitive data (tokens, session keys) or ephemeral scratch space should never be written to disk, even inside a named volume.
- **What it is** — Storage allocated in the host's RAM and mounted into the container. It never touches disk, is not visible to other containers, and is destroyed when the container stops. Size can be capped with `tmpfs-size`.
- **One-liner** — tmpfs is an in-memory mount that guarantees data never reaches disk and disappears on container stop.

```bash
# Mount a tmpfs at /tmp inside the container (64 MB cap)
docker run --tmpfs /tmp:size=64m myapp

# Using --mount syntax
docker run --mount type=tmpfs,destination=/tmp,tmpfs-size=67108864 myapp
```
