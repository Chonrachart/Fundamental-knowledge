# SQL Essentials

- SQL (Structured Query Language) is the standard language for querying and manipulating data in relational databases.
- Four core operations map to CRUD: SELECT (read), INSERT (create), UPDATE (modify), DELETE (remove).
- DevOps needs enough SQL to query logs, check data integrity, debug application issues, and monitor database health.

# Architecture

```text
SQL Query Execution Flow

+----------+     +----------+     +-----------+     +-----------+     +-----------+
|  Client  | --> |  Parser  | --> |  Planner  | --> | Executor  | --> |  Storage  |
| (psql,   |     | (syntax  |     | (query    |     | (runs the |     |  Engine   |
|  mysql)  |     |  check)  |     |  plan,    |     |  plan,    |     | (disk I/O |
|          |     |          |     |  optimize)|     |  fetches) |     |  + cache) |
+----------+     +----------+     +-----------+     +-----------+     +-----------+
     |                                                                      |
     |<--------------------- result set returned --------------------------|
```

# Mental Model

```text
CRUD Operation Decision:

  Need to read data?    --> SELECT ... FROM ... WHERE ...
  Need to create data?  --> INSERT INTO ... VALUES ...
  Need to modify data?  --> UPDATE ... SET ... WHERE ...   (NEVER without WHERE)
  Need to remove data?  --> DELETE FROM ... WHERE ...      (NEVER without WHERE)

Typical DevOps workflow:

  [1] Connect to database
  [2] SELECT to investigate / confirm current state
  [3] UPDATE or DELETE only after verifying with SELECT first
  [4] Verify change with another SELECT
```

```sql
-- always check before modifying
SELECT * FROM users WHERE email = 'old@example.com';
-- then update
UPDATE users SET email = 'new@example.com' WHERE email = 'old@example.com';
-- verify
SELECT * FROM users WHERE email = 'new@example.com';
```

# Core Building Blocks

### SELECT -- Reading Data

- Basic query: `SELECT columns FROM table WHERE condition;`
- Use `*` to select all columns (avoid in production queries -- be explicit).
- `ORDER BY column ASC|DESC` to sort results.
- `LIMIT n` to restrict rows returned (useful for large tables).

```sql
-- basic select with filter and sort
SELECT id, name, email FROM users WHERE active = true ORDER BY name ASC LIMIT 10;

-- count rows
SELECT COUNT(*) FROM orders WHERE status = 'pending';

-- aggregate functions: COUNT, SUM, AVG, MIN, MAX
SELECT status, COUNT(*) AS total, AVG(amount) AS avg_amount
FROM orders
GROUP BY status;

-- filter groups with HAVING (WHERE filters rows, HAVING filters groups)
SELECT status, COUNT(*) AS total
FROM orders
GROUP BY status
HAVING COUNT(*) > 100;
```

Related notes: [001-database-concepts](./001-database-concepts.md)

### INSERT -- Creating Data

- Adds new rows to a table.
- Always specify column names explicitly for clarity.

```sql
-- single row
INSERT INTO users (name, email, active) VALUES ('alice', 'alice@example.com', true);

-- multiple rows
INSERT INTO users (name, email, active) VALUES
  ('bob', 'bob@example.com', true),
  ('carol', 'carol@example.com', false);
```

Related notes: [001-database-concepts](./001-database-concepts.md)

### UPDATE -- Modifying Data

- Changes existing rows. ALWAYS use a WHERE clause.
- Run a SELECT with the same WHERE first to verify which rows will be affected.

```sql
-- DANGEROUS: updates ALL rows
-- UPDATE users SET active = false;

-- SAFE: targets specific rows
UPDATE users SET active = false WHERE last_login < '2025-01-01';
```

Related notes: [004-backup-and-restore](./004-backup-and-restore.md)

### DELETE -- Removing Data

