# Loki and Promtail

- Loki is a log storage backend that indexes on **labels only**, not on log content; this reduces storage and indexing cost but requires good label design.
- Promtail is a lightweight agent that scrapes log files or systemd-journald, applies parsing/relabeling pipeline stages, and ships logs to Loki.
- LogQL is Loki's query language; stream selectors filter by labels, while metric queries (rate, count_over_time) aggregate logs over time.

# Architecture

```text
+------------------+     +------------------+     +------------------+
| App log files    |     | Systemd journald |     | Syslog stream    |
| /var/log/app.log |     | /run/log/journal |     | UDP/TCP socket   |
+--------+---------+     +--------+---------+     +--------+---------+
         |                        |                        |
         |                        v                        |
         |                  +----------+                   |
         |                  | Promtail |<------------------+
         |                  | Agent    |
         |                  +---+------+
         |                      |
         |   [1] tail file      |
         |   [2] read journald   |
         +---+   [3] parse       |
             v   [4] relabel     |
             |   [5] filter      |
             |                   |
             |   batch & compress|
             |                   v
             +---------> Loki Distributor
                             |
                             v
                   +---------+---------+
                   |       Loki        |
                   |                   |
                   | +--+--+--+--+--+ |
                   | |  Ingesters  | |
                   | +--+--+--+--+--+ |
                   |       |         |
                   | +-----------+  |
                   | | WAL cache |  |
                   | +-----------+  |
                   |       |         |
                   | +-----------+  |
                   | | Compactor |  |
                   | |(compress  |  |
                   | | old logs) |  |
                   | +-----------+  |
                   |       |         |
                   |  [storage: S3] |
                   +---------+-------+
                             |
                             v
                       +----------+
                       | Grafana  |
                       | (query   |
                       |  + viz)  |
                       +----------+
```

# Mental Model

```text
Promtail scrape and pipeline flow:

[1] Promtail reads config: which logs to tail, which parsing stages to apply
    |
    v
[2] Scrape config: glob patterns for log files or journald query
    --> /var/log/app/*.log
    --> systemd service=nginx
    --> syslog listening on localhost:1514
    |
    v
[3] For each log line discovered:
    [a] Add initial labels (job=app, instance=hostname)
    [b] Apply pipeline stages:
        - json: parse as JSON, add fields as labels
        - regex: extract fields with regex capture groups
        - timestamp: parse the timestamp field
        - labels: add or drop labels
        - drop: exclude lines matching condition
    [c] Final labels: job, instance, level, service, etc.
    |
    v
[4] Batch logs (e.g., 10s or 1000 lines) and send to Loki
    --> compress with snappy
    --> retry with backoff on failure
    --> queue on disk if backend unavailable
    |
    v
[5] Loki ingester receives logs
    --> index by labels (job, instance, level, service, ...)
    --> store raw log text in chunks
    --> keep 1-5 minutes of uncompressed data, then flush to storage (S3/GCS/filesystem)
    |
    v
[6] User queries Loki via Grafana LogQL
    --> {job="app"} - select all logs with label job=app
    --> {job="app"} | level="ERROR" - filter further by content
    --> rate({job="app"} | level="ERROR" [5m]) - count ERROR logs per second
```

```bash
# Example: Promtail config
cat /etc/promtail/config.yml

# scrape log files + apply parsing
scrape_configs:
  - job_name: app
    static_configs:
      - targets: [localhost]
        labels:
          job: app
          env: prod
    pipeline_stages:
      - json:
          expressions:
            timestamp: timestamp
            level: level
            message: message
            trace_id: trace_id
      - timestamp:
          source: timestamp
          format: "2006-01-02T15:04:05Z07:00"
      - labels:
          level:
          trace_id:
      - match:
          selector: '{level!="DEBUG"}'
          stages:
            - drop: {}

# tail logs in Grafana
# Query: {job="app", env="prod"} | json | level="ERROR"
# shows last 1000 ERROR logs from production app
```

# Core Building Blocks

### Loki Architecture

