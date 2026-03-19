RDS
Lambda
API Gateway
serverless
managed service

---

# RDS

- Managed relational database; engine: MySQL, PostgreSQL, MariaDB, Oracle, SQL Server.
- **Instance**: DB instance class (CPU, memory); storage (gp3, io1); multi-AZ for HA (replica).
- Backups: automated (retention period); snapshots manual; restore to new instance.
- **Security**: VPC; security group; encryption at rest; SSL for connection; IAM auth (some engines).

# Lambda

- Serverless function; run code without managing servers; pay per invocation and duration.
- **Trigger**: Event (S3, DynamoDB, SNS, SQS, API Gateway, schedule, etc.).
- **Runtime**: Node, Python, Go, Java, etc.; package code + dependencies (layer for shared deps).
- **Limit**: Timeout (max 15 min); memory (affects CPU); concurrency (reserved vs provisioned).
- Use IAM role for permissions; env vars for config; avoid storing secrets in code.

# API Gateway

- Create, publish, maintain REST or WebSocket APIs; front Lambda, HTTP backend, or AWS service.
- **REST API**: Resources and methods; integration (Lambda, HTTP, mock); deployment and stage.
- **Lambda proxy**: Request (path, query, headers, body) passed to Lambda; Lambda returns status, headers, body.
- Throttling, usage plans, API keys; CORS config; custom domain.

# Serverless

- No servers to manage; scale automatically; pay per use.
- Lambda + API Gateway + DynamoDB (or other) common pattern for APIs and event-driven workloads.
