# docker run -- Advanced

- `docker run` creates a new container from an image and starts it with configurable options.
- Syntax: `docker run [OPTIONS] IMAGE [COMMAND] [ARG...]`
- Flags control ports, env vars, resource limits, restart policies, volumes, user, and network.

# Core Building Blocks

### Detach vs Foreground

- `-d, --detach`: Run in background; returns container ID; logs not shown.
- Without `-d`: runs in foreground; Ctrl+C stops container (unless `--sig-proxy=false`); logs to terminal.
- `--rm`: Automatically remove container when it exits; useful for one-off runs.
- `-d` runs detached; `--rm` auto-removes on exit; combine for one-off background tasks.

```bash
docker run -d --name web nginx:alpine
docker run --rm alpine echo "hello"
```

### Publish Ports (-p, -P)

- `-p host_port:container_port`: Map host port to container port; multiple `-p` allowed.
- `-p 8080:80`: Host 8080 maps to container 80; access via `localhost:8080`.
- `-p 127.0.0.1:8080:80`: Bind only to localhost (not all interfaces).
- `-p 80`: Random host port maps to container 80; see with `docker port`.
- **-P**: Publish all ports declared in `EXPOSE` to random host ports.
- `-p 127.0.0.1:8080:80` binds only to localhost; `-p 8080:80` binds to all interfaces.

Related notes:
- [004-docker-network-volume](./004-docker-network-volume.md)

### Environment Variables (-e, --env-file)

- `-e KEY=value`: Set env var in container; multiple `-e` allowed.
- `--env-file path`: Read `KEY=value` lines from file; one var per line.
- Override image `ENV`; used for config (DB host, API key, etc.).

```bash
docker run -e DB_HOST=db -e DB_PASS=secret myapp
docker run --env-file .env myapp
```

### Memory and CPU Limits

- `--memory, -m`: Max memory (e.g. `512m`, `1g`); container can be OOM-killed if exceeded.
- `--memory-swap`: Total memory + swap; set to same as `--memory` to disable swap.
- `--cpus`: Cap CPU (e.g. `1.5` = 1.5 cores); `--cpu-shares`: Relative weight (default 1024).
- `--cpuset-cpus`: Pin to specific CPU cores (e.g. `0-3`).
- `-m 512m` sets memory limit; `--cpus=1.5` limits to 1.5 CPU cores.

```bash
docker run -m 512m --cpus=0.5 myapp
```

### Restart Policy (--restart)

- **no** (default): Do not restart.
- **always**: Always restart; on daemon restart, container starts too.
- **on-failure**: Restart only if exit code non-zero; optional max count: `on-failure:3`.
- **unless-stopped**: Like always, but do not start after stop if daemon restarted.
- Restart policies: `no`, `always`, `on-failure[:max]`, `unless-stopped`.

### User and Capabilities

- `--user, -u`: Run as user (e.g. `1000:1000` or `www-data`); container may need writable dirs.
- `--read-only`: Mount root filesystem read-only; use tmpfs or volumes for writable paths.
- `--cap-add, --cap-drop`: Add or drop Linux capabilities; drop all then add minimal: `--cap-drop=ALL --cap-add=NET_BIND_SERVICE`.
- `--cap-drop=ALL --cap-add=<needed>` follows least-privilege principle.
- `--read-only` makes root filesystem immutable; use with `--tmpfs` and volumes.

Related notes:
- [008-security-user-best-practices](./008-security-user-best-practices.md)

### Network and DNS

- `--network`: Attach to network (bridge, host, none, or user-defined name).
- `--dns`: DNS server inside container (e.g. `8.8.8.8`).
- `--add-host`: Add line to `/etc/hosts` (e.g. `--add-host=db:10.0.0.5`).
- `--hostname`: Set container hostname.

### Volume and Mount

- `-v, --volume`: Bind mount or named volume; `host_path:container_path[:options]`.
- `:ro`: Read-only in container.
- `--mount`: More explicit; `type=bind|volume|tmpfs`, source, target, and options.
- `--tmpfs`: Mount tmpfs at path (e.g. `--tmpfs /tmp`).

### Entrypoint and Command Override

- `--entrypoint`: Override image ENTRYPOINT; useful for debug (e.g. `--entrypoint sh`).
- Args after image name override CMD; combined with ENTRYPOINT: `docker run myimg arg1` means ENTRYPOINT receives arg1.
- `--entrypoint sh` overrides ENTRYPOINT for debugging.

### Common Flags Summary

| Flag | Short | Purpose |
|------|--------|---------|
| --detach | -d | Run in background |
| --publish | -p | Port mapping |
| --env | -e | Environment variable |
| --volume | -v | Mount volume |
| --memory | -m | Memory limit |
| --restart | | Restart policy |
| --name | | Container name |
| --rm | | Remove when exit |
| --user | -u | Run as user |
| --network | | Attach network |
| --entrypoint | | Override entrypoint |

Related notes:
- [004-docker-network-volume](./004-docker-network-volume.md)
- [008-security-user-best-practices](./008-security-user-best-practices.md)

---

# Troubleshooting Guide

### Container OOM killed
1. Check: `docker inspect <ctr> | grep OOMKilled`.
2. Increase memory limit: `-m 1g`.
3. Profile app memory usage; fix leaks.

### Container keeps restarting
1. Check restart policy: `docker inspect <ctr> --format '{{.HostConfig.RestartPolicy.Name}}'`.
2. Check logs for crash reason: `docker logs --tail 50 <ctr>`.
3. Use `on-failure:3` to limit retries instead of `always`.

### Environment variables not set inside container
1. Verify: `docker exec <ctr> env | grep <VAR>`.
2. Check `-e` syntax: `-e KEY=value` (no spaces around `=`).
3. Check `--env-file` format: one `KEY=value` per line, no quotes needed.
