# User and Access Management

- Database access control determines who can connect, how they authenticate, and what they are allowed to do.
- MySQL uses `mysql.user` table for authentication; PostgreSQL uses `pg_hba.conf` for connection rules and `pg_authid` for roles.
- Principle of least privilege: every application and user should have only the minimum permissions required.

# Architecture

```text
Authentication and Authorization Flow

+----------+     +----------------+     +------------------+     +----------------+
|  Client  | --> | Auth Check     | --> | Permission Check | --> | Allow / Deny   |
| (app,    |     |                |     |                  |     |                |
|  psql,   |     | PostgreSQL:    |     | GRANT table:     |     | query executes |
|  mysql)  |     |  pg_hba.conf   |     |  SELECT? INSERT? |     | or error       |
|          |     | MySQL:         |     |  UPDATE? DELETE?  |     | returned       |
|          |     |  mysql.user    |     |  ALL PRIVILEGES? |     |                |
+----------+     +----------------+     +------------------+     +----------------+
                       |                        |
                       v                        v
                 +-------------+         +-------------+
                 | Auth Method |         | Privilege    |
                 | - password  |         | Levels:      |
                 | - md5       |         | - global     |
                 | - scram-256 |         | - database   |
                 | - peer/ident|         | - table      |
                 | - SSL cert  |         | - column     |
                 +-------------+         +-------------+
```

# Mental Model

```text
User Setup Workflow:

  [1] Create user       --> CREATE USER / CREATE ROLE
  [2] Set auth method   --> password, pg_hba.conf entry, SSL
  [3] Grant permissions  --> GRANT specific privileges on specific objects
  [4] Verify access      --> connect as user, test allowed and denied operations
  [5] Maintain           --> rotate passwords, review grants, revoke when no longer needed
```

```sql
-- PostgreSQL: full workflow example
CREATE ROLE app_user WITH LOGIN PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE mydb TO app_user;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_user;
-- verify
\du app_user

-- MySQL: full workflow example
CREATE USER 'app_user'@'10.0.0.%' IDENTIFIED BY 'secure_password';
GRANT SELECT, INSERT, UPDATE ON mydb.* TO 'app_user'@'10.0.0.%';
FLUSH PRIVILEGES;
-- verify
SHOW GRANTS FOR 'app_user'@'10.0.0.%';
```

# Core Building Blocks

### Creating Users

- PostgreSQL uses roles (a role with LOGIN is a user, without LOGIN is a group).
- MySQL users are identified by `'username'@'host'` -- the host part matters.

```sql
-- ============================================
-- PostgreSQL
-- ============================================

-- create a login role (user)
CREATE ROLE app_user WITH LOGIN PASSWORD 'secure_password';

-- create a role with specific attributes
CREATE ROLE admin_user WITH LOGIN PASSWORD 'admin_pass' CREATEDB CREATEROLE;

-- create a group role (no login)
CREATE ROLE readonly;

-- add a user to a group
GRANT readonly TO app_user;

-- alter existing user
ALTER ROLE app_user WITH PASSWORD 'new_password';

-- drop a user (must revoke privileges first)
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM app_user;
DROP ROLE app_user;

-- list users
\du

-- ============================================
-- MySQL
-- ============================================

-- create a user (host-specific)
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'secure_password';
CREATE USER 'app_user'@'10.0.0.%' IDENTIFIED BY 'secure_password';   -- subnet wildcard
CREATE USER 'app_user'@'%' IDENTIFIED BY 'secure_password';           -- any host (avoid in prod)

-- alter password
ALTER USER 'app_user'@'localhost' IDENTIFIED BY 'new_password';

-- drop a user
DROP USER 'app_user'@'localhost';

-- list users
SELECT user, host FROM mysql.user;
```

Related notes: [001-database-concepts](./001-database-concepts.md)

### Granting and Revoking Permissions

- Grant the minimum permissions needed (principle of least privilege).
- Common privilege types: SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, ALL PRIVILEGES.
- Privilege levels: global, database, table, column.

