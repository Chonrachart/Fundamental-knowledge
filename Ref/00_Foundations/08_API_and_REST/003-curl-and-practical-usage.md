# curl and Practical API Usage

- curl is the standard command-line tool for transferring data via URLs; it supports HTTP, HTTPS, and dozens of other protocols.
- Practical API usage involves handling pagination, rate limits, errors, and integrating API calls into CI/CD pipelines and automation scripts.
- Webhooks reverse the API model -- instead of polling for changes, the server pushes events to your endpoint.

# Architecture

```text
+-----------+       curl / httpie / script        +-----------+
|           |  ----------------------------------> |           |
|  DevOps   |  GET/POST with headers + body       |   API     |
|  Worksta- |                                     |  Endpoint |
|  tion or  |  <---------------------------------  |           |
|  CI/CD    |  JSON response + status code        |           |
+-----------+                                     +-----------+

Webhook model (push, not pull):

+-----------+                                     +-----------+
|   Event   |   POST to registered callback URL   |  Your     |
|   Source   |  ---------------------------------> |  Webhook  |
|  (GitHub,  |   JSON payload with event data      |  Receiver |
|   Slack)   |                                     |  (server) |
+-----------+                                     +-----------+
```

# Mental Model

```text
curl request flow:

  [1] Build the command
      curl -s -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $TOKEN" \
        -d '{"key":"value"}' \
        https://api.example.com/v1/resource
          |
          v
  [2] curl sends HTTP request over TLS
          |
          v
  [3] Server processes and returns response
          |
          v
  [4] curl outputs response body to stdout
      (use -o to save to file, -w for metadata, -v for debug)
          |
          v
  [5] Script parses response (jq for JSON) and acts on result
```

```bash
# complete example: create resource, capture ID, verify
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"test-server"}' \
  https://api.example.com/v1/servers)

ID=$(echo "$RESPONSE" | jq -r '.id')
echo "Created server with ID: $ID"

# verify it was created
curl -s -H "Authorization: Bearer $TOKEN" \
  https://api.example.com/v1/servers/$ID | jq .
```

# Core Building Blocks

### curl Basics

- curl sends HTTP requests from the command line; the most essential tool for API work.

```bash
# GET request (default method)
curl -s https://api.example.com/v1/status

# POST with JSON body
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"name":"web-01"}' \
  https://api.example.com/v1/servers

# common flags
#   -s          silent (no progress bar)
#   -v          verbose (show request/response headers)
#   -X METHOD   specify HTTP method
#   -H "K: V"   add a header
#   -d 'data'   request body (implies POST if -X not set)
#   -o file     save output to file
#   -w format   output metadata after transfer
#   -L          follow redirects
#   -k          skip TLS verification (testing only, never in prod)
#   -u user:pw  basic auth

# verbose output for debugging
curl -v https://api.example.com/v1/status

# output only status code
curl -s -o /dev/null -w "%{http_code}" https://api.example.com/v1/status

# output status code and response time
curl -s -o /dev/null -w "code: %{http_code} time: %{time_total}s\n" \
  https://api.example.com/v1/status

# POST with data from a file
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d @payload.json \
  https://api.example.com/v1/servers

# download a file with progress (follow redirects)
curl -L -o artifact.tar.gz https://releases.example.com/v1.0/artifact.tar.gz

# send multipart form data (file upload)
curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@report.csv" \
  https://api.example.com/v1/uploads

# parallel requests with xargs
echo -e "server1\nserver2\nserver3" | xargs -P3 -I{} \
  curl -s "https://api.example.com/v1/servers/{}" -o "{}.json"
```

Related notes: [001-rest-concepts](./001-rest-concepts.md)

### Common Patterns

- Real-world APIs require handling pagination, rate limits, and errors.

```text
Pagination styles:

  Offset/limit:
    GET /v1/servers?offset=0&limit=25    (page 1)
    GET /v1/servers?offset=25&limit=25   (page 2)

  Page-based:
    GET /v1/servers?page=1&per_page=25
    GET /v1/servers?page=2&per_page=25

  Cursor-based (most scalable):
    GET /v1/servers?limit=25
    GET /v1/servers?limit=25&cursor=eyJpZCI6NDJ9
    (cursor value comes from previous response)
```

```bash
# paginate through all results (offset/limit)
OFFSET=0
LIMIT=25
while true; do
  RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://api.example.com/v1/servers?offset=$OFFSET&limit=$LIMIT")
  COUNT=$(echo "$RESPONSE" | jq '.items | length')
  echo "$RESPONSE" | jq '.items[]'
  [ "$COUNT" -lt "$LIMIT" ] && break
  OFFSET=$((OFFSET + LIMIT))
done

# handle rate limiting (429 with retry)
STATUS=$(curl -s -o response.json -w "%{http_code}" \
  -H "Authorization: Bearer $TOKEN" \
  https://api.example.com/v1/resources)
if [ "$STATUS" = "429" ]; then
  RETRY_AFTER=$(grep -i 'retry-after' <(curl -sI ...) | awk '{print $2}')
  echo "Rate limited. Retrying after ${RETRY_AFTER}s"
  sleep "$RETRY_AFTER"
  # retry the request
fi
```