- **Distributor** -- entry point for log streams; validates logs and routes to ingesters.
- **Ingester** -- in-memory buffer that batches logs by stream, compresses chunks, and flushes to object storage (S3, GCS, filesystem).
- **Querier** -- retrieves logs from ingesters (hot path, low latency) and storage (historical, slower).
- **Compactor** -- post-compaction; re-orders and compresses old chunks in storage for better read performance and lower space.
- **Index** -- stores stream labels only (not full-text); enables fast label filtering but requires good label design.
- **Storage backends** -- S3, GCS, Azure Blob, or filesystem `/var/loki/chunks`.

Related notes: [001-logging-overview](./001-logging-overview.md), [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md)

### Label-Based Indexing (vs Full-Text)

- **Loki indexes labels only** (e.g., job, instance, level, service); log content is not indexed.
- **Advantage** -- 10-100x lower cardinality and storage cost compared to Elasticsearch; fast label queries.
- **Trade-off** -- full-text search (e.g., search by error message) is slow; must filter by label first, then grep content.
- **Best practice** -- add labels for high-cardinality dimensions (service, environment, instance); add low-cardinality labels (level, error_type).
- **Anti-pattern** -- do not add high-cardinality labels (user_id, request_id); use log content and trace_id instead.

```text
Good labels: {job="api", env="prod", level="ERROR", region="us-west"}
Bad labels:  {job="api", user_id="12345", request_id="abc123"} (too many unique values)

Query:       {job="api", env="prod"} | level="ERROR" | json | error="timeout"
             (filter by labels, then search content)
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### Promtail Scrape Configs

- **Scrape config** -- defines what logs to collect and which pipeline stages to apply.
- **Targets** -- log files (glob pattern), systemd services, syslog listening port.
- **Labels** -- static labels added to all logs from this config; can be overridden by pipeline stages.
- **Pipeline stages** -- ordered steps to parse, transform, and filter logs before shipping.

```text
Scrape config sections:

job_name: app                          # job name (used in label)
static_configs:                        # define log sources
  - targets: [localhost]
    labels:
      job: app
      env: prod
pipeline_stages:                       # processing steps
  - json: {}                           # parse as JSON
  - regex: {}                          # extract with regex
  - timestamp: {}                      # set timestamp
  - labels: {}                         # set labels from parsed fields
  - drop: {}                           # drop lines matching condition
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### Pipeline Stages

- **json** -- parse log line as JSON; extract fields as key-value pairs.
- **regex** -- extract fields using named capture groups (e.g., `(?P<level>\w+)`).
- **multiline** -- merge multi-line log entries into a single entry (e.g., Java stack traces).
- **timestamp** -- parse the timestamp field and set it as the entry timestamp.
- **labels** -- create labels from parsed fields; these become queryable dimensions.
- **drop** -- filter out logs matching a condition (reduce noise, save storage).
- **keep** -- keep only logs matching a condition.
- **metrics** -- create metrics (counts, histograms) from logs on the fly.

```bash
# Example: parse JSON, set labels, drop DEBUG
pipeline_stages:
  - json:
      expressions:
        level: level
        service: service
        message: msg
        duration: duration_ms
  - timestamp:
      source: timestamp
      format: "2006-01-02T15:04:05Z07:00"
  - labels:
      level:
      service:
  - match:
      selector: '{level="DEBUG"}'
      stages:
        - drop: {}
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### Relabeling and Label Manipulation

- **relabel_configs** -- Prometheus-style relabeling to rename, drop, or keep labels before shipping.
- **Common uses** -- extract hostname from filepath, drop PII labels, standardize label names.
- **Order matters** -- each relabel rule processes labels sequentially.

```bash
# Example: extract instance from file path
relabel_configs:
  - source_labels: [__path__]
    regex: '/var/log/(?P<instance>[^/]+)/app.log'
    target_label: instance
  - source_labels: [__hostname__]
    target_label: node

# Example: drop PII (user_id, api_key)
relabel_configs:
  - source_labels: [user_id]
    action: drop
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### LogQL Query Language

