# Loki

- Loki is a log storage backend that indexes on **labels only**, not on log content; this reduces storage and indexing cost but requires good label design.
- Promtail is the legacy Loki agent for log collection, replaced by Grafana Alloy in this stack. See [../Alloy/001-alloy-overview](../Alloy/001-alloy-overview.md).
- LogQL is Loki's query language; stream selectors filter by labels, while metric queries (rate, count_over_time) aggregate logs over time.

# Architecture

```text
+------------------+     +------------------+     +------------------+
| App log files    |     | Systemd journald |     | Syslog stream    |
| /var/log/app.log |     | /run/log/journal |     | UDP/TCP socket   |
+--------+---------+     +--------+---------+     +--------+---------+
         |                        |                        |
         |                        v                        |
         |                +-------------+                  |
         |                | Log Agent   |<-----------------+
         |                | (Alloy)     |
         |                +------+------+
         |                       |
         |   [1] tail file       |
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
Loki log ingestion and query flow:

[1] Log agent (Alloy) collects logs from files, journald, or syslog
    --> applies pipeline stages: parse, relabel, filter
    --> batches and compresses logs
    |
    v
[2] Loki Distributor receives log streams
    --> validates labels and timestamps
    --> routes to appropriate Ingester by hash ring
    |
    v
[3] Ingester buffers logs in memory
    --> index by labels (job, instance, level, service, ...)
    --> store raw log text in chunks
    --> keep 1-5 minutes of uncompressed data, then flush to storage (S3/GCS/filesystem)
    |
    v
[4] User queries Loki via Grafana LogQL
    --> {job="app"} - select all logs with label job=app
    --> {job="app"} | level="ERROR" - filter further by content
    --> rate({job="app"} | level="ERROR" [5m]) - count ERROR logs per second
```

# Core Building Blocks

### Loki Architecture

- **Distributor** -- entry point for log streams; validates logs and routes to ingesters.
- **Ingester** -- in-memory buffer that batches logs by stream, compresses chunks, and flushes to object storage (S3, GCS, filesystem).
- **Querier** -- retrieves logs from ingesters (hot path, low latency) and storage (historical, slower).
- **Compactor** -- post-compaction; re-orders and compresses old chunks in storage for better read performance and lower space.
- **Index** -- stores stream labels only (not full-text); enables fast label filtering but requires good label design.
- **Storage backends** -- S3, GCS, Azure Blob, or filesystem `/var/loki/chunks`.
- Loki stores chunks in memory and flushes to storage (S3, GCS, filesystem) every 1-5 minutes.

Related notes: [001-logging-overview](./001-logging-overview.md), [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md)

### Label-Based Indexing (vs Full-Text)

- **Loki indexes labels only** (e.g., job, instance, level, service); log content is not indexed.
- **Advantage** -- 10-100x lower cardinality and storage cost compared to Elasticsearch; fast label queries.
- **Trade-off** -- full-text search (e.g., search by error message) is slow; must filter by label first, then grep content.
- **Best practice** -- add labels for high-cardinality dimensions (service, environment, instance); add low-cardinality labels (level, error_type).
- **Anti-pattern** -- do not add high-cardinality labels (user_id, request_id); use log content and trace_id instead.
- Loki indexes labels only (not content), reducing cost and complexity compared to Elasticsearch.

```text
Good labels: {job="api", env="prod", level="ERROR", region="us-west"}
Bad labels:  {job="api", user_id="12345", request_id="abc123"} (too many unique values)

Query:       {job="api", env="prod"} | level="ERROR" | json | error="timeout"
             (filter by labels, then search content)
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### Log Collection Agent

- Promtail is the legacy Loki agent for log collection, replaced by Grafana Alloy in this stack. See [../Alloy/001-alloy-overview](../Alloy/001-alloy-overview.md).

Related notes: [001-logging-overview](./001-logging-overview.md), [../Alloy/001-alloy-overview](../Alloy/001-alloy-overview.md)

### LogQL Query Language

- **Stream selector** `{label="value"}` -- filter by labels; returns all logs matching the label set.
- **Line filter** `| "error"` or `| level="ERROR"` -- filter lines by content or JSON field.
- **JSON/logfmt parser** `| json` or `| logfmt` -- parse line content as JSON or key=value.
- **Regex filter** `| regex "pattern"` -- match lines by regex.
- **Metric queries** -- aggregate logs into metrics (count, rate, sum, histogram).
- LogQL: stream selector `{job="app"}`, line filter `| level="ERROR"`, metric queries `rate(...)`.

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

Related notes: [../Prometheus/001-prometheus-overview](../Prometheus/001-prometheus-overview.md), [003-logql-deep-dive](./003-logql-deep-dive.md)

### Label Best Practices (Low Cardinality)

- **Low-cardinality labels** (job, env, region, level, service) -- add these; cardinality < 100 unique values.
- **High-cardinality labels** (user_id, request_id, api_key) -- avoid; put in log content instead.
- **Cardinality explosion** -- if a label has millions of unique values, Loki performance degrades and storage explodes.
- **Rule of thumb** -- Loki works best with < 10-20 labels per stream, each with < 1000 unique values.
- Labels should be low-cardinality (< 1000 unique values each); use log content for high-cardinality data (user_id, request_id).

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
- **Storage backends** -- local filesystem (`/var/loki/chunks`), S3, GCS, Azure Blob.
- **Compaction** -- periodically re-compress and re-order chunks in storage to reduce size and improve query speed.
- **Index retention** -- index is kept longer than chunk data to allow lookups of old logs.
- Retention period (e.g., 30 days) is configurable; old logs and chunks are deleted automatically.

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

### Loki vs ELK Comparison

| Aspect              | Loki                        | ELK (Elasticsearch)              |
| :------------------ | :-------------------------- | :------------------------------- |
| **Indexing**        | Labels only (low cost)      | Full-text (all fields)           |
| **Storage cost**    | Low (simple, label-indexed) | High (inverted index, replicas) |
| **Full-text search**| Slow (must grep content)    | Fast and powerful               |
| **Complexity**      | Simple (Loki + Alloy)       | Complex (Logstash, config)      |
| **Memory per node** | Low (1-2GB baseline)        | High (8-16GB+ typical)           |
| **Use case**        | Modern apps, structured     | Legacy apps, unstructured text  |

- Choose Loki for Kubernetes/structured logs and simplicity
- Choose ELK for complex analysis and unstructured logs

Related notes: [001-logging-overview](./001-logging-overview.md)
