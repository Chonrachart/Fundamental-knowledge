network
volume
bind mount
driver
bridge

---

# Docker Networking

- Each container has its own network namespace; can attach to one or more networks.
- **bridge** (default): Private network on host; containers get IPs; port mapping to reach from host.
- **host**: Container shares host network; no isolation.
- **none**: No network.
- **user-defined**: Create with `docker network create`; attach containers; DNS by container name.

```bash
docker network create mynet
docker run -d --network mynet --name web nginx
docker run -d --network mynet --name app myapp
# app can resolve "web"
```

# Port Mapping

- `-p 8080:80` — host port 8080 → container port 80.
- `-P` — publish all EXPOSE'd ports to random host ports.
- Without publish, container is only reachable from same network (other containers).

# Volume

- Persist data outside container lifecycle; survive container remove.
- **Named volume**: Managed by Docker; `docker volume create` or declare in compose; good for DB data.
- **Bind mount**: Host path mounted in container; `-v /host/path:/container/path`; good for config or dev source.
- **tmpfs**: In-memory; `--tmpfs /tmp`; no disk.

```bash
docker run -v mydata:/var/lib/app myimg
docker run -v $(pwd)/config:/app/config:ro myimg
```

# Volume Drivers

- Default local driver stores data in Docker area (e.g. `/var/lib/docker/volumes/`).
- Other drivers: NFS, cloud (e.g. AWS EBS), plugins; specify in `docker volume create --driver`.

# Read-Only and Permissions

- Bind mount: `:ro` for read-only in container.
- File ownership in container follows container user; host path permissions apply on host.
