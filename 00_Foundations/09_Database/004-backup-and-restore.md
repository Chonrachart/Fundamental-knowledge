# Backup and Restore

- Backups are your last line of defence against data loss -- hardware failure, human error, ransomware, and bad deployments all happen.
- Logical backups export SQL statements (portable, slow for large DBs); physical backups copy raw data files (fast, engine-specific).
- A backup that has never been restored is not a backup -- test your restores regularly.

# Architecture

```text
+----------------+       +---------------+       +------------------+
|   Live DB      |------>|  Backup Tool  |------>|  Backup File     |
| (MySQL / PG)   |       | mysqldump     |       | .sql / .dump     |
|                |       | pg_dump       |       | .tar.gz          |
|                |       | xtrabackup    |       |                  |
|                |       | pg_basebackup |       |                  |
+----------------+       +---------------+       +------------------+
                                                        |
                                                        v
                                               +------------------+
                                               |  Storage         |
                                               |  - local disk    |
                                               |  - NFS / S3      |
                                               |  - offsite copy  |
                                               +------------------+
                                                        |
                                                        v
                                               +------------------+
                                               |  Retention       |
                                               |  rotate: N days  |
                                               |  compress: gzip  |
                                               +------------------+

Restore path (reverse):
  Storage --> backup file --> restore tool --> target DB (staging or prod)
```

# Mental Model

```text
Backup strategy decision tree:

  How big is the database?
      |
      +-- small (< ~50 GB) --> logical backup (mysqldump / pg_dump)
      |                            fast enough, portable, human-readable
      |
      +-- large (> ~50 GB) --> physical backup (xtrabackup / pg_basebackup)
      |                            much faster, but tied to engine version
      |
  Do you need point-in-time recovery?
      |
      +-- yes --> enable binary logs (MySQL) or WAL archiving (PostgreSQL)
      |           full backup + replay logs to exact timestamp
      |
      +-- no  --> scheduled full dumps are sufficient

  Backup type recap:
    Full         -- complete copy every time
    Incremental  -- only changes since last backup (any type)
    Differential -- only changes since last full backup
```

```text
Example: nightly logical backup of a PostgreSQL database

  [1] pg_dump -Fc mydb > /backups/mydb_2026-03-16.dump
  [2] gzip /backups/mydb_2026-03-16.dump
  [3] upload to S3 / copy to offsite storage
  [4] delete local backups older than 7 days
  [5] weekly: restore latest dump to staging and verify
```

# Core Building Blocks

### Backup Types

- **Logical backup** -- exports data as SQL statements or archive format.
  - Portable across versions and sometimes across engines.
  - Slower for large databases (reads every row, generates SQL).
  - Tools: `mysqldump`, `pg_dump`, `pg_dumpall`.
- **Physical backup** -- copies raw data files (datadir, tablespaces, WAL/binlog).
  - Much faster for large databases.
  - Must match engine version exactly on restore.
  - Tools: `pg_basebackup`, Percona XtraBackup, filesystem snapshots (LVM, ZFS).
- **Full** -- complete copy of the database every run.
- **Incremental** -- only data changed since the last backup (full or incremental).
- **Differential** -- only data changed since the last full backup.

Related notes: [001-database-concepts](./001-database-concepts.md), [002-sql-essentials](./002-sql-essentials.md)

### MySQL Backup (mysqldump)

- `mysqldump` is the standard logical backup tool for MySQL / MariaDB.
- Use `--single-transaction` for InnoDB tables to get a consistent snapshot without locking.
- For MyISAM or mixed engines, `--lock-all-tables` is needed (causes downtime).

```bash
# single database
mysqldump --single-transaction -u root -p mydb > mydb.sql

# all databases
mysqldump --single-transaction --all-databases -u root -p > all_dbs.sql

# single table
mysqldump --single-transaction -u root -p mydb users > mydb_users.sql

# with compression
mysqldump --single-transaction -u root -p mydb | gzip > mydb_$(date +%F).sql.gz

# check binary log position (for PITR)
mysql -e "SHOW MASTER STATUS\G"
```

- **Restore:**

