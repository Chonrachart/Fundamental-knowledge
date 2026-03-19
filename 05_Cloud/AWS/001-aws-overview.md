AWS
region
AZ
EC2
VPC
S3
IAM

---

# AWS

- Amazon Web Services; broad set of cloud services (compute, storage, network, databases, etc.).
- Global infrastructure: regions and Availability Zones (AZs).

# Region and AZ

- **Region**: e.g. `us-east-1`, `ap-southeast-1`; choose for latency and compliance.
- **Availability Zone**: Isolated location within a region; use multiple AZs for HA.

# EC2

- Virtual servers (instances); choose AMI, instance type, storage, networking.
- Key pairs for SSH; security groups as firewall.

# VPC

- Virtual Private Cloud; isolated network; subnets (public/private), route tables, NACLs.
- Control how instances are exposed (public IP, NAT, load balancer).

# S3

- Object storage; buckets and keys; durability and availability by storage class.
- Use for static assets, backups, data lakes; versioning and lifecycle rules available.

# IAM

- Identity and Access Management; users, groups, roles, policies.
- Principle of least privilege; use roles for services; avoid long-term keys where possible.

# Common Services (Overview)

| Service   | Purpose              |
| :-------- | :------------------- |
| EC2      | Virtual servers      |
| VPC      | Networking           |
| S3       | Object storage       |
| RDS      | Managed database     |
| Lambda   | Serverless functions |
| IAM      | Access control       |
