# AWS (Amazon Web Services)

- Cloud platform with 200+ services spanning compute, storage, networking, databases, security, and more.
- Global infrastructure: Regions (geographic), Availability Zones (isolated data centers within a region), Edge Locations (CDN).
- Shared responsibility model: AWS secures infrastructure; you secure your data, config, and access.

# Architecture

```text
AWS Global Infrastructure
├── Region (us-east-1, eu-west-1, ap-southeast-1)
│     ├── Availability Zone (us-east-1a)
│     │     └── Data Center(s) — isolated power, networking, cooling
│     ├── Availability Zone (us-east-1b)
│     └── Availability Zone (us-east-1c)
│
└── Edge Locations (CloudFront CDN, Route 53 DNS)

Your Account
├── VPC (virtual network per region)
│     ├── Public Subnet (IGW → internet)
│     │     ├── EC2 instances, NAT Gateway, ALB
│     │     └── Security Group (stateful firewall)
│     └── Private Subnet (NAT → outbound only)
│           ├── EC2, RDS, Lambda
│           └── Security Group
├── IAM (global — users, roles, policies)
├── S3 (global namespace — object storage)
└── CloudWatch (monitoring and logs)
```

# Mental Model

```text
1. Choose Region (latency, compliance, cost)
2. Create VPC with subnets across AZs (high availability)
3. Set up IAM roles (least privilege, no long-lived keys)
4. Deploy compute (EC2, ECS, Lambda)
5. Store data (S3, EBS, RDS)
6. Expose (ALB, Route 53, CloudFront)
7. Monitor (CloudWatch metrics, logs, alarms)
```

# Core Building Blocks

### Compute

- **EC2**: Virtual machines; choose instance type, AMI, and storage.
- **ECS/EKS**: Container orchestration (Docker, Kubernetes).
- **Lambda**: Serverless functions; event-driven; no servers to manage.

Related notes: [004-ec2](./004-ec2.md), [008-ecs-eks](./008-ecs-eks.md), [009-lambda-serverless](./009-lambda-serverless.md)

### Networking

- **VPC**: Isolated virtual network; subnets, route tables, gateways.
- **Security Group**: Stateful firewall at instance level.
- **ALB/NLB**: Load balancing across targets.
- **Route 53**: DNS service.

Related notes: [003-vpc-networking](./003-vpc-networking.md), [007-elb-auto-scaling](./007-elb-auto-scaling.md)

### Storage

- **S3**: Object storage; durability 11 nines; lifecycle policies.
- **EBS**: Block storage attached to EC2; snapshots for backup.

Related notes: [005-s3](./005-s3.md), [004-ec2](./004-ec2.md)

### Database

- **RDS**: Managed relational DB (MySQL, PostgreSQL, etc.); Multi-AZ for HA.
- **DynamoDB**: Managed NoSQL; key-value; serverless mode available.

Related notes: [006-rds-databases](./006-rds-databases.md)

### Security and Identity

- **IAM**: Users, groups, roles, policies; global service.
- **Shared responsibility**: AWS secures hardware/network; you secure config, data, access.

Related notes: [002-iam](./002-iam.md)

---

# Troubleshooting Guide

### Cannot access EC2 instance from internet
1. Check subnet has route `0.0.0.0/0 → igw-xxx` (public subnet).
2. Check instance has public IP or Elastic IP.
3. Check security group allows inbound on the required port.
4. Check NACL allows traffic (if custom NACL configured).

### AWS CLI returns "Access Denied"
1. Check IAM policy: does the user/role have permission for this action on this resource?
2. Check resource policy (S3 bucket policy, KMS key policy) if applicable.
3. Use `aws sts get-caller-identity` to verify which identity is being used.

### Resources in wrong region
1. Check `AWS_DEFAULT_REGION` env var or `--region` flag.
2. AWS Console: check region selector in top-right corner.
3. Some services are global (IAM, Route 53, CloudFront); most are regional.

---

# Quick Facts (Revision)

- Region = geographic area; AZ = isolated data center within a region (typically 3 AZs per region).
- IAM is global; most other services are regional.
- S3 bucket names are globally unique; objects are region-specific.
- Security Groups are stateful (allow return traffic); NACLs are stateless (must allow both directions).
- Shared responsibility: AWS secures "of" the cloud; you secure "in" the cloud.
- Default VPC exists in every region; custom VPCs are recommended for production.
- Always use IAM roles (temporary credentials) over IAM users (long-lived keys).
- Multi-AZ deployments provide high availability within a region.

# Topic Map (basic → advanced)

- [001-aws-overview](./001-aws-overview.md) — Regions, AZs, service categories, global infrastructure
- [002-iam](./002-iam.md) — Users, groups, roles, policies, best practices
- [003-vpc-networking](./003-vpc-networking.md) — VPC, subnets, routing, IGW, NAT, SG, NACL, peering
- [004-ec2](./004-ec2.md) — Instances, AMI, EBS, user data, instance profiles, lifecycle
- [005-s3](./005-s3.md) — Buckets, objects, storage classes, versioning, lifecycle, policies
- [006-rds-databases](./006-rds-databases.md) — RDS, Multi-AZ, read replicas, backups, Aurora
- [007-elb-auto-scaling](./007-elb-auto-scaling.md) — ALB, NLB, target groups, Auto Scaling Groups
- [008-ecs-eks](./008-ecs-eks.md) — ECS, Fargate, EKS, container orchestration on AWS
- [009-lambda-serverless](./009-lambda-serverless.md) — Lambda, API Gateway, event-driven patterns
