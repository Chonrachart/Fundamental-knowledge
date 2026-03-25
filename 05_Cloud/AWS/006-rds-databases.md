# RDS and Databases

- RDS (Relational Database Service) is a managed database supporting MySQL, PostgreSQL, MariaDB, Oracle, and SQL Server.
- Multi-AZ provides high availability with automatic failover; read replicas offload read traffic.
- Automated backups, snapshots, and encryption at rest/in-transit are built-in.

# Architecture

```text
              Application
                  │
          ┌───────┴───────┐
          │  RDS Endpoint  │ (DNS — same after failover)
          └───────┬───────┘
                  │
    ┌─────────────┼─────────────────────────────┐
    │ VPC         │                              │
    │  ┌──────────┴──────────┐                   │
    │  │     AZ-a            │    AZ-b           │
    │  │ ┌────────────────┐  │ ┌──────────────┐  │
    │  │ │  Primary (RW)  │  │ │  Standby     │  │
    │  │ │  db.m5.large   │──┼─│  (sync repl) │  │
    │  │ └───────┬────────┘  │ └──────────────┘  │
    │  │         │           │                   │
    │  └─────────┼───────────┘                   │
    │            │ async replication              │
    │  ┌─────────┴───────────┐                   │
    │  │  Read Replica (RO)  │  (same or cross   │
    │  │  separate endpoint  │   region)         │
    │  └─────────────────────┘                   │
    └────────────────────────────────────────────┘
```

# Mental Model

RDS provisioning flow — from engine selection to production-ready:

```text
1. Choose engine (MySQL, PostgreSQL, Aurora...)
         │
2. Select instance class (db.t3.medium, etc.)
         │
3. Configure storage (gp3, io1, size)
         │
4. Set VPC, subnet group, security group
         │
5. Enable Multi-AZ for HA (automatic failover)
         │
6. Create read replicas for read scaling
         │
7. Configure automated backups + retention
```

Example — create a Multi-AZ RDS instance:
```bash
aws rds create-db-instance \
  --db-instance-identifier mydb-prod \
  --db-instance-class db.m5.large \
  --engine postgres \
  --allocated-storage 100 \
  --storage-type gp3 \
  --multi-az \
  --vpc-security-group-ids sg-0123456789abcdef0 \
  --db-subnet-group-name my-subnet-group \
  --backup-retention-period 7
```

# Core Building Blocks

### RDS Basics

- **Instance class**: CPU and memory (e.g. `db.t3.micro`, `db.m5.large`).
- **Storage**: gp3 (general SSD), io2 (high IOPS); auto-scaling available.
- **Engine**: MySQL, PostgreSQL, MariaDB, Oracle, SQL Server; each with version choices.
- **Parameter group**: Database engine configuration (like `my.cnf` for MySQL).
- **Security**: Runs in VPC; accessed via Security Group; encryption at rest (KMS); SSL for connections.
- RDS handles OS patching, backups, and failover; you manage schema, queries, and engine tuning.
- Enable encryption at rest when creating the instance — can't enable later.
- RDS instances should always be in private subnets.

Related notes: [003-vpc-networking](./003-vpc-networking.md), [002-iam](./002-iam.md)

### Multi-AZ

- Synchronous standby replica in another AZ; automatic failover on primary failure.
- DNS endpoint stays the same; failover takes 1-2 minutes.
- Not for read scaling — standby is passive.
- Multi-AZ is for HA (automatic failover); read replicas are for read scaling.

Related notes: [003-vpc-networking](./003-vpc-networking.md)

### Read Replicas

- Asynchronous replication; use for read-heavy workloads.
- Can be in same AZ, different AZ, or different region (cross-region).
- Can be promoted to standalone DB (breaks replication).
- Up to 15 replicas for Aurora; 5 for standard RDS.

Related notes: [001-aws-overview](./001-aws-overview.md)

### Backups and Snapshots

| Type | Automated | Manual |
|------|-----------|--------|
| Trigger | Backup window (daily) | On-demand |
| Retention | 1-35 days (configurable) | Until deleted |
| Point-in-time | Yes (transaction logs) | No |
| Restore | Creates new instance | Creates new instance |
- Restoring a backup or snapshot always creates a NEW RDS instance.
- Point-in-time recovery lets you restore to any second within the retention period.

Related notes: [005-s3](./005-s3.md)

### Aurora

- AWS-proprietary; MySQL and PostgreSQL compatible; up to 5x MySQL / 3x PostgreSQL performance.
- Storage auto-scales (10 GB to 128 TB); 6 copies across 3 AZs.
- Serverless mode: auto-scales compute; pay per ACU-second.
- Aurora stores 6 copies of data across 3 AZs automatically.

Related notes: [001-aws-overview](./001-aws-overview.md)

### DynamoDB (Overview)

- Managed NoSQL key-value/document database.
- Single-digit millisecond performance at any scale.
- **Modes**: On-demand (pay per request) or provisioned (set read/write capacity).
- **Partition key** + optional **sort key**; no joins, no SQL.
- DynamoDB is serverless NoSQL; no maintenance, no patching.

Related notes: [001-aws-overview](./001-aws-overview.md), [002-iam](./002-iam.md)

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
