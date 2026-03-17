# Monitoring and Troubleshooting

- Database monitoring tracks connections, query performance, disk usage, replication lag, and cache efficiency to catch problems before they cause outages.
- MySQL and PostgreSQL expose internal statistics through system views and status commands; external tools (Prometheus + Grafana) provide dashboards and alerting.
- Most operational emergencies come down to five things: too many connections, long-running queries, lock contention, disk full, or replication lag.

# Architecture

```text
Monitoring Stack:

+------------------+     +------------------+     +------------------+
|   MySQL          |     |   PostgreSQL     |     |   Other DBs      |
|   (port 3306)    |     |   (port 5432)    |     |   (Redis, Mongo) |
+--------+---------+     +--------+---------+     +--------+---------+
         |                        |                        |
         v                        v                        v
+------------------+     +------------------+     +------------------+
|  mysqld_exporter |     | postgres_exporter|     |  redis_exporter  |
|  (port 9104)     |     |  (port 9187)     |     |  (port 9121)     |
+--------+---------+     +--------+---------+     +--------+---------+
         |                        |                        |
         +------------------------+------------------------+
                                  |
                        +---------v----------+
                        |    Prometheus      |
                        |  (scrape metrics)  |
                        |  (port 9090)       |
                        +---------+----------+
                                  |
                   +--------------+--------------+
                   |                             |
          +--------v--------+          +--------v--------+
          |    Grafana       |          |   Alertmanager  |
          |  (dashboards)    |          |  (Slack/email/  |
          |  (port 3000)     |          |   PagerDuty)    |
          +-----------------+          +-----------------+
```

# Mental Model

```text
Database Health Check Workflow:

  [1] Connections       [2] Queries          [3] Disk             [4] Replication    [5] Locks
      |                     |                    |                    |                  |
      v                     v                    v                    v                  v
  Active count?         Slow queries?        Data dir size?       Lag in seconds?    Blocked
  Near max_conn?        Long-running?        WAL/binlog size?     Replica connected? queries?
  Idle connections?     Missing indexes?     Tablespace full?     Bytes behind?      Deadlocks?
      |                     |                    |                    |                  |
      v                     v                    v                    v                  v
  Tune pool size        Add indexes          Expand disk /        Fix network /      Kill or
  or kill idle          Kill bad queries     purge old WAL        tune wal_keep      investigate
  connections           Enable slow log      Archive logs         Check apply lag    lock waits

Concrete example -- investigating a slow application:

  1. Check connections  -->  SELECT count(*) FROM pg_stat_activity;
                             too many idle? --> app not closing connections
  2. Find slow queries  -->  SELECT pid, duration, query FROM pg_stat_activity
                             WHERE state = 'active' ORDER BY duration DESC;
  3. Explain the query  -->  EXPLAIN ANALYZE SELECT ... ;
                             Seq Scan on large table? --> missing index
  4. Check disk         -->  df -h /var/lib/postgresql
                             WAL piling up? --> check archiving or replication
  5. Check replication  -->  SELECT * FROM pg_stat_replication;
                             replay_lag growing? --> replica overloaded
```

# Core Building Blocks

### Key Metrics to Monitor

- **Active connections** -- how many clients are connected and running queries right now.
- **Max connections** -- the configured limit; hitting it means new connections are refused.
- **Idle connections** -- connected but doing nothing; too many waste memory and connection slots.
- **Slow queries** -- queries exceeding a threshold (e.g., 1 second); the top cause of user-facing latency.
- **Queries per second (QPS)** -- overall throughput; sudden drops or spikes signal problems.
- **Cache/buffer hit ratio** -- percentage of reads served from memory; below 95% means too many disk reads.
- **Replication lag** -- delay between primary write and replica apply; stale reads if too high.
- **Disk usage** -- data directory size, WAL/binlog accumulation, free space on the volume.
- **Lock waits / deadlocks** -- queries blocked waiting for locks; deadlocks are auto-resolved but indicate contention.

Related notes: [005-replication-and-ha](./005-replication-and-ha.md)

### MySQL Monitoring