```sql
-- ============================================
-- PostgreSQL
-- ============================================

-- grant connect to a database
GRANT CONNECT ON DATABASE mydb TO app_user;

-- grant usage on schema (required before table grants)
GRANT USAGE ON SCHEMA public TO app_user;

-- grant specific privileges on all existing tables
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_user;

-- grant on a specific table
GRANT SELECT ON users TO app_user;

-- grant on future tables (so new tables get the same permissions)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE ON TABLES TO app_user;

-- revoke
REVOKE INSERT, UPDATE ON ALL TABLES IN SCHEMA public FROM app_user;

-- check grants
\dp                         -- all table permissions
\dp users                   -- permissions on specific table
SELECT * FROM information_schema.role_table_grants WHERE grantee = 'app_user';

-- ============================================
-- MySQL
-- ============================================

-- grant on entire database
GRANT SELECT, INSERT, UPDATE ON mydb.* TO 'app_user'@'10.0.0.%';

-- grant on specific table
GRANT SELECT ON mydb.users TO 'app_user'@'10.0.0.%';

-- grant all (avoid for app users)
GRANT ALL PRIVILEGES ON mydb.* TO 'admin_user'@'localhost';

-- revoke
REVOKE INSERT, UPDATE ON mydb.* FROM 'app_user'@'10.0.0.%';

-- apply changes
FLUSH PRIVILEGES;

-- check grants
SHOW GRANTS FOR 'app_user'@'10.0.0.%';
```

Related notes: [002-sql-essentials](./002-sql-essentials.md)

### Authentication Methods

- PostgreSQL controls authentication via `pg_hba.conf` (host-based authentication).
- MySQL stores authentication in the `mysql.user` table with plugin-based methods.

```text
PostgreSQL pg_hba.conf format:
+--------+----------+-----------+-----------+----------+
| TYPE   | DATABASE | USER      | ADDRESS   | METHOD   |
+--------+----------+-----------+-----------+----------+
| local  | all      | postgres  |           | peer     |
| host   | mydb     | app_user  | 10.0.0/24 | scram-sha-256 |
| host   | all      | all       | 0.0.0.0/0 | md5      |
| hostssl| all      | all       | 0.0.0.0/0 | scram-sha-256 |
+--------+----------+-----------+-----------+----------+

Rules are evaluated top to bottom -- first match wins.
```

```text
PostgreSQL auth methods:
  peer     -- OS user must match DB user (local connections only)
  md5      -- password hashed with MD5 (legacy, still common)
  scram-sha-256 -- stronger password auth (recommended for new setups)
  cert     -- client SSL certificate authentication
  reject   -- deny connection (useful to block specific users/hosts)
```

```bash
# PostgreSQL: find pg_hba.conf location
psql -c "SHOW hba_file;"

# PostgreSQL: reload after editing pg_hba.conf (no restart needed)
psql -c "SELECT pg_reload_conf();"
# or
systemctl reload postgresql
```

```sql
-- MySQL: check authentication plugin per user
SELECT user, host, plugin FROM mysql.user;

-- MySQL auth plugins:
--   mysql_native_password  -- legacy (MySQL 5.x default)
--   caching_sha2_password  -- default in MySQL 8.x (stronger)

-- MySQL: change auth plugin for a user
ALTER USER 'app_user'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'new_password';
```

Related notes: [000-core](./000-core.md)

### Connection Security -- SSL/TLS

- Encrypt connections to prevent credential and data interception on the network.
- Especially important for remote / cross-network connections.

```sql
-- ============================================
-- PostgreSQL
-- ============================================

-- check if SSL is enabled
SHOW ssl;

-- check current connection SSL status
SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();

-- require SSL for a user via pg_hba.conf (use hostssl instead of host)
-- hostssl  mydb  app_user  10.0.0.0/24  scram-sha-256

-- ============================================
-- MySQL
-- ============================================

-- check SSL status
SHOW VARIABLES LIKE '%ssl%';
SHOW STATUS LIKE 'Ssl_cipher';

-- require SSL for a user
ALTER USER 'app_user'@'%' REQUIRE SSL;

-- require specific SSL options
ALTER USER 'app_user'@'%' REQUIRE X509;  -- require client certificate
```

```bash
# PostgreSQL: connect with SSL
psql "host=dbhost dbname=mydb user=app_user sslmode=require"

# MySQL: connect with SSL
mysql -h dbhost -u app_user -p --ssl-mode=REQUIRED

# test SSL connection
openssl s_client -connect dbhost:5432 -starttls postgres
openssl s_client -connect dbhost:3306 -starttls mysql
```

Related notes: [000-core](./000-core.md)

### Best Practices

