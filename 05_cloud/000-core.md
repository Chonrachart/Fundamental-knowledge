overview of

    cloud
    IaaS
    PaaS
    SaaS
    region
    availability zone

---

# Cloud

- On-demand compute, storage, and services over the internet; pay per use.
- Scalable; no need to own and maintain physical hardware.

# IaaS, PaaS, SaaS

- **IaaS**: Virtual machines, networks, storage (e.g. EC2, VPC).
- **PaaS**: Runtime and platform (e.g. managed DB, app runtimes).
- **SaaS**: Application delivered over the web (e.g. Gmail, Salesforce).

# Region / Availability Zone

- **Region**: Geographic area (e.g. us-east-1); contains multiple AZs.
- **Availability Zone**: Isolated datacenter(s) in a region; use multiple AZs for resilience.

# Shared Responsibility

- **Cloud provider**: Security of cloud (hardware, hypervisor, physical network); managed service patching.
- **Customer**: Security in cloud (OS, app, IAM, network config, data encryption).
- IaaS: more customer responsibility; SaaS: less.

# Topic Map (basic → advanced)

- [AWS/001-aws-overview](./AWS/001-aws-overview.md) — Region, AZ, EC2, VPC, S3, IAM (start here)
- [AWS/002-ec2-vpc](./AWS/002-ec2-vpc.md) — EC2, AMI, security group, VPC, subnet, NAT
- [AWS/003-s3-iam](./AWS/003-s3-iam.md) — S3, bucket, storage class, IAM, policy, role
- [AWS/004-rds-lambda](./AWS/004-rds-lambda.md) — RDS, Lambda, API Gateway
- [AWS/005-ec2-deep-dive](./AWS/005-ec2-deep-dive.md) — Instance types, EBS, AMI, user data, instance profile
- [AWS/006-vpc-networking-deep-dive](./AWS/006-vpc-networking-deep-dive.md) — VPC, route table, IGW, NAT, SG, NACL, peering