- `SHOW PROCESSLIST` -- see all active connections, their state, and running queries.
- `SHOW GLOBAL STATUS` -- server-wide counters (connections, queries, threads, bytes sent/received).
- `SHOW VARIABLES` -- current configuration values (max_connections, innodb_buffer_pool_size).
- **Slow query log** -- enable with `slow_query_log = 1` and `long_query_time = 1` in my.cnf.
- `information_schema.TABLES` -- query for table and database sizes.
- `EXPLAIN` -- shows query execution plan; look for type=ALL (full table scan) as a warning sign.

```sql
-- check active connections
SHOW PROCESSLIST;

-- how many connections vs max
SHOW GLOBAL STATUS LIKE 'Threads_connected';
SHOW VARIABLES LIKE 'max_connections';

-- database sizes
SELECT table_schema AS db,
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.TABLES
GROUP BY table_schema
ORDER BY size_mb DESC;

-- table sizes in a specific database
SELECT table_name,
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.TABLES
WHERE table_schema = 'mydb'
ORDER BY size_mb DESC;

-- InnoDB buffer pool hit ratio
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';
-- hit ratio = 1 - (Innodb_buffer_pool_reads / Innodb_buffer_pool_read_requests) * 100

-- enable slow query log at runtime
SET GLOBAL slow_query_log = 1;
SET GLOBAL long_query_time = 1;

-- check query execution plan
EXPLAIN SELECT * FROM orders WHERE customer_id = 42;
-- look for: type=ALL (bad), type=ref or type=const (good)
```

Related notes: [002-sql-essentials](./002-sql-essentials.md), [003-user-and-access-management](./003-user-and-access-management.md)

### PostgreSQL Monitoring

- `pg_stat_activity` -- shows all current connections, their state (active/idle), and running queries.
- `pg_stat_user_tables` -- per-table stats: sequential scans, index scans, live/dead tuples (vacuum needed?).
- `pg_stat_replication` -- replication status: connected replicas, lag in bytes and time.
- `pg_locks` -- current locks held and waiting; join with pg_stat_activity to find blockers.
- **Slow query log** -- set `log_min_duration_statement = 1000` (ms) in postgresql.conf.
- `EXPLAIN ANALYZE` -- runs the query and shows actual execution time and row counts per step.

```sql
-- active connections by state
SELECT state, count(*)
FROM pg_stat_activity
GROUP BY state;

-- connections vs max
SELECT count(*) AS current, setting::int AS max
FROM pg_stat_activity, pg_settings
WHERE pg_settings.name = 'max_connections'
GROUP BY setting;

-- find long-running queries (> 5 minutes)
SELECT pid, now() - query_start AS duration, state, query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '5 minutes'
ORDER BY duration DESC;

-- database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database
ORDER BY pg_database_size(datname) DESC;

-- table sizes (top 10)
SELECT relname AS table,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;

-- cache hit ratio (should be > 0.95)
SELECT round(sum(blks_hit) / nullif(sum(blks_hit + blks_read), 0), 4) AS cache_hit_ratio
FROM pg_stat_database;

-- tables needing vacuum (high dead tuple ratio)
SELECT relname, n_dead_tup, n_live_tup,
       round(n_dead_tup::numeric / nullif(n_live_tup, 0), 4) AS dead_ratio
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY dead_ratio DESC;

-- replication status
SELECT client_addr, state, sent_lsn, replay_lsn,
       sent_lsn - replay_lsn AS byte_lag
FROM pg_stat_replication;

-- find blocked queries (waiting for locks)
SELECT blocked.pid AS blocked_pid,
       blocked.query AS blocked_query,
       blocking.pid AS blocking_pid,
       blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks ON blocked.pid = blocked_locks.pid
JOIN pg_locks blocking_locks ON blocked_locks.locktype = blocking_locks.locktype
  AND blocked_locks.relation = blocking_locks.relation
  AND blocked_locks.pid != blocking_locks.pid
JOIN pg_stat_activity blocking ON blocking_locks.pid = blocking.pid
WHERE NOT blocked_locks.granted;

-- query execution plan with actual timing
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;
-- look for: Seq Scan (bad on large tables), Index Scan (good)
```

Related notes: [002-sql-essentials](./002-sql-essentials.md), [005-replication-and-ha](./005-replication-and-ha.md)

### External Monitoring Tools

- **Prometheus + Grafana** -- the standard open-source monitoring stack for databases.
  - `mysqld_exporter` (port 9104) -- exports MySQL metrics to Prometheus.
  - `postgres_exporter` (port 9187) -- exports PostgreSQL metrics to Prometheus.
  - Grafana dashboards: use community dashboards (ID 7362 for MySQL, 9628 for PostgreSQL).