- Removes rows from a table. ALWAYS use a WHERE clause.
- Consider using `active = false` (soft delete) instead of DELETE in production.

```sql
-- DANGEROUS: deletes ALL rows
-- DELETE FROM users;

-- SAFE: targets specific rows
DELETE FROM users WHERE active = false AND last_login < '2024-01-01';

-- PostgreSQL: delete and return deleted rows for verification
DELETE FROM users WHERE id = 42 RETURNING *;
```

Related notes: [004-backup-and-restore](./004-backup-and-restore.md)

### Filtering -- WHERE Clauses

- `WHERE` filters rows before grouping; `HAVING` filters after grouping.
- Combine conditions with `AND`, `OR` (use parentheses for clarity).

```sql
-- exact match
SELECT * FROM users WHERE email = 'alice@example.com';

-- multiple values
SELECT * FROM users WHERE role IN ('admin', 'editor');

-- pattern matching (% = any chars, _ = single char)
SELECT * FROM users WHERE email LIKE '%@example.com';

-- range
SELECT * FROM orders WHERE created_at BETWEEN '2025-01-01' AND '2025-12-31';

-- null checks (use IS NULL, not = NULL)
SELECT * FROM users WHERE deleted_at IS NULL;

-- combined
SELECT * FROM users
WHERE active = true
  AND (role = 'admin' OR role = 'editor')
  AND email IS NOT NULL;
```

Related notes: [001-database-concepts](./001-database-concepts.md)

### JOINs -- Combining Tables

- INNER JOIN: returns only rows that match in both tables.
- LEFT JOIN: returns all rows from the left table, NULLs for non-matching right rows.
- DevOps rarely needs RIGHT JOIN or FULL JOIN.

```text
users table           orders table
+---------+------+    +----------+---------+--------+
| user_id | name |    | order_id | user_id | amount |
+---------+------+    +----------+---------+--------+
| 1       | alice|    | 101      | 1       | 50.00  |
| 2       | bob  |    | 102      | 1       | 30.00  |
| 3       | carol|    | 103      | 2       | 75.00  |
+---------+------+    +----------+---------+--------+

INNER JOIN (users with orders only):
  alice -- order 101, 102
  bob   -- order 103
  (carol excluded -- no orders)

LEFT JOIN (all users, even without orders):
  alice -- order 101, 102
  bob   -- order 103
  carol -- NULL (no orders)
```

```sql
-- INNER JOIN: users who have placed orders
SELECT u.name, o.order_id, o.amount
FROM users u
INNER JOIN orders o ON u.user_id = o.user_id;

-- LEFT JOIN: all users, orders if they exist
SELECT u.name, o.order_id, COALESCE(o.amount, 0) AS amount
FROM users u
LEFT JOIN orders o ON u.user_id = o.user_id;
```

Related notes: [001-database-concepts](./001-database-concepts.md)

### Useful DevOps Queries

- Queries for monitoring database health and investigating issues.
- Syntax differs between MySQL and PostgreSQL.

```sql
-- ============================================
-- DATABASE SIZE
-- ============================================

-- PostgreSQL: database size
SELECT pg_database.datname,
       pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database ORDER BY pg_database_size(pg_database.datname) DESC;

-- MySQL: database size
SELECT table_schema AS database_name,
       ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.tables
GROUP BY table_schema ORDER BY size_mb DESC;

-- ============================================
-- TABLE SIZES
-- ============================================

-- PostgreSQL: table sizes in current database
SELECT relname AS table_name,
       pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC LIMIT 10;

-- MySQL: table sizes in a database
SELECT table_name,
       ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.tables
WHERE table_schema = 'your_database'
ORDER BY size_mb DESC LIMIT 10;

-- ============================================
-- ACTIVE CONNECTIONS
-- ============================================

-- PostgreSQL: active connections
SELECT datname, usename, client_addr, state, query
FROM pg_stat_activity
WHERE state = 'active';

-- MySQL: active connections
SHOW PROCESSLIST;
-- or for more detail:
SELECT * FROM information_schema.processlist WHERE command != 'Sleep';

-- ============================================
-- RUNNING / LONG QUERIES
-- ============================================

-- PostgreSQL: queries running longer than 5 seconds
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 seconds'
  AND state != 'idle';

-- MySQL: queries running longer than 5 seconds
SELECT id, user, host, db, command, time, state, info
FROM information_schema.processlist
WHERE command != 'Sleep' AND time > 5;

-- ============================================
-- KILL A QUERY
-- ============================================

-- PostgreSQL: cancel or terminate
SELECT pg_cancel_backend(pid);      -- graceful (cancel query)
SELECT pg_terminate_backend(pid);   -- force (kill connection)

-- MySQL: kill a query
KILL QUERY <process_id>;   -- kill the query only
KILL <process_id>;         -- kill the connection
```

