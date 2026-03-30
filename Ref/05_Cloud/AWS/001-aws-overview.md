# AWS Overview

- Amazon Web Services is the largest cloud platform with 200+ services across compute, storage, networking, and databases.
- Pay-as-you-go pricing with multiple commitment options for cost optimization.
- For regions, AZs, and edge locations, see [../000-core](../000-core.md)
- For the Shared Responsibility Model, see [../000-core](../000-core.md)
- For AWS service categories, see [000-core](./000-core.md)

# Architecture

```text
AWS Global Infrastructure:

+------------------------------------------------------------------+
|                        AWS Cloud                                  |
|  +------------------+  +------------------+  +----------------+  |
|  | Region: us-east-1|  | Region: eu-west-1|  | Region: ap-..  |  |
|  |  +------+ +------+  |  +------+ +------+  |                |  |
|  |  | AZ-a | | AZ-b |  |  | AZ-a | | AZ-b |  |    ...         |  |
|  |  +------+ +------+  |  +------+ +------+  |                |  |
|  +------------------+  +------------------+  +----------------+  |
|                                                                  |
|  Edge Locations (CloudFront CDN) -- 400+ worldwide               |
+------------------------------------------------------------------+
```

# Mental Model

```text
AWS Request Flow:

1. User authenticates via IAM
2. Request hits the AWS API endpoint for the target region
3. Service processes request within the selected AZ
4. Resources provisioned within VPC (if applicable)
5. Response returned, logged in CloudTrail
```

Example — launching an EC2 instance:
```bash
# 1. Authenticate (IAM credentials or role)
aws sts get-caller-identity

# 2-4. Request targets us-east-1, provisions in AZ us-east-1a inside your VPC
aws ec2 run-instances --image-id ami-0abcdef --instance-type t3.micro \
  --subnet-id subnet-abc123 --region us-east-1

# 5. Response includes instance ID; event logged in CloudTrail
```

# Core Building Blocks

### AWS CLI and Access

```bash
aws configure                          # set access key, secret, region
aws sts get-caller-identity            # verify current identity
aws ec2 describe-instances             # list EC2 instances
aws s3 ls                              # list S3 buckets
```

- Prefer IAM roles over access keys.
- Use `aws-vault` or SSO for secure credential management.
- `aws sts get-caller-identity` is the first debugging step for permission issues.

Related notes: [002-iam](./002-iam.md)

### Pricing Models

| Model | Use Case |
|-------|----------|
| On-Demand | Default; pay per hour/second; no commitment |
| Reserved (1-3yr) | Steady-state workloads; up to 72% discount |
| Spot | Fault-tolerant workloads; up to 90% discount; can be interrupted |
| Savings Plans | Flexible commitment; applies across instance families |

- Spot instances save up to 90% but can be interrupted with 2-minute warning.
- Use tags for cost allocation, automation, and access control.

Related notes: [004-ec2](./004-ec2.md), [009-lambda-serverless](./009-lambda-serverless.md)
