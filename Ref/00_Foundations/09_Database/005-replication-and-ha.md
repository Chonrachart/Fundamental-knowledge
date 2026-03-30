# Replication and High Availability

- Replication copies data from a primary server to one or more replicas -- provides read scaling, redundancy, and disaster recovery.
- High availability (HA) ensures the database remains accessible even when a node fails -- achieved through replication + failover + connection routing.
- The core trade-off: more replicas and stricter consistency increase durability but add latency and operational complexity.

# Architecture

```text
Write path (replication):

  +-------------+     binlog / WAL stream     +-------------+
  |   Primary   |  ------------------------>  |  Replica 1  |  (read-only)
  |  (read/write)|                            +-------------+
  +-------------+  ------------------------>  +-------------+
        |            binlog / WAL stream      |  Replica 2  |  (read-only)
        |                                     +-------------+
        |
        v
  +-------------+
  |  binlog /   |   archived for PITR
  |  WAL archive|
  +-------------+


HA with proxy:

  +----------+      +----------+      +----------+
  |  App 1   |      |  App 2   |      |  App 3   |
  +----------+      +----------+      +----------+
       |                 |                 |
       +---------+-------+---------+-------+
                 |                 |
                 v                 v
          +------------+   +------------+
          |  Proxy /   |   |  Proxy /   |   (HAProxy, PgBouncer,
          |  Pooler    |   |  Pooler    |    ProxySQL -- can be
          +------------+   +------------+    combined or separate)
                 |                 |
        +--------+---------+------+--------+
        |                  |               |
        v                  v               v
  +----------+      +----------+    +----------+
  |  Primary |      | Replica  |    | Replica  |
  | (writes) |      | (reads)  |    | (reads)  |
  +----------+      +----------+    +----------+
```

# Mental Model

```text
HA maturity levels -- pick the level that matches your SLA:

  Level 0: Single node
      |    no redundancy, simplest, longest downtime on failure
      v
  Level 1: Primary + Replica(s)
      |    manual failover, minutes of downtime
      |    good for: read scaling, warm standby
      v
  Level 2: Primary + Replica + Proxy + Automatic failover
      |    seconds of downtime, proxy reroutes traffic
      |    good for: production services with SLA
      v
  Level 3: Multi-node cluster (Galera, Patroni, Aurora)
      |    near-zero downtime, complex to operate
      |    good for: critical workloads, multi-AZ
```

```text
Example: PostgreSQL streaming replication setup

  [1] Primary: enable WAL archiving + replication in postgresql.conf
      wal_level = replica
      max_wal_senders = 5
  [2] Create replication user
      CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '...';
  [3] Allow in pg_hba.conf
      host replication replicator replica_ip/32 md5
  [4] On replica: pg_basebackup from primary
      pg_basebackup -h primary_ip -U replicator -D /var/lib/postgresql/data -P -X stream
  [5] Replica starts and streams WAL from primary continuously
```

# Core Building Blocks

### Replication Concepts

- **Primary (source)** -- the server that accepts writes. Formerly called "master" (deprecated term).
- **Replica (target)** -- receives changes from primary, serves read-only queries. Formerly "slave" (deprecated term).
- **Async replication** -- primary does not wait for replica to confirm. Fast but replica can lag.
- **Sync replication** -- primary waits for at least one replica to confirm write. Slower but no data loss on failover.
- **Semi-sync** -- primary waits for replica to receive (not apply) the transaction. MySQL-specific middle ground.
- **Replication lag** -- delay between a write on primary and its visibility on replica. Monitor this.

Related notes: [001-database-concepts](./001-database-concepts.md)

### MySQL Replication

- Based on **binary log (binlog)** -- primary records every change, replica reads and replays it.
- **GTID (Global Transaction Identifier)** -- unique ID per transaction across the cluster. Makes failover and re-pointing replicas much easier than file+position.
- Replica runs two threads: IO thread (fetches binlog) and SQL thread (applies it).

```bash
# on primary: check binlog status
mysql -e "SHOW MASTER STATUS\G"

# on replica: configure replication (MySQL 8.0+ syntax)
mysql -e "
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='primary_ip',
  SOURCE_USER='repl_user',
  SOURCE_PASSWORD='...',
  SOURCE_AUTO_POSITION=1;
START REPLICA;
"

# check replica status
mysql -e "SHOW REPLICA STATUS\G"
# key fields: Replica_IO_Running, Replica_SQL_Running, Seconds_Behind_Source

# list all GTID transactions executed
mysql -e "SELECT @@gtid_executed\G"

# skip a single replication error (use with caution)
mysql -e "SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1; START REPLICA;"
```

