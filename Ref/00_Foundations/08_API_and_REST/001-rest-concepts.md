# REST Concepts

- REST (Representational State Transfer) is an architectural style for building web APIs around resources, using standard HTTP methods and status codes.
- Communication is stateless: each request is self-contained, carrying all authentication, parameters, and context the server needs to process it.
- Resources are identified by URLs, represented in formats like JSON, and manipulated through a uniform interface (GET, POST, PUT, PATCH, DELETE).

# Architecture

```text
+-----------+                              +-----------+
|           |   GET /api/v1/servers/42     |           |
|  Client   |  --------------------------> |  API      |
|           |   Authorization: Bearer ...  |  Server   |
|           |                              |           |
|           |  <------------------------   |           |
|           |   200 OK                     |           |
|           |   Content-Type: app/json     |           |
|           |   {"id":42,"name":"web-1"}   |           |
+-----------+                              +-----------+

URL structure:
  https://api.example.com/v1/servers?status=active&limit=10
  \____/ \______________/ \_/ \____/ \____________________/
  scheme     host        ver  path     query parameters
```

# Mental Model

```text
REST request anatomy:

  +--------------------------------------------------+
  | METHOD  URL                          HTTP/1.1     |
  | Host: api.example.com                             |
  | Authorization: Bearer eyJhbGci...                 |
  | Content-Type: application/json                    |
  | Accept: application/json                          |
  |                                                   |
  | {"name": "web-server-01", "region": "us-east-1"}  |
  +--------------------------------------------------+
       |
       v
  +--------------------------------------------------+
  | HTTP/1.1 201 Created                              |
  | Content-Type: application/json                    |
  | Location: /v1/servers/42                          |
  |                                                   |
  | {"id": 42, "name": "web-server-01", ...}          |
  +--------------------------------------------------+
```

```bash
# examine full request/response exchange
curl -v -X GET \
  -H "Accept: application/json" \
  https://api.example.com/v1/servers/42
```

# Core Building Blocks

### HTTP Methods

- **GET** -- read/retrieve a resource; no body; idempotent and safe (no side effects).
- **POST** -- create a new resource; includes body; NOT idempotent (repeating may create duplicates).
- **PUT** -- replace a resource entirely; includes body; idempotent (same result on repeat).
- **PATCH** -- partially update a resource; includes body; not guaranteed idempotent.
- **DELETE** -- remove a resource; idempotent (deleting twice gives same result).

```text
Method    CRUD      Body?   Idempotent?   Safe?
------    -----     -----   -----------   -----
GET       Read      No      Yes           Yes
POST      Create    Yes     No            No
PUT       Replace   Yes     Yes           No
PATCH     Update    Yes     No*           No
DELETE    Delete    No**    Yes           No

*  PATCH can be idempotent depending on implementation
** DELETE may include a body in some APIs but typically does not
```

```bash
# curl examples for each method
curl -s https://api.example.com/v1/servers/42                          # GET
curl -s -X POST -H "Content-Type: application/json" \
  -d '{"name":"web-01"}' https://api.example.com/v1/servers            # POST
curl -s -X PUT -H "Content-Type: application/json" \
  -d '{"name":"web-01","region":"eu-west-1"}' \
  https://api.example.com/v1/servers/42                                # PUT
curl -s -X PATCH -H "Content-Type: application/json" \
  -d '{"region":"eu-west-1"}' https://api.example.com/v1/servers/42    # PATCH
curl -s -X DELETE https://api.example.com/v1/servers/42                # DELETE
# check only the status code
curl -s -o /dev/null -w "%{http_code}" https://api.example.com/v1/servers/42
```

Related notes: [000-core](./000-core.md)

### Status Codes

- Status codes indicate the result of an API request; grouped by first digit.

```text
2xx -- Success
  200 OK              -- request succeeded, response has body
  201 Created         -- resource created (POST), often includes Location header
  204 No Content      -- success but no response body (common for DELETE)

3xx -- Redirection
  301 Moved Permanently  -- resource URL changed permanently
  302 Found              -- temporary redirect
  304 Not Modified       -- cached version is still valid

4xx -- Client Error (your fault)
  400 Bad Request        -- malformed syntax, invalid parameters
  401 Unauthorized       -- missing or invalid authentication
  403 Forbidden          -- authenticated but not authorized
  404 Not Found          -- resource does not exist
  409 Conflict           -- request conflicts with current state
  422 Unprocessable      -- valid syntax but semantically invalid
  429 Too Many Requests  -- rate limited; check Retry-After header

5xx -- Server Error (their fault)
  500 Internal Server Error  -- generic server failure
  502 Bad Gateway            -- upstream server returned invalid response
  503 Service Unavailable    -- server overloaded or in maintenance
  504 Gateway Timeout        -- upstream server did not respond in time
```

Related notes: [000-core](./000-core.md)

### Headers

- Headers carry metadata about the request or response.

```text
Request headers:
  Content-Type: application/json     -- format of the request body
  Accept: application/json           -- format the client wants back
  Authorization: Bearer <token>      -- authentication credentials
  User-Agent: my-script/1.0          -- identifies the client
  X-Request-ID: abc-123              -- trace ID for debugging

Response headers:
  Content-Type: application/json     -- format of the response body
  Location: /v1/servers/42           -- URL of newly created resource
  Retry-After: 60                    -- seconds to wait (with 429)
  X-RateLimit-Remaining: 58          -- remaining requests in window
  Cache-Control: max-age=300         -- caching instructions
```

Related notes: [002-authentication](./002-authentication.md)

### URL Structure

- URLs identify resources; path segments represent hierarchy, query parameters filter or modify.

```text
https://api.example.com/v1/projects/7/servers?status=active&limit=10
\____/ \______________/ \_/ \_______________/ \____________________/
scheme     base host   ver   resource path     query parameters

Conventions:
  /v1/servers          -- collection (plural nouns, not verbs)
  /v1/servers/42       -- single resource by ID
  /v1/servers/42/logs  -- sub-resource
  ?page=2&per_page=25  -- pagination parameters
  ?sort=name&order=asc -- sorting parameters
```

Related notes: [003-curl-and-practical-usage](./003-curl-and-practical-usage.md)

### Idempotency

- An operation is idempotent if performing it multiple times produces the same result as performing it once.
- Critical for automation: if a script fails mid-way and retries, idempotent calls are safe to repeat.

```text
Idempotent (safe to retry):
  GET  /servers/42       -- reading never changes state
  PUT  /servers/42       -- replacing with same data = same result
  DELETE /servers/42     -- deleting twice = resource still gone

NOT idempotent (dangerous to retry blindly):
  POST /servers          -- each call may create a new server

Workarounds for non-idempotent POST:
  - Use idempotency keys (X-Idempotency-Key header)
  - Check if resource exists before creating
  - Use PUT with a client-generated ID instead
```

Related notes: [000-core](./000-core.md)

### Content Negotiation
```text
Client sends:     Accept: application/json
Server responds:  Content-Type: application/json

Client sends:     Content-Type: application/json  (in POST/PUT body)
Server validates: body must be valid JSON
```

Related notes: [003-curl-and-practical-usage](./003-curl-and-practical-usage.md)
- APIs can support multiple formats; Content-Type and Accept headers negotiate the format.
- JSON (application/json) is the standard for nearly all modern REST APIs.
- Some APIs also support XML, YAML, or plain text.
