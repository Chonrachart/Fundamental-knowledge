# Cloud Computing

- Cloud computing delivers compute, storage, networking, and databases as on-demand services over the internet.
- Instead of owning physical hardware, you rent resources from a provider and pay only for what you use.
- Key properties: elasticity (scale up/down automatically), pay-per-use billing, global availability across regions, and managed services that offload operational burden.
- Service models (IaaS, PaaS, SaaS) define how much the provider manages vs. how much you control.


# Architecture

```text
User Request
    |
    v
Cloud Provider (AWS, Azure, GCP)
    |
    v
Region (geographic area, e.g. us-east-1)
    |
    v
Availability Zone (isolated data center within region)
    |
    v
Services
    ├── IaaS (VMs, storage, networking)
    ├── PaaS (managed platforms, databases)
    └── SaaS (applications)
```

- Users interact with the cloud provider through console, CLI, or API.
- The provider organizes infrastructure into regions for geographic proximity and compliance.
- Each region contains multiple AZs for fault isolation and high availability.
- Services are deployed within AZs; spreading across AZs protects against single-datacenter failures.


# Mental Model

```text
Choose Provider (AWS, Azure, GCP)
    |
    v
Select Region (latency, compliance, cost)
    |
    v
Pick Service Model (IaaS for control, PaaS for convenience, SaaS for turnkey)
    |
    v
Configure Resources (VPC, compute, storage, IAM)
    |
    v
Deploy and Monitor (CI/CD, logging, alerts)
```

Example — deploying a web app on AWS:

```text
1. Provider: AWS
2. Region: ap-southeast-1 (closest to users in Southeast Asia)
3. Service model: IaaS (EC2 for full OS control)
4. Resources: VPC with public/private subnets, EC2 instances, RDS database, S3 for static assets
5. Deploy: push code via CI/CD, monitor with CloudWatch
```


# Core Building Blocks

### Service Models (IaaS / PaaS / SaaS)

- Cloud services are categorized by how much the provider manages on your behalf.
- Moving from IaaS to SaaS trades control for convenience.

| Model | You Manage | Provider Manages | Example |
|-------|-----------|-----------------|---------|
| IaaS | OS, runtime, app, data | Hardware, network, virtualization | EC2, GCE |
| PaaS | App and data | OS, runtime, infra | Elastic Beanstalk, Heroku |
| SaaS | Nothing (use it) | Everything | Gmail, Slack |

- **IaaS**: maximum flexibility, you handle patching and scaling — best for custom workloads.
- **PaaS**: focus on code, platform handles infrastructure — best for standard web apps.
- **SaaS**: consume the service as-is — best for productivity tools and off-the-shelf software.

Related notes: [AWS/001-aws-overview](./AWS/001-aws-overview.md)

### Regions and Availability Zones

- **Region**: geographic area with multiple data centers (e.g. us-east-1, eu-west-1, ap-southeast-1).
- **Availability Zone (AZ)**: one or more isolated data centers within a region, each with independent power, cooling, and networking.
- Deploy across AZs for high availability — if one AZ fails, the others continue serving traffic.
- Choose region based on: proximity to users (latency), data residency laws (compliance), service availability, and pricing.

Related notes: [AWS/001-aws-overview](./AWS/001-aws-overview.md), [AWS/003-vpc-networking](./AWS/003-vpc-networking.md)

### Shared Responsibility Model

- Cloud security is split between provider and customer — understanding the boundary prevents gaps.
- **Provider responsibility**: physical security, hardware, networking, hypervisor, managed service internals.
- **Customer responsibility**: data encryption, identity and access control, OS patching (IaaS), application configuration, firewall rules.
- The boundary shifts with service model:
  - IaaS — customer manages the most (OS, runtime, app, data).
  - PaaS — provider takes over OS and runtime; customer manages app and data.
  - SaaS — provider manages nearly everything; customer manages access and data.

Related notes: [AWS/002-iam](./AWS/002-iam.md)

### Edge Locations and CDN

- **Edge Location**: a point of presence (PoP) outside of regions, used for caching content closer to end users.
- **CDN (Content Delivery Network)**: distributes static assets (images, CSS, JS) to edge locations worldwide, reducing latency.
- Example: AWS CloudFront caches S3 objects at edge locations so users in Tokyo get content from a nearby PoP instead of the origin in us-east-1.
- Also used for DNS resolution (e.g. Route 53) and DDoS protection (e.g. AWS Shield).

Related notes: [AWS/001-aws-overview](./AWS/001-aws-overview.md), [AWS/005-s3](./AWS/005-s3.md)


# Troubleshooting Guide

### Wrong region selected
1. Check current region in console or CLI: `aws configure get region`.
2. Verify resources exist in expected region: `aws ec2 describe-instances --region <region>`.
3. Resources are region-scoped — creating in wrong region means they won't appear in the expected one.

### Connectivity issues (firewall / security groups)
1. Check security group inbound rules: `aws ec2 describe-security-groups --group-ids <sg-id>`.
2. Verify NACL rules on the subnet allow traffic in both directions.
3. Confirm route table has a route to the internet gateway (for public subnets) or NAT gateway (for private subnets).
4. Test connectivity: `curl -v http://<endpoint>` or `telnet <ip> <port>`.

### Permission denied (IAM / resource policies)
1. Check which identity is being used: `aws sts get-caller-identity`.
2. Review attached IAM policies for the user/role.
3. Look for explicit deny in resource-based policies (S3 bucket policy, KMS key policy).
4. Use IAM Policy Simulator to test permissions: `aws iam simulate-principal-policy`.


---

# Topic Map (basic -> advanced)

### AWS
- [AWS/001-aws-overview](./AWS/001-aws-overview.md) — Regions, AZs, service categories, pricing models
- [AWS/002-iam](./AWS/002-iam.md) — Users, groups, roles, policies, least privilege
- [AWS/003-vpc-networking](./AWS/003-vpc-networking.md) — VPC, subnets, routing, IGW, NAT, SG, NACL, peering
- [AWS/004-ec2](./AWS/004-ec2.md) — Instance types, AMI, EBS, user data, instance profiles
- [AWS/005-s3](./AWS/005-s3.md) — Buckets, objects, storage classes, versioning, lifecycle
- [AWS/006-rds-databases](./AWS/006-rds-databases.md) — RDS, Multi-AZ, read replicas, Aurora, DynamoDB
- [AWS/007-elb-auto-scaling](./AWS/007-elb-auto-scaling.md) — ALB, NLB, target groups, Auto Scaling Groups
- [AWS/008-ecs-eks](./AWS/008-ecs-eks.md) — ECS, Fargate, EKS, ECR, container orchestration
- [AWS/009-lambda-serverless](./AWS/009-lambda-serverless.md) — Lambda, API Gateway, event-driven patterns