- **Stream selector** `{label="value"}` -- filter by labels; returns all logs matching the label set.
- **Line filter** `| "error"` or `| level="ERROR"` -- filter lines by content or JSON field.
- **JSON/logfmt parser** `| json` or `| logfmt` -- parse line content as JSON or key=value.
- **Regex filter** `| regex "pattern"` -- match lines by regex.
- **Metric queries** -- aggregate logs into metrics (count, rate, sum, histogram).

```text
LogQL examples:

# [1] Stream selector: all logs from app in production
{job="app", env="prod"}

# [2] Add line filter: only ERROR level (if level is a label)
{job="app", env="prod", level="ERROR"}

# [3] If level is in content (JSON), parse and filter
{job="app"} | json | level="ERROR"

# [4] Count ERROR logs per minute
rate({job="app"} | level="ERROR" [1m])

# [5] Count by service
sum(count_over_time({job="app"} [5m])) by (service)

# [6] Regex filter: logs containing "timeout"
{job="api"} | regex "timeout"

# [7] Histogram: latency distribution
histogram_quantile(0.95, sum(rate({job="api"} | json | latency_ms=`\d+` [5m])) by (le))
```

Related notes: [../Grafana/004-promql-deep-dive](../Grafana/004-promql-deep-dive.md)

### Label Best Practices (Low Cardinality)

- **Low-cardinality labels** (job, env, region, level, service) -- add these; cardinality < 100 unique values.
- **High-cardinality labels** (user_id, request_id, api_key) -- avoid; put in log content instead.
- **Cardinality explosion** -- if a label has millions of unique values, Loki performance degrades and storage explodes.
- **Rule of thumb** -- Loki works best with < 10-20 labels per stream, each with < 1000 unique values.

```text
Example label design:

GOOD:
  {job="api", env="prod", region="us-west", level="ERROR", error_type="timeout"}
  Labels: 5
  Cardinality: job (3) x env (3) x region (4) x level (5) x error_type (10) = ~1800 streams

BAD:
  {job="api", env="prod", user_id="alice", request_id="req-123", client_ip="192.168.1.1"}
  Labels: 5
  Cardinality: job (3) x env (3) x user_id (1M) x request_id (1G) x client_ip (1M) = EXPLOSION

CORRECT:
  Labels: {job="api", env="prod", level="ERROR"}
  Content: {"user_id":"alice", "request_id":"req-123", "client_ip":"192.168.1.1", ...}
  Query: {job="api", env="prod", level="ERROR"} | json | user_id="alice"
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### Retention and Storage

- **Retention period** -- how long logs are kept (e.g., 30 days); older logs are deleted.
- **Chunk retention** -- Loki flushes in-memory chunks to storage every 1-5 minutes; each chunk is independently compressed.
- **Storage backends** -- local filesystem (/var/loki/chunks), S3, GCS, Azure Blob.
- **Compaction** -- periodically re-compress and re-order chunks in storage to reduce size and improve query speed.
- **Index retention** -- index is kept longer than chunk data to allow lookups of old logs.

```bash
# Loki config: retention and storage

# limits_config
retention_enabled: true
retention_period: 720h           # keep 30 days

# ingester
chunk_idle_period: 3m            # flush after 3m inactive
chunk_max_age: 1h                # max 1h before forced flush
max_chunk_age: 2h                # hard limit on chunk age

# storage_config.filesystem
directory: /var/loki/chunks      # local storage

# storage_config.s3
s3: s3://my-bucket/loki/chunks   # S3 storage
```

Related notes: [001-logging-overview](./001-logging-overview.md)

---

# Practical Command Set (Core)

```bash
# -- Promtail --

# check Promtail is running
systemctl status promtail
docker ps | grep promtail

# reload Promtail config (zero downtime)
systemctl reload promtail
docker exec <promtail> kill -HUP 1

# check Promtail config syntax
promtail -config.file=/etc/promtail/config.yml -dry-run

# tail Promtail logs for errors
journalctl -u promtail -f
docker logs <promtail> -f

# -- Loki --

# check Loki API is healthy
curl -s http://loki:3100/ready
curl -s http://loki:3100/loki/api/v1/label

