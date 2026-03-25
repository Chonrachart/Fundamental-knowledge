# Lambda and Serverless

- Lambda runs code without servers; triggered by events (S3, API Gateway, SQS, schedule); billed per invocation + duration.
- API Gateway creates REST/HTTP APIs that front Lambda functions — the standard serverless API pattern.
- Serverless = no server management, auto-scaling, pay-per-use; trade control for operational simplicity.

# Architecture

```text
Event Sources                    Lambda Service                 Outputs
─────────────                    ──────────────                 ───────
API Gateway  ──┐                 ┌──────────────────────┐
S3 Events    ──┤                 │  Execution Environment│
SQS Queue    ──┼──► Invoke ────►│  ├── Runtime (Python)  │────► Response to caller
EventBridge  ──┤                 │  ├── Handler function  │────► Other AWS services
CloudWatch   ──┘                 │  └── Layers (deps)     │────► CloudWatch Logs
                                 └──────────────────────┘
```

# Mental Model

```text
Event source (S3 upload, HTTP request, SQS message, cron)
        │
        ▼
Lambda function invoked
  → cold start (if no warm container) → init code runs
  → handler function executes
  → returns result
        │
        ▼
Response to caller (API Gateway → HTTP response)
  or side effect (write to DynamoDB, send SNS)
```

# Core Building Blocks

### Lambda Basics

- **Runtime**: Python, Node.js, Go, Java, .NET, Ruby; or custom runtime (container image).
- **Handler**: Entry point function; receives event object and context.
- **Memory**: 128 MB – 10,240 MB; CPU scales proportionally with memory.
- **Timeout**: Max 15 minutes; default 3 seconds.
- **Concurrency**: 1,000 concurrent executions per account (soft limit); reserved concurrency per function.
- Lambda max timeout is 15 minutes; max memory is 10 GB; CPU scales with memory.

Related notes: [002-iam](./002-iam.md)

```python
# Python Lambda handler
def handler(event, context):
    name = event.get('name', 'World')
    return {
        'statusCode': 200,
        'body': f'Hello, {name}!'
    }
```

### Event Sources (Triggers)

| Source | Invocation | Use Case |
|--------|-----------|----------|
| API Gateway | Synchronous | REST/HTTP APIs |
| S3 | Async | File processing on upload |
| SQS | Polling | Queue processing |
| DynamoDB Streams | Polling | Change data capture |
| EventBridge (schedule) | Async | Cron jobs |
| SNS | Async | Fan-out notifications |
| CloudWatch Logs | Async | Log processing |

Related notes: [001-aws-overview](./001-aws-overview.md)

### API Gateway

- **REST API**: Full-featured; resources, methods, stages, usage plans.
- **HTTP API**: Simpler, cheaper, faster; recommended for most new APIs.
- **Lambda proxy integration**: Passes entire request to Lambda; Lambda returns status + headers + body.
- API Gateway HTTP API is simpler and cheaper than REST API — use for new projects.

```yaml
# API Gateway → Lambda flow
Client → API Gateway (api.example.com/users)
           → Lambda function
           → DynamoDB (read/write)
           → Response to client
```

Related notes: [003-vpc-networking](./003-vpc-networking.md)

### IAM and Permissions

- **Execution role**: IAM role Lambda assumes; grants access to AWS services (S3, DynamoDB, logs).
- **Resource policy**: Controls who can invoke the function (API Gateway, S3, other accounts).
- Always follow least privilege for execution role.
- Lambda execution role determines what AWS services the function can access.

Related notes: [002-iam](./002-iam.md)

### Environment and Configuration

- **Environment variables**: Config and secrets; encrypted at rest with KMS.
- **Layers**: Shared dependencies (libraries, runtimes); up to 5 layers per function.
- **VPC**: Lambda can run inside VPC to access private resources (RDS, ElastiCache); adds cold start latency.
- **Provisioned concurrency**: Pre-warm instances; eliminates cold starts (costs more).
- Environment variables are the standard way to pass config; use KMS for sensitive values.
- Layers share common dependencies across functions — useful for large libraries.
- Lambda in VPC needs NAT Gateway for internet access — adds cost and cold start latency.

Related notes: [003-vpc-networking](./003-vpc-networking.md)

### Cold Start

```text
Cold start: new container initialized
  → download code → init runtime → run init code → execute handler
  → 100ms–10s depending on runtime, package size, VPC

Warm invocation: reuse existing container
  → execute handler only
  → typically < 100ms
```

- Cold starts happen on first invocation and after scaling up.
- Minimize: use smaller packages, avoid VPC unless needed, use provisioned concurrency.
- Cold starts are worst for Java/C# and VPC-attached functions; best for Python/Node.js.
- Provisioned concurrency eliminates cold starts but costs per pre-warmed instance.

Related notes: [001-aws-overview](./001-aws-overview.md), [002-iam](./002-iam.md), [006-rds-databases](./006-rds-databases.md)

---

# Troubleshooting Guide

### Lambda function timing out
1. Check timeout setting (default 3s); increase if operation takes longer.
2. Check if function is in VPC without NAT Gateway — can't reach internet/AWS services.
3. Check external dependencies (DB, API) response times.
4. Check for infinite loops or blocking calls.

### "Task timed out after 3.00 seconds"
1. Default timeout is 3 seconds; most functions need 10-30 seconds.
2. Set appropriate timeout in function configuration.
3. API Gateway has its own timeout (29 seconds max for REST API).

### Lambda cannot access RDS in private subnet
1. Lambda must be configured to run in the same VPC.
2. Lambda security group must allow outbound to RDS port.
3. RDS security group must allow inbound from Lambda security group.
4. Lambda execution role needs `ec2:CreateNetworkInterface` for VPC access.