Related notes: [003-user-and-access-management](./003-user-and-access-management.md)

### PostgreSQL Replication

- **Streaming replication** -- replica connects to primary and receives WAL (Write-Ahead Log) records in real time.
- **WAL shipping** -- WAL files are copied to a remote location; replica replays them. Simpler but higher lag than streaming.
- **pg_basebackup** -- takes a full physical copy from a running primary; used to bootstrap a new replica.
- **synchronous_commit** -- controls whether primary waits for replica. Set per-transaction or globally.
  - `on` (default) -- waits for local WAL flush only.
  - `remote_write` -- waits until replica has received and written (not flushed) WAL.
  - `remote_apply` -- waits until replica has applied the WAL (strongest, most latency).

```bash
# check replication status on primary
psql -c "SELECT client_addr, state, sent_lsn, replay_lsn,
         replay_lsn - sent_lsn AS lag_bytes
         FROM pg_stat_replication;"

# check recovery status on replica
psql -c "SELECT pg_is_in_recovery(), pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();"

# check WAL receiver status (on replica)
psql -c "SELECT * FROM pg_stat_wal_receiver;"
```

Related notes: [004-backup-and-restore](./004-backup-and-restore.md)

### Failover

- **Manual failover** -- admin promotes a replica to primary, reconfigures other replicas, updates application connection strings.
- **Automatic failover** -- tooling detects primary failure and promotes a replica without human intervention.
  - PostgreSQL: Patroni, repmgr, pg_auto_failover.
  - MySQL: MySQL InnoDB Cluster (Group Replication + MySQL Router), Orchestrator, MHA.
- **Split-brain** -- two nodes both believe they are primary. Causes data divergence and corruption. Prevented by fencing (STONITH), quorum, or leader election.

```text
Manual failover steps (PostgreSQL):

  [1] Confirm primary is truly down (not a network blip)
  [2] Pick the replica with the least lag
  [3] Promote:  pg_ctl promote -D /var/lib/postgresql/data
                or: SELECT pg_promote();
  [4] Repoint other replicas to the new primary
  [5] Update application connection string / DNS / proxy config
  [6] Investigate and rebuild the old primary as a replica
```

Related notes: [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md)

### High Availability Patterns

- **Active-passive** -- one primary handles all traffic; replica is on standby. Simple, well-understood.
- **Active-active (multi-primary)** -- multiple nodes accept writes. Requires conflict resolution. Examples: MySQL Group Replication, Galera Cluster.
- **Proxy-based routing** -- a proxy sits between application and database, directing writes to primary and reads to replicas. Handles failover transparently.

| Pattern         | Writes       | Reads           | Failover       | Complexity |
| :-------------- | :----------- | :-------------- | :------------- | :--------- |
| Single node     | 1 node       | 1 node          | manual rebuild | lowest     |
| Active-passive  | primary only | primary+replica | manual/auto    | moderate   |
| Proxy + replicas| primary only | replicas        | proxy reroutes | moderate   |
| Active-active   | all nodes    | all nodes       | automatic      | highest    |

Related notes: [001-database-concepts](./001-database-concepts.md)

### Connection Pooling and Proxies
```text
Connection flow with PgBouncer:

  App (100 connections) --> PgBouncer (pool: 20 connections) --> PostgreSQL (20 backend connections)

  Without pooler: PostgreSQL handles 100 connections (high memory)
  With pooler:    PostgreSQL handles 20 connections (efficient)
```

Related notes: [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md), [007-database-in-containers](./007-database-in-containers.md)
- Database connections are expensive (memory, process/thread per connection). Pooling reuses a smaller set of connections.
- **PgBouncer** (PostgreSQL) -- lightweight connection pooler. Modes: session, transaction, statement.
  - Transaction pooling is the most common -- connection returned to pool after each transaction.
- **ProxySQL** (MySQL) -- connection pooler + query router + query caching.
  - Routes reads to replicas, writes to primary based on query rules.
  - Can handle automatic failover with query rules and health checks.
- **HAProxy** -- generic TCP/HTTP load balancer, used in front of database replicas for read distribution.

```bash
# check PgBouncer stats
psql -p 6432 -U pgbouncer pgbouncer -c "SHOW POOLS;"
psql -p 6432 -U pgbouncer pgbouncer -c "SHOW STATS;"

# check ProxySQL status
mysql -h 127.0.0.1 -P 6032 -u admin -p -e "SELECT * FROM runtime_mysql_servers;"

# HAProxy: check backend health via stats socket
echo "show stat" | socat stdio /var/run/haproxy/admin.sock | cut -d, -f1,2,18
```