Related notes: [001-rest-concepts](./001-rest-concepts.md)

### Real DevOps Examples

- Practical API calls for common DevOps tasks.

```bash
# --- GitHub API ---

# list repositories for a user
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/user/repos?per_page=5 | jq '.[].full_name'

# create an issue
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"Deploy failed","body":"Pipeline #42 failed in staging"}' \
  https://api.github.com/repos/owner/repo/issues

# trigger a workflow dispatch
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"ref":"main","inputs":{"environment":"staging"}}' \
  https://api.github.com/repos/owner/repo/actions/workflows/deploy.yml/dispatches

# --- Slack Webhook ---

# send a notification to a Slack channel
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"text":"Deployment to production completed successfully"}' \
  "$SLACK_WEBHOOK_URL"

# --- Health Checks ---

# check if an API is healthy
curl -sf https://api.example.com/health && echo "UP" || echo "DOWN"

# check multiple endpoints
for URL in \
  https://api.example.com/health \
  https://auth.example.com/health \
  https://monitor.example.com/health; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
  echo "$URL: $STATUS"
done
```

Related notes: [002-authentication](./002-authentication.md)

### Other Tools

- curl is not the only option; other tools can be more convenient for specific use cases.

```bash
# --- httpie (more human-readable) ---
# install: pip install httpie (or apt/brew)

# GET request
http GET https://api.example.com/v1/servers Authorization:"Bearer $TOKEN"

# POST with JSON (httpie sends JSON by default)
http POST https://api.example.com/v1/servers name=web-01 region=us-east-1

# --- wget (simpler, good for downloads) ---

# download a file
wget -q https://releases.example.com/v1.2.3/binary -O /usr/local/bin/tool

# --- python one-liners ---

# quick GET request
python3 -c "import requests; r=requests.get('https://api.example.com/health'); print(r.status_code, r.json())"

# POST with auth
python3 -c "
import requests, os
r = requests.post('https://api.example.com/v1/servers',
    headers={'Authorization': f'Bearer {os.environ[\"TOKEN\"]}'},
    json={'name': 'web-01'})
print(r.status_code, r.json())
"
```

Related notes: [000-core](./000-core.md)

### Testing APIs in CI/CD

- Smoke tests, health checks, and readiness probes ensure services are working after deployment.

```bash
# health check in CI/CD pipeline (fail if not 200)
STATUS=$(curl -s -o /dev/null -w "%{http_code}" https://api.example.com/health)
if [ "$STATUS" != "200" ]; then
  echo "Health check failed with status $STATUS"
  exit 1
fi

# readiness probe (Kubernetes style)
# /readyz returns 200 when the app is ready to serve traffic
curl -sf http://localhost:8080/readyz || exit 1

# liveness probe
# /healthz returns 200 when the app is alive
curl -sf http://localhost:8080/healthz || exit 1

# smoke test: create and delete a test resource
ID=$(curl -s -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"smoke-test-resource"}' \
  https://api.example.com/v1/resources | jq -r '.id')

curl -s -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  "https://api.example.com/v1/resources/$ID"

echo "Smoke test passed"
```

Related notes: [001-rest-concepts](./001-rest-concepts.md)

### Webhooks
```text
Pull model (polling):
  Client --> GET /events?since=... --> Server   (repeated every N seconds)
  Problem: wasted requests when nothing changed, delayed when something did

Push model (webhook):
  Server --> POST to your callback URL --> Your handler   (instant, on demand)
  Problem: you must run a reachable HTTP server; need to verify payloads

Common webhook uses:
  - GitHub: push events trigger CI/CD pipeline
  - Alertmanager: alert fires, POSTs to Slack/PagerDuty
  - Docker Hub: image push triggers deployment
  - Stripe/payment: transaction events trigger fulfillment
```

```bash
# test a webhook receiver locally (using nc as a simple listener)
# terminal 1: listen on port 9000
nc -l -p 9000

# terminal 2: simulate a webhook payload
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"event":"push","repo":"myapp","branch":"main"}' \
  http://localhost:9000/webhook

# verify webhook signature (GitHub example, pseudo-code)
# GitHub sends X-Hub-Signature-256 header with HMAC-SHA256
# Your handler must verify: HMAC(secret, body) == signature
```

Related notes: [000-core](./000-core.md)
- Webhooks invert the typical API model: instead of your code polling an API, the service pushes events to your URL.
- Common in CI/CD triggers, alerting, ChatOps, and event-driven automation.