- **Zabbix** -- agent-based monitoring with built-in database templates; good for traditional infra.
- **What to alert on:**
  - Connection usage > 80% of max_connections
  - Replication lag > 30 seconds
  - Disk usage > 85% on data volume
  - Slow query count spike (> N per minute)
  - Database down (port not responding)
  - Cache hit ratio < 95%
  - Deadlocks detected

```bash
# run postgres_exporter
export DATA_SOURCE_NAME="postgresql://user:pass@localhost:5432/postgres?sslmode=disable"
./postgres_exporter

# run mysqld_exporter
export DATA_SOURCE_NAME="user:pass@(localhost:3306)/"
./mysqld_exporter

# verify exporter is serving metrics
curl -s http://localhost:9187/metrics | head -20   # postgres
curl -s http://localhost:9104/metrics | head -20   # mysql
```

Related notes: [000-core](./000-core.md)

### Common Issues and Fixes

- **Too many connections** -- app not closing connections or no connection pooler; fix: use PgBouncer/ProxySQL, increase max_connections as a short-term fix, fix app connection leaks.
- **Long-running queries** -- missing index or bad query plan; fix: EXPLAIN the query, add indexes, set statement_timeout.
- **Table locks / deadlocks** -- concurrent writes to same rows; fix: keep transactions short, access tables in consistent order, kill blocking queries if stuck.
- **Disk full** -- WAL/binlog not cleaned, tables not vacuumed, large temp files; fix: archive or remove old WAL, run VACUUM FULL, extend volume.
- **Replication lag** -- replica too slow (CPU/IO) or network issues; fix: check replica resources, tune wal_keep_size, check network latency.

```bash
# kill a problematic query (PostgreSQL)
SELECT pg_terminate_backend(<pid>);

# kill a problematic query (MySQL)
KILL <thread_id>;

# emergency: set statement timeout to prevent runaway queries (PostgreSQL)
ALTER SYSTEM SET statement_timeout = '60s';
SELECT pg_reload_conf();

# check and reclaim disk space (PostgreSQL)
VACUUM FULL <table_name>;

# purge old binary logs (MySQL)
PURGE BINARY LOGS BEFORE NOW() - INTERVAL 3 DAY;
```

Related notes: [004-backup-and-restore](./004-backup-and-restore.md)

### EXPLAIN Output Reading

- EXPLAIN shows the query plan the database will use; EXPLAIN ANALYZE also runs it and shows actual times.
- **Seq Scan** (sequential scan) -- reads every row in the table; fine for small tables, bad for large ones.
- **Index Scan** -- uses an index to find rows; much faster on large tables with selective WHERE clauses.
- **Index Only Scan** -- all needed columns are in the index; fastest read path.
- **Nested Loop / Hash Join / Merge Join** -- how tables are joined; each suits different data sizes.
- **Cost** -- estimated startup and total cost (arbitrary units); lower is better.
- **Rows** -- estimated number of rows; if wildly wrong, run ANALYZE to update statistics.

```text
PostgreSQL EXPLAIN output example:

  EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 42;

  Seq Scan on orders  (cost=0.00..1520.00 rows=5 width=64)
    (actual time=12.5..45.2 rows=5 loops=1)
    Filter: (customer_id = 42)
    Rows Removed by Filter: 99995
  Planning Time: 0.1 ms
  Execution Time: 45.3 ms

  Problem: Seq Scan on 100K rows to find 5 matches
  Fix:     CREATE INDEX idx_orders_customer_id ON orders(customer_id);

  After index:
  Index Scan using idx_orders_customer_id on orders  (cost=0.29..8.31 rows=5 width=64)
    (actual time=0.03..0.05 rows=5 loops=1)
    Index Cond: (customer_id = 42)
  Planning Time: 0.1 ms
  Execution Time: 0.07 ms
```

Related notes: [002-sql-essentials](./002-sql-essentials.md), [001-database-concepts](./001-database-concepts.md)

---

# Practical Command Set (Core)

