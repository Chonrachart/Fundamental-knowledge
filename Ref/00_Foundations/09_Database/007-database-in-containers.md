# Database in Containers

- Containers make it trivial to spin up databases for development and testing; production use requires persistent volumes, backups, and careful resource management.
- Docker Compose handles multi-service setups (app + database) with named volumes; Kubernetes uses StatefulSets and PersistentVolumeClaims for stateful workloads.
- Connection strings differ in containerized environments -- use service names (Docker Compose) or Kubernetes service DNS instead of localhost or IP addresses.

# Architecture

```text
Docker: Container DB with Persistent Storage

+----------------------------------------------+
|              Docker Host                      |
|                                               |
|  +------------------+   +------------------+  |
|  |  App Container   |   |   DB Container   |  |
|  |  (web/api)       |   |  (mysql:8.0 or   |  |
|  |                  |   |   postgres:16)    |  |
|  |  connects to:    |   |                  |  |
|  |  db:5432         +-->|  port 5432/3306  |  |
|  +------------------+   +--------+---------+  |
|                                  |            |
|                          +-------v--------+   |
|                          | Named Volume   |   |
|                          | (pgdata or     |   |
|                          |  mysqldata)    |   |
+--------------------------|----------------+   |
                           |                    |
                  +--------v--------+           |
                  |  Host Disk /    |           |
                  |  /var/lib/docker|           |
                  |  /volumes/...  |           |
                  +-----------------+           |
+-----------------------------------------------+


Kubernetes: StatefulSet with PVC

+-----------------------------------------------------+
|  Kubernetes Cluster                                  |
|                                                      |
|  +------------------+     +----------------------+   |
|  | App Deployment   |     |  DB StatefulSet      |   |
|  | (replicas: 3)    |     |  (replicas: 1-3)     |   |
|  |                  |     |                      |   |
|  | connects to:     |     |  pod: db-0           |   |
|  | db-svc:5432      +---->|  pod: db-1 (replica) |   |
|  +------------------+     |  pod: db-2 (replica) |   |
|                           +----------+-----------+   |
|                                      |               |
|  +-------------------+    +----------v-----------+   |
|  | Headless Service  |    | PersistentVolumeClaim|   |
|  | db-svc            |    | (one per pod)        |   |
|  | (no ClusterIP)    |    +----------+-----------+   |
|  +-------------------+               |               |
|                            +---------v----------+    |
|                            | PersistentVolume   |    |
|                            | (cloud disk / NFS) |    |
|                            +--------------------+    |
+------------------------------------------------------+
```

# Mental Model

```text
Container DB Decision Tree:

  "Do I need a database?"
       |
       v
  What environment?
       |
       +-- Development / Testing
       |       |
       |       v
       |   Docker (or Docker Compose)
       |   - Quick to start/destroy
       |   - Use named volumes for data
       |   - docker compose up / down
       |
       +-- Small Production (single node)
       |       |
       |       v
       |   Docker + Volume + Backup
       |   - Named volume on reliable disk
       |   - Automated backup (cron + dump)
       |   - Monitor with exporter
       |   - Acceptable for low-traffic apps
       |
       +-- Large Production / Critical
               |
               v
           Managed Service or K8s Operator
           - RDS, Cloud SQL, Azure DB
           - Or: CloudNativePG, Percona Operator
           - Built-in HA, backups, monitoring
           - Worth the cost for critical data

Concrete example -- PostgreSQL in Docker Compose for development:

  1. Write docker-compose.yml with postgres service + named volume
  2. Set POSTGRES_PASSWORD, POSTGRES_DB in environment
  3. Mount init.sql to /docker-entrypoint-initdb.d/ for schema setup
  4. App connects to postgres://user:pass@db:5432/mydb
  5. docker compose up -d  -->  database ready in seconds
  6. docker compose down   -->  data persists in named volume
  7. docker compose down -v --> data destroyed (volumes removed)
```

# Core Building Blocks

### Docker Basics for Databases

- Official images on Docker Hub: `mysql`, `postgres`, `mariadb`, `redis`, `mongo`.
- Each image uses environment variables for initial configuration.
- Default ports must be mapped with `-p` to access from the host.

```bash
# run PostgreSQL
docker run -d --name pg \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  postgres:16

# run MySQL
docker run -d --name mysql \
  -e MYSQL_ROOT_PASSWORD=secret \
  -e MYSQL_DATABASE=mydb \
  -p 3306:3306 \
  mysql:8.0

# run Redis (no password by default)
docker run -d --name redis \
  -p 6379:6379 \
  redis:7

# run MongoDB
docker run -d --name mongo \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=secret \
  -p 27017:27017 \
  mongo:7

# connect to running database
docker exec -it pg psql -U postgres -d mydb
docker exec -it mysql mysql -u root -p mydb
```

Related notes: [000-core](./000-core.md), [003-user-and-access-management](./003-user-and-access-management.md)

### Data Persistence

- **Without a volume, all data is lost when the container is removed.** This is the number one mistake.
- **Named volumes** -- Docker manages storage location; best for most cases.
- **Bind mounts** -- map a specific host directory; useful when you need direct access to files.
- Never run a database in production without a persistent volume.

