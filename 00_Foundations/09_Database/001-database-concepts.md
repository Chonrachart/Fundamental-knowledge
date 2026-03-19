# Database Concepts

- Relational databases organize data into tables with enforced schemas and use SQL for queries; they are the default choice for structured, transactional workloads.
- NoSQL databases (document, key-value, columnar) trade strict schemas and joins for flexibility, horizontal scaling, and specialized access patterns.
- Understanding database fundamentals helps DevOps engineers make informed decisions about provisioning, scaling, and troubleshooting data stores.

# Architecture

```text
Table: orders
+--------------------------------------------------------------------+
|  Column:   order_id (PK)  | customer_id (FK) | product  |  total  |
|--------------------------------------------------------------------+
|  Row 1:       1001        |       42         | Widget A |  29.99  |
|  Row 2:       1002        |       42         | Widget B |  49.99  |
|  Row 3:       1003        |       87         | Widget A |  29.99  |
+--------------------------------------------------------------------+
       |                           |
       |  PRIMARY KEY              |  FOREIGN KEY
       |  (unique, not null,       |  (references customers.id,
       |   clustered index)        |   enforces referential integrity)
       v                           v
  Auto-increment             Table: customers
  or UUID                    +-------------------------------+
                             |  id (PK) | name    | email   |
                             |-------------------------------+
                             |    42    | Alice   | a@ex.co |
                             |    87    | Bob     | b@ex.co |
                             +-------------------------------+

Index (B-tree on orders.customer_id):
+---------------------------------------------------+
|         [pointer to 42]    [pointer to 87]        |
|            /       \              |                |
|     Row 1, Row 2              Row 3               |
+---------------------------------------------------+
  Speeds up: SELECT * FROM orders WHERE customer_id = 42;
  Cost: extra disk space + slower INSERT/UPDATE
```

# Mental Model

```text
Choosing the right database type -- decision tree:

  What is your primary data pattern?
      |
      +-- Structured rows/columns, need transactions (ACID)?
      |       |
      |       +-- Yes --> Relational (PostgreSQL, MySQL)
      |
      +-- Flexible/nested documents, schema changes often?
      |       |
      |       +-- Yes --> Document store (MongoDB)
      |
      +-- Simple key-value lookups, caching, sessions?
      |       |
      |       +-- Yes --> Key-value store (Redis, Memcached)
      |
      +-- Massive write throughput, time-series, wide columns?
              |
              +-- Yes --> Columnar store (Cassandra, ScyllaDB)

In practice:
  - Most web applications start with PostgreSQL or MySQL
  - Add Redis for caching / session storage
  - Introduce specialized stores only when a clear need arises
```

```bash
# check which database engines are installed on a system
which psql && psql --version       # PostgreSQL client
which mysql && mysql --version     # MySQL client
which mongosh && mongosh --version # MongoDB shell
which redis-cli && redis-cli --version
```

# Core Building Blocks

### Relational Databases

- Data lives in tables (relations); each table has a fixed set of columns (schema) and rows hold individual records.
- Primary key (PK) uniquely identifies each row; foreign key (FK) links rows across tables, enforcing referential integrity.
- PostgreSQL and MySQL are the two most common relational databases in DevOps environments; PostgreSQL is more feature-rich, MySQL is historically more widespread in LAMP stacks.

```text
PostgreSQL strengths:         MySQL strengths:
- Advanced data types         - Simpler to operate
  (JSONB, arrays, hstore)    - Wide hosting support
- Extensions (PostGIS,        - Multiple storage engines
  pg_trgm, pgcrypto)           (InnoDB default)
- Standards compliance        - Large community, many
- Better concurrency (MVCC)     tutorials and tooling
```

Related notes: [000-core](./000-core.md) | [002-sql-essentials](./002-sql-essentials.md)

### NoSQL Overview

- Document stores (MongoDB) save data as JSON-like documents; flexible schema allows different fields per document, good for content management and catalogs.
- Key-value stores (Redis) map keys to values in memory; extremely fast, used for caching, sessions, rate limiting, and queues.
- Column-family stores (Cassandra) organize data by columns instead of rows; designed for high write throughput across many nodes, used for time-series, IoT, and logging.

