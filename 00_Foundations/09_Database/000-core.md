# Database

- A database is an organized system for storing, retrieving, and managing data; relational databases use tables with rows and columns, while NoSQL databases use flexible models (documents, key-value, columnar).
- The database engine receives queries through client connections, parses and optimizes them, then reads/writes data to persistent storage on disk.
- DevOps engineers need database knowledge for provisioning, backup/restore, replication setup, access control, monitoring, and running databases in containers.

# Architecture

```text
+------------------+     +------------------+     +------------------+
|   Application    |     |   Application    |     |    Admin / DBA   |
|   (web app)      |     |   (API server)   |     |   (psql / mysql) |
+--------+---------+     +--------+---------+     +--------+---------+
         |                        |                        |
         +------------------------+------------------------+
                                  |
                        +---------v----------+
                        |  Connection Pool   |
                        |  / Wire Protocol   |
                        |  (port 3306/5432)  |
                        +---------+----------+
                                  |
                        +---------v----------+
                        |   Query Parser     |
                        |   + Optimizer      |
                        +---------+----------+
                                  |
                        +---------v----------+
                        |   Execution Engine |
                        +---------+----------+
                                  |
                   +--------------+--------------+
                   |                             |
          +--------v--------+          +--------v--------+
          |  Buffer Pool /  |          |  Transaction    |
          |  Shared Buffers |          |  Log (WAL/Redo) |
          +--------+--------+          +--------+--------+
                   |                             |
          +--------v--------+          +--------v--------+
          |   Data Files    |          |   Log Files     |
          |   (on disk)     |          |   (on disk)     |
          +-----------------+          +-----------------+
```

# Mental Model

```text
Typical DevOps database workflow:

  Deploy            Configure           Backup            Monitor           Scale
    |                  |                  |                  |                |
    v                  v                  v                  v                v
 Install DB       Set users/roles    Schedule dumps    Watch metrics     Add replicas
 (package/        Set listen addr    Test restore      Slow query log    Configure
  container)      Tune memory/       Off-site copy     Connection count  failover
                  connections                          Disk usage

Concrete example -- standing up PostgreSQL for a new service:

  1. Install   -->  apt install postgresql  (or docker run postgres:16)
  2. Configure -->  edit postgresql.conf (listen_addresses, shared_buffers)
                    edit pg_hba.conf (allow app subnet)
  3. Create    -->  CREATE DATABASE appdb; CREATE USER appuser WITH PASSWORD '...';
  4. Backup    -->  cron job: pg_dump appdb | gzip > /backup/appdb_$(date +%F).sql.gz
  5. Monitor   -->  check pg_stat_activity, replication lag, disk free
  6. Scale     -->  add streaming replica for read traffic
```

# Core Building Blocks

### Database Concepts

- Relational databases store data in tables with enforced schemas; NoSQL databases trade strict schema for flexibility and horizontal scaling.
- ACID properties (Atomicity, Consistency, Isolation, Durability) guarantee reliable transactions in relational systems.
- Indexes speed up reads at the cost of slower writes and extra disk space; choosing the right indexes is a key performance lever.

Related notes: [001-database-concepts](./001-database-concepts.md)

### SQL Essentials

- CRUD operations (INSERT, SELECT, UPDATE, DELETE) are the four fundamental data manipulation commands.
- JOINs combine rows from multiple tables; WHERE and HAVING filter results; ORDER BY and LIMIT control output.
- Understanding basic SQL lets DevOps engineers debug data issues, verify migrations, and write health-check queries.

Related notes: [002-sql-essentials](./002-sql-essentials.md)

### User and Access Management

- Authentication verifies identity (password, certificate, LDAP); authorization controls what a user can do (GRANT/REVOKE).
- Follow least-privilege: application users get only the permissions they need (SELECT, INSERT on specific tables).
- Host-based access control (pg_hba.conf for PostgreSQL, bind-address + user host for MySQL) restricts which IPs can connect.

Related notes: [003-user-and-access-management](./003-user-and-access-management.md)

### Backup and Restore

- Logical backups (pg_dump, mysqldump) export SQL statements; physical backups copy raw data files for faster restore of large databases.
- Every backup strategy must include tested restore procedures -- an untested backup is not a backup.
- Schedule backups with cron or systemd timers; store copies off-site (S3, GCS) with retention policies.

Related notes: [004-backup-and-restore](./004-backup-and-restore.md)

### Replication and High Availability

- Streaming replication sends write-ahead log (WAL) entries from primary to replica for near-real-time copies.
- Failover promotes a replica to primary when the original primary fails; tools like Patroni and orchestrators automate this.
- Read replicas offload SELECT queries from the primary, improving read throughput without changing the application write path.

Related notes: [005-replication-and-ha](./005-replication-and-ha.md)

### Monitoring and Troubleshooting

- Key metrics: active connections, queries per second, replication lag, cache hit ratio, disk usage.
- Slow query logs and EXPLAIN plans reveal inefficient queries that need indexing or rewriting.
- Connection storms, lock contention, and disk full are the top three operational emergencies.

Related notes: [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md)

### Database in Containers
Related notes: [007-database-in-containers](./007-database-in-containers.md)
- Run databases in containers for dev/test easily; production use requires careful volume management and backup strategy.
- Always mount data directories on named volumes or host paths -- container filesystems are ephemeral.
- Connection strings change in containerized environments; use service names (Docker Compose) or ClusterIP (Kubernetes) instead of localhost.

# Troubleshooting Guide

```text
Problem: cannot connect to database
    |
    v
[1] Service running?
    systemctl status postgresql / mysql
    |
    v
[2] Port listening?
    ss -tlnp | grep 5432   (or 3306)
    |
    v
[3] Firewall blocking?
    iptables -L -n / firewall-cmd --list-all
    |
    v
[4] Listen address correct?
    PostgreSQL: check listen_addresses in postgresql.conf
    MySQL: check bind-address in my.cnf
    |
    v
[5] Authentication allowed?
    PostgreSQL: check pg_hba.conf for client IP/method
    MySQL: check user host (SELECT user, host FROM mysql.user)
    |
    v
[6] Credentials correct?
    Test with: psql -h <host> -U <user> -d <db>
               mysql -h <host> -u <user> -p <db>
    |
    v
[7] Max connections reached?
    PostgreSQL: SELECT count(*) FROM pg_stat_activity;
    MySQL: SHOW STATUS LIKE 'Threads_connected';
```

# Topic Map

- [001-database-concepts](./001-database-concepts.md) -- relational model, NoSQL, ACID, indexes, schemas
- [002-sql-essentials](./002-sql-essentials.md) -- CRUD, joins, filtering, aggregation
- [003-user-and-access-management](./003-user-and-access-management.md) -- authentication, authorization, grants
- [004-backup-and-restore](./004-backup-and-restore.md) -- dump, restore, scheduling, off-site storage
- [005-replication-and-ha](./005-replication-and-ha.md) -- primary/replica, failover, read scaling
- [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md) -- metrics, slow queries, connection issues
- [007-database-in-containers](./007-database-in-containers.md) -- Docker, volumes, Kubernetes, connection strings
