# RDS and Databases

- RDS (Relational Database Service) is a managed database supporting MySQL, PostgreSQL, MariaDB, Oracle, and SQL Server.
- Multi-AZ provides high availability with automatic failover; read replicas offload read traffic.
- Automated backups, snapshots, and encryption at rest/in-transit are built-in.

# Core Building Blocks

### RDS Basics

- **Instance class**: CPU and memory (e.g. `db.t3.micro`, `db.m5.large`).
- **Storage**: gp3 (general SSD), io2 (high IOPS); auto-scaling available.
- **Engine**: MySQL, PostgreSQL, MariaDB, Oracle, SQL Server; each with version choices.
- **Parameter group**: Database engine configuration (like `my.cnf` for MySQL).
- **Security**: Runs in VPC; accessed via Security Group; encryption at rest (KMS); SSL for connections.

### Multi-AZ

- Synchronous standby replica in another AZ; automatic failover on primary failure.
- DNS endpoint stays the same; failover takes 1-2 minutes.
- Not for read scaling — standby is passive.

### Read Replicas

- Asynchronous replication; use for read-heavy workloads.
- Can be in same AZ, different AZ, or different region (cross-region).
- Can be promoted to standalone DB (breaks replication).
- Up to 15 replicas for Aurora; 5 for standard RDS.

### Backups and Snapshots

| Type | Automated | Manual |
|------|-----------|--------|
| Trigger | Backup window (daily) | On-demand |
| Retention | 1-35 days (configurable) | Until deleted |
| Point-in-time | Yes (transaction logs) | No |
| Restore | Creates new instance | Creates new instance |

### Aurora

- AWS-proprietary; MySQL and PostgreSQL compatible; up to 5x MySQL / 3x PostgreSQL performance.
- Storage auto-scales (10 GB to 128 TB); 6 copies across 3 AZs.
- Serverless mode: auto-scales compute; pay per ACU-second.

### DynamoDB (Overview)

- Managed NoSQL key-value/document database.
- Single-digit millisecond performance at any scale.
- **Modes**: On-demand (pay per request) or provisioned (set read/write capacity).
- **Partition key** + optional **sort key**; no joins, no SQL.

Related notes: [001-aws-overview](./001-aws-overview.md), [003-vpc-networking](./003-vpc-networking.md)

---

# Troubleshooting Guide

### Cannot connect to RDS instance
1. Check Security Group: allows inbound on DB port (3306 MySQL, 5432 PostgreSQL) from app's SG.
2. Check RDS is in the correct VPC and subnet group.
3. Check "Publicly Accessible" setting if connecting from outside VPC.
4. Check credentials and database name.

### High replication lag on read replica
1. Check replica instance class — undersized replica can't keep up.
2. Check for long-running write transactions on primary.
3. Consider upgrading replica instance class or adding more replicas.

### Restore takes too long
1. Restores create a new instance — copy time depends on size.
2. Use point-in-time restore for most recent data (up to 5 minutes ago).
3. Snapshots of large databases take longer; plan restore testing.

# Quick Facts (Revision)

- RDS handles OS patching, backups, and failover; you manage schema, queries, and engine tuning.
- Multi-AZ is for HA (automatic failover); read replicas are for read scaling.
- Restoring a backup or snapshot always creates a NEW RDS instance.
- Aurora stores 6 copies of data across 3 AZs automatically.
- DynamoDB is serverless NoSQL; no maintenance, no patching.
- Enable encryption at rest when creating the instance — can't enable later.
- Point-in-time recovery lets you restore to any second within the retention period.
- RDS instances should always be in private subnets.
