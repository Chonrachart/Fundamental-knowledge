# API and REST

- An API (Application Programming Interface) defines how software components communicate -- endpoints, methods, and data formats that allow programs to interact without knowing each other's internals.
- REST (Representational State Transfer) is the dominant API style for web services, using HTTP methods and URLs to perform CRUD operations on resources.
- DevOps engineers interact with APIs daily: provisioning cloud infrastructure, triggering CI/CD pipelines, querying monitoring systems, and automating workflows.

# Architecture

```text
+-------------+         HTTPS request          +----------------+
|             |  -----------------------------> |                |
|   Client    |   method + URL + headers + body |   API Server   |
|  (curl,     |                                 |  (nginx/app)   |
|   script,   |  <-----------------------------  |                |
|   CI/CD)    |   status code + headers + body  |                |
+-------------+         HTTPS response          +-------+--------+
                                                        |
                                                        v
                                                +----------------+
                                                | Business Logic |
                                                |  (validation,  |
                                                |   processing)  |
                                                +-------+--------+
                                                        |
                                                        v
                                                +----------------+
                                                |   Data Store   |
                                                |  (database,    |
                                                |   object store)|
                                                +----------------+
```

# Mental Model

```text
API call lifecycle (e.g., create a GitHub issue):

  [1] Client builds request
      POST https://api.github.com/repos/owner/repo/issues
      Headers: Authorization: Bearer <token>, Content-Type: application/json
      Body: {"title": "Bug report", "body": "Details here"}
          |
          v
  [2] HTTP request travels over TLS to API server
          |
          v
  [3] Server authenticates (valid token?), authorizes (has permission?)
          |
          v
  [4] Server processes request (validates input, creates resource)
          |
          v
  [5] Server returns response
      HTTP/1.1 201 Created
      Body: {"id": 42, "title": "Bug report", "state": "open", ...}
```

```bash
# create a GitHub issue via API
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Bug report","body":"Details here"}' \
  https://api.github.com/repos/owner/repo/issues
```

# Core Building Blocks

### REST Concepts

- REST defines how to structure APIs around resources, using HTTP methods (GET, POST, PUT, DELETE) for operations.
- Stateless communication: each request contains all information needed; the server stores no client session.
- Status codes, headers, and URL structure form the vocabulary of every REST API.

Related notes: [001-rest-concepts](./001-rest-concepts.md)

### API Authentication

- APIs require authentication to identify callers and enforce access control.
- Methods range from simple API keys to OAuth 2.0 flows, depending on security requirements.
- Cloud providers each have their own auth mechanisms (AWS STS, Azure service principals, GCP service accounts).

Related notes: [002-authentication](./002-authentication.md)

### curl and Practical API Usage
Related notes: [003-curl-and-practical-usage](./003-curl-and-practical-usage.md)
- curl is the universal command-line tool for making HTTP requests and testing APIs.
- Real-world API usage involves pagination, rate limiting, error handling, and webhook integration.
- Every DevOps workflow -- CI/CD, monitoring, alerting -- relies on practical API interaction patterns.

# Topic Map

- [001-rest-concepts](./001-rest-concepts.md) -- REST principles, HTTP methods, status codes, headers
- [002-authentication](./002-authentication.md) -- API keys, bearer tokens, OAuth 2.0, cloud provider auth
- [003-curl-and-practical-usage](./003-curl-and-practical-usage.md) -- curl, practical patterns, webhooks, DevOps examples
