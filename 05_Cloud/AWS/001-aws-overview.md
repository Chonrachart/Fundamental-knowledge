# AWS Overview

- Amazon Web Services is the largest cloud platform with 200+ services across compute, storage, networking, and databases.
- Global infrastructure: 30+ Regions, each with 3+ Availability Zones; Edge Locations for CDN and DNS.
- Pay-as-you-go pricing; shared responsibility model separates AWS infrastructure security from customer data security.

# Core Building Blocks

### Regions and Availability Zones

- **Region**: Geographic area (e.g. us-east-1, eu-west-1); choose based on latency, compliance, service availability, cost.
- **AZ**: One or more isolated data centers within a region; connected by low-latency links.
- **Multi-AZ**: Deploy across AZs for high availability; if one AZ fails, others continue.
- **Edge Locations**: CDN (CloudFront) and DNS (Route 53) points of presence worldwide.

### Service Categories

| Category | Key Services |
|----------|-------------|
| Compute | EC2, Lambda, ECS, EKS, Fargate |
| Storage | S3, EBS, EFS, Glacier |
| Networking | VPC, Route 53, CloudFront, ELB |
| Database | RDS, DynamoDB, ElastiCache, Aurora |
| Security | IAM, KMS, Secrets Manager, WAF |
| Monitoring | CloudWatch, CloudTrail, X-Ray |
| IaC | CloudFormation, CDK |
| Containers | ECS, EKS, ECR, Fargate |

### Shared Responsibility Model

```text
Customer responsibility ("security IN the cloud"):
  ├── Data encryption and classification
  ├── IAM (users, roles, policies)
  ├── OS patching (EC2)
  ├── Network config (SG, NACL, VPC)
  └── Application code and dependencies

AWS responsibility ("security OF the cloud"):
  ├── Physical data centers
  ├── Hardware and networking
  ├── Hypervisor and host OS
  └── Managed service infrastructure (RDS, Lambda, S3)
```

### AWS CLI and Access

```bash
aws configure                          # set access key, secret, region
aws sts get-caller-identity            # verify current identity
aws ec2 describe-instances             # list EC2 instances
aws s3 ls                              # list S3 buckets
```

- Prefer IAM roles over access keys.
- Use `aws-vault` or SSO for secure credential management.

### Pricing Models

| Model | Use Case |
|-------|----------|
| On-Demand | Default; pay per hour/second; no commitment |
| Reserved (1–3yr) | Steady-state workloads; up to 72% discount |
| Spot | Fault-tolerant workloads; up to 90% discount; can be interrupted |
| Savings Plans | Flexible commitment; applies across instance families |

Related notes: [002-iam](./002-iam.md), [003-vpc-networking](./003-vpc-networking.md), [004-ec2](./004-ec2.md)

---

# Troubleshooting Guide

### AWS CLI "Unable to locate credentials"
1. Check `aws configure` has been run: `cat ~/.aws/credentials`.
2. Check env vars: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
3. On EC2: check instance profile is attached (uses IMDS for credentials).

### Service not available in region
1. Not all services are in every region; check AWS Regional Services list.
2. Some services are global: IAM, Route 53, CloudFront, S3 (namespace).
3. Switch region with `--region` flag or `AWS_DEFAULT_REGION`.

### Unexpected charges
1. Check for running EC2 instances, NAT Gateways, and unattached Elastic IPs.
2. Use AWS Cost Explorer or Billing Dashboard.
3. Enable AWS Budgets for alerts.

# Quick Facts (Revision)

- Region = geographic area; AZ = isolated data center(s) within a region.
- IAM, Route 53, CloudFront, and S3 namespace are global; most services are regional.
- Shared responsibility: AWS secures infrastructure; you secure your configs, data, and access.
- Spot instances save up to 90% but can be interrupted with 2-minute warning.
- Use tags for cost allocation, automation, and access control.
- `aws sts get-caller-identity` is the first debugging step for permission issues.
- Always enable MFA on root account; use IAM users/roles for daily work.