```bash
# --- PostgreSQL Monitoring ---

# check active connections count
psql -c "SELECT state, count(*) FROM pg_stat_activity GROUP BY state;"

# find queries running longer than 5 minutes
psql -c "SELECT pid, now()-query_start AS duration, query FROM pg_stat_activity WHERE state='active' AND now()-query_start > interval '5 min';"

# database sizes
psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database ORDER BY pg_database_size(datname) DESC;"

# cache hit ratio
psql -c "SELECT round(sum(blks_hit)/nullif(sum(blks_hit+blks_read),0),4) AS ratio FROM pg_stat_database;"

# replication lag
psql -c "SELECT client_addr, state, replay_lag FROM pg_stat_replication;"

# kill a runaway query
psql -c "SELECT pg_terminate_backend(<pid>);"

# --- MySQL Monitoring ---

# check active connections
mysql -e "SHOW PROCESSLIST;"

# connection count vs max
mysql -e "SHOW GLOBAL STATUS LIKE 'Threads_connected'; SHOW VARIABLES LIKE 'max_connections';"

# database sizes
mysql -e "SELECT table_schema, ROUND(SUM(data_length+index_length)/1024/1024,2) AS size_mb FROM information_schema.TABLES GROUP BY table_schema ORDER BY size_mb DESC;"

# InnoDB buffer pool usage
mysql -e "SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool%';"

# kill a runaway query
mysql -e "KILL <thread_id>;"

# --- External Checks ---

# check database port is responding
nc -zv <host> 5432   # PostgreSQL
nc -zv <host> 3306   # MySQL

# check disk usage on data directory
df -h /var/lib/postgresql   # PostgreSQL
df -h /var/lib/mysql        # MySQL
```

# Troubleshooting Guide

```text
Problem: application reports slow database queries
    |
    v
[1] Check connection count
    PostgreSQL: SELECT count(*) FROM pg_stat_activity;
    MySQL: SHOW STATUS LIKE 'Threads_connected';
    |
    +-- near max_connections --> increase limit or add connection pooler
    |
    v
[2] Find slow / long-running queries
    PostgreSQL: SELECT pid, duration, query FROM pg_stat_activity WHERE state='active';
    MySQL: SHOW PROCESSLIST;
    |
    +-- long-running query found --> EXPLAIN it (step 3)
    +-- no obvious slow query --> check disk and replication (step 4)
    |
    v
[3] EXPLAIN the slow query
    EXPLAIN ANALYZE <query>;
    |
    +-- Seq Scan on large table --> CREATE INDEX on filter/join columns
    +-- many rows removed by filter --> WHERE clause not selective, review query
    +-- bad row estimates --> run ANALYZE <table> to update statistics
    |
    v
[4] Check disk usage
    df -h /var/lib/postgresql   (or /var/lib/mysql)
    |
    +-- disk > 90% full --> extend volume, purge old WAL/binlog, VACUUM FULL
    |
    v
[5] Check replication lag
    PostgreSQL: SELECT replay_lag FROM pg_stat_replication;
    MySQL: SHOW REPLICA STATUS\G  (look for Seconds_Behind_Source)
    |
    +-- lag growing --> check replica CPU/IO, network, wal_keep_size
    |
    v
[6] Check for lock contention
    PostgreSQL: SELECT * FROM pg_locks WHERE NOT granted;
    MySQL: SHOW ENGINE INNODB STATUS;  (look for LATEST DEADLOCK)
    |
    +-- blocked queries --> identify blocker, kill if necessary
    |
    v
[7] Review database logs
    PostgreSQL: /var/log/postgresql/postgresql-*.log
    MySQL: /var/log/mysql/error.log
```

# Quick Facts (Revision)

- Monitor five things: connections, query performance, disk usage, replication lag, and locks.
- Cache hit ratio should be above 95%; below that means the buffer pool / shared_buffers is too small or workload does not fit in memory.
- `SHOW PROCESSLIST` (MySQL) and `pg_stat_activity` (PostgreSQL) are the first places to look when something is slow.
- `EXPLAIN ANALYZE` runs the query and shows actual timing; plain `EXPLAIN` only estimates -- use ANALYZE for real diagnostics.
- Seq Scan on a large table almost always means a missing index; create one on the WHERE/JOIN column.
- Prometheus exporters (mysqld_exporter, postgres_exporter) are the standard way to feed database metrics into Grafana dashboards.
- Set alerts on connection usage (>80%), disk usage (>85%), replication lag (>30s), and any deadlocks.
- Always check the database error log as a last resort -- it often contains the root cause that status views do not show.