```text
Type          Example       Data Model           Typical Use Case
-----------   -----------   -------------------  -------------------------
Document      MongoDB       JSON-like documents  Content, catalogs, CMS
Key-Value     Redis         Key -> Value (any)   Caching, sessions, queues
Column        Cassandra     Column families      Time-series, IoT, logs
Graph         Neo4j         Nodes + edges        Social networks, fraud
```

Related notes: [000-core](./000-core.md)

### ACID Properties

- Atomicity: a transaction is all-or-nothing; if any part fails, the entire transaction is rolled back.
- Consistency: a transaction brings the database from one valid state to another; constraints (PK, FK, NOT NULL) are always enforced.
- Isolation: concurrent transactions do not interfere with each other; the database behaves as if transactions run sequentially.
- Durability: once a transaction is committed, it survives crashes; data is written to the WAL/redo log before acknowledging the commit.

```text
Bank transfer example (ACID in action):

  BEGIN TRANSACTION;
    UPDATE accounts SET balance = balance - 100 WHERE id = 1;  -- debit
    UPDATE accounts SET balance = balance + 100 WHERE id = 2;  -- credit
  COMMIT;

  Atomicity   --> if the credit fails, the debit is rolled back
  Consistency --> total money in the system stays the same
  Isolation   --> another query sees either both changes or neither
  Durability  --> after COMMIT, the transfer survives a server crash
```

Related notes: [000-core](./000-core.md) | [002-sql-essentials](./002-sql-essentials.md)

### Indexes

- An index is a separate data structure (usually B-tree) that maps column values to row locations, making lookups faster without scanning every row.
- Without an index, the database does a sequential scan (reads every row); with an index on the filtered column, it does an index scan (jumps directly).
- Trade-off: indexes speed up SELECT but slow down INSERT/UPDATE/DELETE because the index must be updated too; add indexes on columns used in WHERE, JOIN, and ORDER BY.

```text
When to add an index (DevOps rules of thumb):
  - Column appears in WHERE clauses frequently
  - Column is used in JOIN conditions
  - Column is used in ORDER BY on large tables
  - Slow query log shows sequential scans on big tables

When NOT to add an index:
  - Table is small (< 1000 rows) -- scan is fast enough
  - Column has very low cardinality (e.g., boolean)
  - Table is write-heavy and reads are rare

Check existing indexes:
  PostgreSQL: \di  or  SELECT * FROM pg_indexes WHERE tablename = 'orders';
  MySQL:      SHOW INDEX FROM orders;
```

Related notes: [000-core](./000-core.md) | [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md)

### Schemas and Migrations

- A schema defines the structure of the database: tables, columns, data types, constraints, indexes.
- Migrations are versioned scripts that evolve the schema over time (add column, create table, alter type); they let you track database changes in version control alongside application code.
- Common migration tools: Flyway (Java ecosystem), Alembic (Python/SQLAlchemy), Django migrations (Python/Django), Liquibase (cross-platform), golang-migrate (Go).

```text
Migration workflow:

  Developer writes          CI/CD pipeline          Production database
  migration file            runs migrations         schema updated
       |                         |                        |
       v                         v                        v
  V001_create_users.sql  --> flyway migrate       --> users table created
  V002_add_email.sql     --> flyway migrate       --> email column added
  V003_create_orders.sql --> flyway migrate       --> orders table created

  Key rules:
  - Never edit a migration that has already been applied
  - Always test migrations against a copy of production data
  - Include both "up" (apply) and "down" (rollback) scripts
  - Run migrations in a transaction when possible
```

Related notes: [000-core](./000-core.md) | [003-user-and-access-management](./003-user-and-access-management.md)

### Relational vs NoSQL Comparison

