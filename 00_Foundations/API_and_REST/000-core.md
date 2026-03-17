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

- curl is the universal command-line tool for making HTTP requests and testing APIs.
- Real-world API usage involves pagination, rate limiting, error handling, and webhook integration.
- Every DevOps workflow -- CI/CD, monitoring, alerting -- relies on practical API interaction patterns.

Related notes: [003-curl-and-practical-usage](./003-curl-and-practical-usage.md)

---

# Practical Command Set (Core)

```bash
# simple GET request
curl -s https://api.example.com/health

# GET with headers and verbose output
curl -v -H "Authorization: Bearer $TOKEN" https://api.example.com/resource

# POST with JSON body
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"key":"value"}' \
  https://api.example.com/resource

# check HTTP status code only
curl -s -o /dev/null -w "%{http_code}" https://api.example.com/health

# follow redirects
curl -sL https://api.example.com/resource

# save response to file
curl -s -o response.json https://api.example.com/resource
```

# Troubleshooting Guide

```text
Problem: API call failing or returning errors
    |
    v
[1] Can you reach the API endpoint?
    curl -v https://api.example.com/health
    |
    +-- connection refused --> wrong host/port, service down
    +-- timeout --> firewall, DNS, network issue
    |
    v
[2] Is the response a valid HTTP status?
    Check status code
    |
    +-- 401/403 --> authentication/authorization problem
    +-- 404 --> wrong URL path or resource does not exist
    +-- 429 --> rate limited, check Retry-After header
    +-- 5xx --> server-side error, check server logs
    |
    v
[3] Is the request well-formed?
    Check Content-Type header, JSON syntax, required fields
    |
    +-- 400/422 --> malformed request body or missing parameters
    |
    v
[4] Is authentication configured correctly?
    Verify token/key is valid, not expired, has correct scopes
    |
    v
[5] Check response body for error details
    Most APIs return error messages in JSON response body
```

# Quick Facts (Revision)

- API = Application Programming Interface; a contract between software components defining how they communicate.
- REST = Representational State Transfer; the most common API style, built on HTTP.
- RESTful APIs use HTTP methods (GET, POST, PUT, PATCH, DELETE) to operate on resources identified by URLs.
- Every API call has: method, URL, headers, optional body (request) and status code, headers, body (response).
- Authentication methods: API keys, bearer tokens (JWT), OAuth 2.0, basic auth, cloud provider credentials.
- Idempotent methods (GET, PUT, DELETE) are safe to retry; POST is not idempotent.
- Status code families: 2xx success, 3xx redirect, 4xx client error, 5xx server error.
- curl is the essential CLI tool for API interaction, debugging, and automation scripting.

# Topic Map

- [001-rest-concepts](./001-rest-concepts.md) -- REST principles, HTTP methods, status codes, headers
- [002-authentication](./002-authentication.md) -- API keys, bearer tokens, OAuth 2.0, cloud provider auth
- [003-curl-and-practical-usage](./003-curl-and-practical-usage.md) -- curl, practical patterns, webhooks, DevOps examples