```bash
# restore a single database dump
mysql -u root -p mydb < mydb.sql

# restore from compressed backup
gunzip < mydb_2026-03-16.sql.gz | mysql -u root -p mydb

# restore all databases
mysql -u root -p < all_dbs.sql
```

Related notes: [003-user-and-access-management](./003-user-and-access-management.md)

### PostgreSQL Backup (pg_dump / pg_dumpall)

- `pg_dump` backs up a single database. `pg_dumpall` includes roles and all databases.
- Output formats: plain SQL (default), custom `-Fc` (compressed, supports selective restore), directory `-Fd` (parallel dump).
- `pg_restore` handles custom and directory formats; plain SQL uses `psql`.

```bash
# plain SQL format
pg_dump mydb > mydb.sql

# custom format (compressed, most flexible)
pg_dump -Fc mydb > mydb.dump

# directory format (parallel dump with -j)
pg_dump -Fd -j 4 mydb -f /backups/mydb_dir/

# all databases + roles
pg_dumpall > all_dbs.sql
```

- **Restore:**

```bash
# restore plain SQL
psql mydb < mydb.sql

# restore custom format (can select specific tables)
pg_restore -d mydb mydb.dump

# restore custom format -- clean (drop) + create objects
pg_restore -d mydb --clean --create mydb.dump

# restore specific table from custom dump
pg_restore -d mydb -t users mydb.dump

# list contents of a custom dump without restoring
pg_restore -l mydb.dump

# check WAL archiving status (for PITR readiness)
psql -c "SELECT * FROM pg_stat_archiver;"
```

Related notes: [003-user-and-access-management](./003-user-and-access-management.md)

### Physical Backups

- Best for large databases where logical dumps take too long.
- Produce a binary copy of the data directory -- fast backup and fast restore.
- Require the same (or compatible) engine version on restore.

```bash
# PostgreSQL -- pg_basebackup (streams a full copy from a running server)
pg_basebackup -D /backups/pg_base_2026-03-16 -Ft -z -P -X stream

# MySQL -- Percona XtraBackup (hot backup for InnoDB, no locking)
xtrabackup --backup --target-dir=/backups/mysql_base_2026-03-16
xtrabackup --prepare --target-dir=/backups/mysql_base_2026-03-16

# restore xtrabackup (stop MySQL, replace datadir, fix permissions)
systemctl stop mysql
xtrabackup --copy-back --target-dir=/backups/mysql_base_2026-03-16
chown -R mysql:mysql /var/lib/mysql
systemctl start mysql
```

Related notes: [005-replication-and-ha](./005-replication-and-ha.md)

### Automation and Retention

- Schedule backups with cron; never rely on manual runs.
- Use a consistent naming convention with timestamps for easy identification.
- Compress backups to save storage (gzip, zstd).
- Implement retention: keep N daily, N weekly, N monthly backups.

```bash
# example cron entry: nightly PostgreSQL backup at 02:00
# 0 2 * * * /usr/local/bin/backup_pg.sh >> /var/log/pg_backup.log 2>&1

# simple backup script skeleton
#!/bin/bash
DATE=$(date +%F_%H%M)
BACKUP_DIR="/backups/postgres"
DB="mydb"

pg_dump -Fc "$DB" > "${BACKUP_DIR}/${DB}_${DATE}.dump"

# retain only last 7 days of backups
find "$BACKUP_DIR" -name "${DB}_*.dump" -mtime +7 -delete
```

Related notes: [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md)

### Testing Restores
```text
Restore test checklist:
  [1] Copy backup file to staging server
  [2] Restore into a test database
  [3] Run application smoke tests against it
  [4] Compare row counts on critical tables vs production
  [5] Record time taken (= your realistic RTO)
  [6] Log result: pass/fail + date
```

Related notes: [006-monitoring-and-troubleshooting](./006-monitoring-and-troubleshooting.md)
- A backup you have never restored is a backup you hope works -- hope is not a strategy.
- Schedule periodic restore tests to a staging server (weekly or monthly).
- Verify row counts, application functionality, and data integrity after restore.
- Document restore time so you know your RTO (Recovery Time Objective).
