# Cloud Computing

- Cloud delivers compute, storage, networking, and databases as on-demand services over the internet.
- Service models: IaaS (infrastructure), PaaS (platform), SaaS (software) — each abstracts more from the customer.
- Key properties: elasticity (scale up/down), pay-per-use, global availability, managed services.

# Core Building Blocks

### IaaS, PaaS, SaaS

| Model | You Manage | Provider Manages | Example |
|-------|-----------|-----------------|---------|
| IaaS | OS, runtime, app, data | Hardware, network, virtualization | EC2, GCE |
| PaaS | App and data | OS, runtime, infra | Elastic Beanstalk, Heroku |
| SaaS | Nothing (use it) | Everything | Gmail, Slack |

### Region and Availability Zone

- **Region**: Geographic area with multiple data centers (e.g. us-east-1, eu-west-1).
- **Availability Zone (AZ)**: Isolated data center(s) within a region; deploy across AZs for HA.
- **Edge Location**: CDN/DNS point of presence for low-latency content delivery.

### Shared Responsibility

- **Provider**: Physical security, hardware, networking, hypervisor.
- **Customer**: Data, identity, access control, OS patching (IaaS), application config.
- PaaS/SaaS shifts more responsibility to provider; IaaS gives you more control.

---

# Topic Map (basic → advanced)

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