# check Loki ingester status
curl -s http://loki:3100/loki/api/v1/status

# query logs from Loki API directly (LogQL)
curl -s 'http://loki:3100/loki/api/v1/query_range?query={job="app"}&start=<unix-ts>&end=<unix-ts>&limit=1000' | jq '.data.result'

# list labels in Loki
curl -s http://loki:3100/loki/api/v1/label | jq '.data[]'

# list label values
curl -s 'http://loki:3100/loki/api/v1/label/job/values' | jq '.data[]'

# -- Grafana integration --

# check Loki data source connectivity in Grafana
curl -s -u admin:admin http://grafana:3000/api/datasources | jq '.[] | select(.name=="Loki") | {name, type, url}'

# test Loki data source
curl -s -u admin:admin -X POST http://grafana:3000/api/datasources/1/query \
  -H 'Content-Type: application/json' \
  -d '{"queries":[{"refId":"A","expr":"{job=\"app\"}"}]}'
```

# Troubleshooting Guide

```text
Problem: Promtail not shipping logs to Loki
    |
    v
[1] Is Promtail running?
    systemctl status promtail / docker ps | grep promtail
    |
    +-- not running --> start it
    |
    v
[2] Is Promtail config valid?
    promtail -config.file=config.yml -dry-run
    journalctl -u promtail -f
    |
    +-- config error --> fix and reload
    |
    v
[3] Are log files being tailed?
    tail -f /var/log/app.log
    journalctl -u app -f
    |
    +-- no new logs --> app not logging
    |
    v
[4] Can Promtail reach Loki?
    curl -v http://loki:3100/ready
    journalctl -u promtail | grep "error\|failed"
    |
    +-- connection refused --> check firewall, Loki address, port
    |
    v
[5] Are logs arriving at Loki?
    curl http://loki:3100/loki/api/v1/label
    Grafana Explore: query {job="app"}
    |
    +-- empty result --> check label names in Promtail config
    |
    v
[6] Check Promtail agent logs for errors
    journalctl -u promtail -f --all
    docker logs <promtail> -f
    |
    +-- debug: invalid JSON parsing, label cardinality, network errors
    |
    v
[7] Check Loki resource usage
    systemctl status loki
    curl http://loki:3100/loki/api/v1/status
    |
    +-- disk full, memory exhausted --> increase limits or reduce retention

Problem: LogQL query returns no results
    |
    v
[1] Does the label exist in Loki?
    curl http://loki:3100/loki/api/v1/label | jq '.data[]'
    |
    +-- missing label --> check Promtail pipeline stages
    |
    v
[2] Check label values
    curl 'http://loki:3100/loki/api/v1/label/job/values' | jq '.data[]'
    |
    +-- value not present --> logs not shipped yet or different value
    |
    v
[3] Try simpler query first
    {job="app"} (stream selector only)
    |
    +-- no results --> no logs from that job
    +-- results --> add filters one by one
    |
    v
[4] Check time range
    Grafana: change time picker to "Last 24 hours"
    API: verify start/end unix timestamps are correct
    |
    v
[5] Check line filters and JSON parsing
    {job="app"} | json | level="ERROR"
    |
    +-- parse error --> verify JSON format in logs, check pipeline
```

# Quick Facts (Revision)

- Loki indexes labels only (not content), reducing cost and complexity compared to Elasticsearch.
- Promtail is a log agent that scrapes files and journald, applies pipeline stages (parse, relabel, filter), ships to Loki.
- Labels should be low-cardinality (< 1000 unique values each); use log content for high-cardinality data (user_id, request_id).
- LogQL: stream selector `{job="app"}`, line filter `| level="ERROR"`, metric queries `rate(...)`.
- Pipeline stages: json, regex, timestamp, labels, drop, keep, metrics; order matters.
- Relabel rules rename, drop, or keep labels before shipping; use for hostname extraction, PII removal.
- Loki stores chunks in memory and flushes to storage (S3, GCS, filesystem) every 1-5 minutes.
- Retention period (e.g., 30 days) is configurable; old logs and chunks are deleted automatically.