- **No root/superuser for applications** -- create dedicated users with limited grants.
- **Separate user per application** -- if app A is compromised, app B is unaffected.
- **Principle of least privilege** -- grant only SELECT if the app only reads data.
- **Host restriction** -- bind users to specific IPs or subnets, never `'%'` in production.
- **Password rotation** -- change passwords periodically, use secret managers (Vault, AWS Secrets Manager).
- **Audit grants regularly** -- review who has access and remove stale users.

```text
Good setup example:

  +------------------+----------------------------------+-------------------+
  | User             | Privileges                       | Host              |
  +------------------+----------------------------------+-------------------+
  | admin_dba        | ALL PRIVILEGES (for maintenance) | localhost only    |
  | app_backend      | SELECT, INSERT, UPDATE on app_db | 10.0.1.0/24      |
  | app_readonly     | SELECT on app_db                 | 10.0.2.0/24      |
  | monitoring_agent | SELECT on pg_stat_activity       | monitoring server |
  +------------------+----------------------------------+-------------------+

Bad setup (avoid):
  - 'root'@'%' with no password
  - one user shared across all applications
  - ALL PRIVILEGES granted to application users
  - password stored in plaintext in app config
```

Related notes: [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md)

---

# Practical Command Set (Core)

```bash
# ---- PostgreSQL ----

# list all roles/users
psql -c "\du"

# list permissions on tables
psql -d mydb -c "\dp"

# check pg_hba.conf location
psql -c "SHOW hba_file;"

# reload pg_hba.conf after changes
psql -c "SELECT pg_reload_conf();"

# check who is connected
psql -c "SELECT usename, client_addr, ssl, state FROM pg_stat_activity;"

# check SSL status
psql -c "SHOW ssl;"

# ---- MySQL ----

# list all users
mysql -e "SELECT user, host, plugin FROM mysql.user;"

# show grants for a user
mysql -e "SHOW GRANTS FOR 'app_user'@'localhost';"

# check SSL status
mysql -e "SHOW VARIABLES LIKE '%ssl%';"

# flush privileges after direct table edits
mysql -e "FLUSH PRIVILEGES;"

# check current connections
mysql -e "SELECT user, host, db, command FROM information_schema.processlist;"
```

# Troubleshooting Guide

```text
Problem: user cannot connect to the database
    |
    v
[1] Is the database service running?
    systemctl status postgresql / systemctl status mysql
    |
    +-- not running --> start it, check logs
    |
    v
[2] Does the user exist?
    PostgreSQL: \du  |  MySQL: SELECT user, host FROM mysql.user;
    |
    +-- user not found --> CREATE USER / CREATE ROLE
    |
    v
[3] Is the password correct?
    Try connecting: psql -U user -d db  /  mysql -u user -p
    |
    +-- auth failed (PostgreSQL) --> check pg_hba.conf method and order
    +-- auth failed (MySQL) --> check user@host match, password, auth plugin
    |
    v
[4] Is the host allowed?
    PostgreSQL: check pg_hba.conf for matching host/address line
    MySQL: check user@host -- 'app'@'localhost' != 'app'@'10.0.0.5'
    |
    +-- no matching rule --> add pg_hba.conf entry / create user with correct host
    |
    v
[5] Does the user have the right privileges?
    PostgreSQL: \dp table_name  |  MySQL: SHOW GRANTS FOR 'user'@'host';
    |
    +-- missing grants --> GRANT required privileges
    |
    v
[6] Is SSL required but not used?
    Check if hostssl is required in pg_hba.conf / REQUIRE SSL in MySQL
    |
    +-- SSL missing --> connect with sslmode=require / --ssl-mode=REQUIRED
```

# Quick Facts (Revision)

- PostgreSQL: roles are users (with LOGIN) or groups (without LOGIN); MySQL: users are `'name'@'host'` pairs.
- PostgreSQL `pg_hba.conf` is evaluated top to bottom -- first matching rule wins; reload after editing.
- MySQL `FLUSH PRIVILEGES` is needed after direct edits to grant tables (not after GRANT/REVOKE statements).
- Use `scram-sha-256` (PostgreSQL) or `caching_sha2_password` (MySQL 8) -- avoid legacy md5/mysql_native_password for new setups.
- Never use the superuser/root account for application connections.
- Separate users per application limits blast radius of credential leaks.
- Always restrict user host access: use specific IPs or subnets, not `'%'` or `0.0.0.0/0`.
- Use `hostssl` in pg_hba.conf or `REQUIRE SSL` in MySQL to enforce encrypted connections.