```text
+-------------------+----------------------------+----------------------------+
| Aspect            | Relational (SQL)           | NoSQL                      |
+-------------------+----------------------------+----------------------------+
| Data model        | Tables, rows, columns      | Documents, key-value,      |
|                   |                            | columns, graphs            |
+-------------------+----------------------------+----------------------------+
| Schema            | Fixed, enforced             | Flexible, schema-on-read   |
+-------------------+----------------------------+----------------------------+
| Query language    | SQL (standardized)          | Varies per database        |
+-------------------+----------------------------+----------------------------+
| Transactions      | Full ACID                   | Varies (some support ACID) |
+-------------------+----------------------------+----------------------------+
| Scaling           | Vertical (scale up)         | Horizontal (scale out)     |
+-------------------+----------------------------+----------------------------+
| Joins             | Native, efficient           | Usually no joins;          |
|                   |                            | denormalize instead        |
+-------------------+----------------------------+----------------------------+
| Best for          | Structured data, complex    | Flexible schemas, high     |
|                   | queries, strong consistency | write volume, caching      |
+-------------------+----------------------------+----------------------------+
| Examples          | PostgreSQL, MySQL,          | MongoDB, Redis, Cassandra, |
|                   | MariaDB, Oracle             | DynamoDB, Neo4j            |
+-------------------+----------------------------+----------------------------+
| DevOps concern    | Backup with pg_dump /       | Backup varies per tool;    |
|                   | mysqldump; replication      | clustering is built-in     |
|                   | via WAL / binlog            | for most NoSQL             |
+-------------------+----------------------------+----------------------------+
```

Related notes: [000-core](./000-core.md)

---

# Practical Command Set (Core)

```bash
# --- Inspect database structure ---

# PostgreSQL: list all tables and their sizes
psql -c "\dt+"

# PostgreSQL: describe a table's columns and types
psql -c "\d orders"

# PostgreSQL: list all indexes on a table
psql -c "SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'orders';"

# MySQL: list tables with sizes
mysql -e "SELECT table_name, ROUND(data_length/1024/1024, 2) AS size_mb
          FROM information_schema.tables
          WHERE table_schema = 'mydb';"

# MySQL: describe a table
mysql -e "DESCRIBE orders;" mydb

# MySQL: show indexes
mysql -e "SHOW INDEX FROM orders;" mydb

# --- Check ACID / transactions ---

# PostgreSQL: check current transaction isolation level
psql -c "SHOW transaction_isolation;"

# MySQL: check storage engine (InnoDB = ACID)
mysql -e "SELECT table_name, engine FROM information_schema.tables
          WHERE table_schema = 'mydb';"

# --- Migration tools ---

# Flyway: run pending migrations
flyway -url=jdbc:postgresql://localhost/mydb -user=admin -password=secret migrate

# Alembic: generate and apply a migration
alembic revision --autogenerate -m "add email column"
alembic upgrade head
```

# Troubleshooting Guide

```text
Problem: query is slow
    |
    v
[1] Identify the query
    PostgreSQL: check pg_stat_statements or slow query log
    MySQL: enable slow_query_log, check slow queries
    |
    v
[2] Run EXPLAIN (ANALYZE)
    EXPLAIN ANALYZE SELECT ... ;
    Look for: Seq Scan on large table, high cost, many rows
    |
    v
[3] Missing index?
    If Seq Scan on a filtered column --> CREATE INDEX
    |
    v
[4] Table bloat? (PostgreSQL)
    Check dead tuples: SELECT n_dead_tup FROM pg_stat_user_tables;
    Fix: VACUUM ANALYZE <table>;
    |
    v
[5] Query design issue?
    SELECT * instead of specific columns?
    Missing WHERE clause? Cartesian join?
    |
    v
[6] Resource limits?
    Check shared_buffers, work_mem (PostgreSQL)
    Check innodb_buffer_pool_size (MySQL)
    Monitor CPU, RAM, disk I/O during query
```

# Quick Facts (Revision)

- A table = a relation; a row = a tuple/record; a column = an attribute/field.
- Primary key = unique + not null; foreign key = references another table's primary key.
- ACID guarantees reliable transactions; BASE (Basically Available, Soft state, Eventually consistent) describes many NoSQL systems.
- B-tree is the default index type in both PostgreSQL and MySQL; it handles equality and range queries.
- An index on a column used in WHERE can turn a full table scan (O(n)) into a B-tree lookup (O(log n)).
- Schema migrations should be versioned, idempotent where possible, and tested against production-like data.
- PostgreSQL uses MVCC (Multi-Version Concurrency Control) so readers never block writers and vice versa.
- When in doubt, start with PostgreSQL -- it covers relational, JSON (JSONB), and full-text search in one engine.