```bash
# named volume (recommended)
docker run -d --name pg \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

# bind mount (host directory)
docker run -d --name pg \
  -e POSTGRES_PASSWORD=secret \
  -v /srv/pgdata:/var/lib/postgresql/data \
  postgres:16

# list volumes
docker volume ls

# inspect a volume (see mount point on host)
docker volume inspect pgdata

# remove a volume (DESTROYS DATA)
docker volume rm pgdata

# data directory locations inside containers:
#   PostgreSQL:  /var/lib/postgresql/data
#   MySQL:       /var/lib/mysql
#   MongoDB:     /data/db
#   Redis:       /data
```

Related notes: [004-backup-and-restore](./004-backup-and-restore.md)
- **Rule of thumb:** if you would not enjoy being paged at 3 AM to debug a container storage issue, use a managed service.

### Docker Compose

- Define multi-service applications in a single YAML file.
- `depends_on` controls startup order; `healthcheck` ensures the database is ready before the app connects.
- Named volumes are declared in the top-level `volumes:` section.

```yaml
# docker-compose.yml
version: "3.8"

services:
  app:
    image: myapp:latest
    ports:
      - "8080:8080"
    environment:
      DATABASE_URL: "postgresql://appuser:secret@db:5432/mydb"
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: mydb
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U appuser -d mydb"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

```bash
# start all services
docker compose up -d

# check status
docker compose ps

# view database logs
docker compose logs db

# stop services (data persists)
docker compose down

# stop and destroy volumes (DATA LOSS)
docker compose down -v
```

Related notes: [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md)

### Init Scripts

- Mount `.sql`, `.sql.gz`, or `.sh` files to `/docker-entrypoint-initdb.d/` inside the container.
- Scripts run only on first startup (when the data directory is empty).
- Files execute in alphabetical order -- prefix with numbers for ordering.

```bash
# directory structure
./init-scripts/
  01-schema.sql       # CREATE TABLE statements
  02-seed-data.sql    # INSERT test data
  03-create-users.sh  # shell script for complex setup

# mount the directory
docker run -d --name pg \
  -e POSTGRES_PASSWORD=secret \
  -v ./init-scripts:/docker-entrypoint-initdb.d \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16
```

Related notes: [002-sql-essentials](./002-sql-essentials.md)

### Kubernetes Databases

- **StatefulSet** -- gives each pod a stable hostname (db-0, db-1, db-2) and persistent storage; required for databases.
- **PersistentVolumeClaim (PVC)** -- requests storage from the cluster; each StatefulSet replica gets its own PVC.
- **Headless Service** -- no ClusterIP; enables direct DNS to individual pods (db-0.db-svc.namespace.svc).
- **Operators** simplify database lifecycle management in Kubernetes:
  - CloudNativePG -- PostgreSQL operator (backup, HA, monitoring built-in).
  - MySQL Operator (Oracle) -- for MySQL InnoDB Cluster.
  - Percona Operator -- for MySQL, PostgreSQL, and MongoDB.

```yaml
# headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: db-svc
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
    - port: 5432

---
# statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
spec:
  serviceName: db-svc
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-secret
                  key: password
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

Related notes: [005-replication-and-ha](./005-replication-and-ha.md)
- **When containers make sense for production:**
  - Team has strong Kubernetes expertise.
  - Using a mature operator (CloudNativePG, Percona).
  - Compliance requires on-premises deployment.
  - Small, non-critical databases with proper volume and backup setup.

### Connection Strings

- Format varies by database engine; the host portion changes depending on environment.
- In Docker Compose, the host is the service name (e.g., `db`).
- In Kubernetes, the host is `service-name.namespace.svc.cluster.local`.

```text
Connection String Formats:

  PostgreSQL:
    postgresql://user:password@host:5432/dbname
    postgresql://user:password@host:5432/dbname?sslmode=require

  MySQL:
    mysql://user:password@host:3306/dbname
    user:password@tcp(host:3306)/dbname        # Go driver format

  MongoDB:
    mongodb://user:password@host:27017/dbname?authSource=admin
    mongodb://user:password@host1:27017,host2:27017/dbname?replicaSet=rs0

Host Resolution by Environment:

  Docker Compose:
    host = service name from docker-compose.yml
    example: postgresql://appuser:secret@db:5432/mydb

  Kubernetes:
    host = <service>.<namespace>.svc.cluster.local
    example: postgresql://appuser:secret@db-svc.default.svc.cluster.local:5432/mydb
    short form (same namespace): db-svc:5432

  StatefulSet individual pods:
    host = <pod>.<service>.<namespace>.svc.cluster.local
    example: db-0.db-svc.default.svc.cluster.local
```

Related notes: [001-database-concepts](./001-database-concepts.md)

### When NOT to Containerize
Related notes: [004-backup-and-restore](./004-backup-and-restore.md), [005-replication-and-ha](./005-replication-and-ha.md)
- **Large production databases** -- managing HA, backups, upgrades, and performance tuning in containers adds complexity with little benefit over managed services.
- **Managed services are usually better for production:**
  - AWS RDS / Aurora (MySQL, PostgreSQL)
  - Google Cloud SQL (MySQL, PostgreSQL)
  - Azure Database for PostgreSQL / MySQL
  - Automated backups, patching, failover, monitoring included.