Related notes: [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md)

---

# Practical Command Set (Core)

```bash
# ---- PostgreSQL ----

# connect to a database
psql -h localhost -U postgres -d mydb

# run a single query from command line
psql -h localhost -U postgres -d mydb -c "SELECT COUNT(*) FROM users;"

# run a SQL file
psql -h localhost -U postgres -d mydb -f /path/to/script.sql

# export query results to CSV
psql -h localhost -U postgres -d mydb -c "COPY (SELECT * FROM users) TO STDOUT WITH CSV HEADER;" > users.csv

# ---- MySQL ----

# connect to a database
mysql -h localhost -u root -p mydb

# run a single query from command line
mysql -h localhost -u root -p -e "SELECT COUNT(*) FROM users;" mydb

# run a SQL file
mysql -h localhost -u root -p mydb < /path/to/script.sql

# export query results to CSV (requires FILE privilege or use --batch)
mysql -h localhost -u root -p -B -e "SELECT * FROM users;" mydb | tr '\t' ',' > users.csv
```

# Troubleshooting Flow (Quick)

```text
Problem: application reports "data not found" or "wrong data"
    |
    v
[1] Can you connect to the database?
    psql -h host -U user -d db   /   mysql -h host -u user -p db
    |
    +-- connection refused --> check service is running, port, firewall
    +-- auth failed --> check credentials, pg_hba.conf / mysql.user
    |
    v
[2] Does the table exist and have data?
    SELECT COUNT(*) FROM table_name;
    |
    +-- table does not exist --> wrong database? check schema
    +-- count = 0 --> data was deleted or never inserted
    |
    v
[3] Does the expected row exist?
    SELECT * FROM table_name WHERE <condition>;
    |
    +-- no rows --> wrong filter? check column values, case sensitivity
    +-- data looks wrong --> check recent UPDATE statements, app logs
    |
    v
[4] Are there long-running or blocking queries?
    pg_stat_activity (PostgreSQL)  /  SHOW PROCESSLIST (MySQL)
    |
    +-- long query found --> consider pg_cancel_backend / KILL QUERY
    |
    v
[5] Check application logs and query logs for the actual SQL being sent
```

# Quick Facts (Revision)

- CRUD maps to SQL: Create=INSERT, Read=SELECT, Update=UPDATE, Delete=DELETE.
- NEVER run UPDATE or DELETE without a WHERE clause -- always SELECT first to verify.
- `COUNT(*)` counts all rows; `COUNT(column)` counts non-NULL values only.
- INNER JOIN returns matching rows only; LEFT JOIN returns all left-table rows plus matches.
- Use `IS NULL` / `IS NOT NULL` to check for NULLs (not `= NULL`).
- `LIKE` patterns: `%` matches any characters, `_` matches exactly one character.
- PostgreSQL uses `pg_stat_activity` for connections; MySQL uses `SHOW PROCESSLIST`.
- Always wrap destructive operations in a transaction: `BEGIN; ... ROLLBACK;` to test, then `COMMIT;` to apply.
