# ELK Stack Basics

- The ELK stack (Elasticsearch, Logstash, Kibana) provides full-text search and analytics for logs at scale.
- Elasticsearch is a distributed search engine that indexes all fields in logs, enabling complex queries; Logstash parses and transforms logs before indexing.
- Kibana provides a UI for ad-hoc search (Discover), dashboards, and alerting; Filebeat is a lightweight alternative to Logstash for simple log shipping.

# Architecture

```text
+------------------+   +------------------+   +------------------+
| Application logs |   | Systemd journald |   | Syslog stream    |
| /var/log/app.log |   | /run/log/journal |   | UDP/TCP socket   |
+--------+---------+   +--------+---------+   +--------+---------+
         |                      |                      |
         |          Lightweight shipper                |
         |                      |                      |
         |    +--------+---------+---------+            |
         |    |                           |            |
         |    v                           v            |
         | +-------+                  +--------+       |
         | |Filebeat|                 |Logstash|<------+
         | +-------+                  +--------+
         |    |                           |
         |    | (lightweight)     (parsing, filtering,
         |    |                   enrichment, routing)
         |    |                           |
         |    +--------+---------+--------+
         |             |
         |             v
         |      +------------------+
         |      | Elasticsearch    |
         |      |                  |
         |      | [Indices]        |
         |      | app-2026.03.17   |
         |      | app-2026.03.16   |
         |      | ...              |
         |      |                  |
         |      | [Shards & Replicas]
         |      | Shard 0, Shard 1 |
         |      | Replica 0, ...   |
         |      |                  |
         |      | [Inverted Index] |
         |      | (full-text)      |
         |      +------------------+
         |             |
         |             v
         +-------> +------------------+
                  | Kibana           |
                  | Discover, Dash,  |
                  | Alerting         |
                  +------------------+
```

# Mental Model

```text
ELK workflow:

[1] Application writes log to file or stdout
    --> Filebeat or Logstash reads it
    |
    v
[2] Logstash processes (if used):
    [a] Input: which log sources (file, syslog, http, tcp, beats)
    [b] Filter: parse (grok, json), transform, enrich
    [c] Output: send to Elasticsearch
    |
    v
[3] Elasticsearch ingests log document
    --> extract all fields into inverted index
    --> add metadata: @timestamp, _id, _source
    --> route to appropriate index (app-2026.03.17, app-2026.03.16)
    |
    v
[4] Index management (ILM - Index Lifecycle Management)
    --> hot: fresh index, receiving writes
    --> warm: no new writes, still searchable
    --> cold: compress, move to slow storage
    --> delete: remove after X days
    |
    v
[5] User queries via Kibana
    [a] Discover tab: ad-hoc search, filter, aggregate
    [b] Dashboard: save queries as panels, visualizations
    [c] KQL query language: field:value, ranges, OR/AND operators
    --> results returned in milliseconds to seconds
    |
    v
[6] Alerting
    --> run aggregation queries on schedule (e.g., every minute)
    --> if threshold breached, send notification (email, Slack)
```

```bash
# Example: Logstash pipeline
input {
  file {
    path => "/var/log/app/*.log"
    start_position => "beginning"
  }
}

filter {
  json {
    source => "message"
  }
  date {
    match => ["timestamp", "ISO8601"]
    target => "@timestamp"
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "app-%{+YYYY.MM.dd}"
  }
}

# Query example: Kibana KQL
service:api AND level:ERROR AND @timestamp:[now-1h TO now]
# returns all ERROR logs from api service in the last hour
```

# Core Building Blocks

### Elasticsearch Index Model

- **Index** -- logical collection of documents (logs); similar to a database table.
- **Shard** -- physical partition of an index; enables parallel processing and scaling.
- **Replica** -- copy of a shard on another node; provides redundancy and improves read throughput.
- **Mapping** -- schema that defines field names, types (text, keyword, number, date), and analyzers.
- **Document** -- a single log entry; stored as JSON with all fields flattened.

```text
Index structure:

  app-2026.03.17 (index)
    ├── Shard 0
    │   ├── Replica 0 (on node1)
    │   └── Replica 1 (on node2)
    ├── Shard 1
    │   ├── Replica 0 (on node2)
    │   └── Replica 1 (on node3)
    └── Shard 2
        ├── Replica 0 (on node3)
        └── Replica 1 (on node1)

Default: 1 primary shard, 1 replica (2 total copies)
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### Logstash Input/Filter/Output Pipeline

- **Input** -- data source (file, syslog, HTTP, Beats, Kafka).
  - File: tail log files (like Promtail/Filebeat).
  - Beats: receive logs from lightweight shippers (Filebeat, Metricbeat).
  - Syslog: listen on UDP/TCP for syslog messages.
- **Filter** -- processing stages: parse (grok, json, csv), enrich (geoip, translate), transform (mutate, drop).
  - **grok** -- regex-based pattern matching for unstructured logs.
  - **json** -- parse JSON log lines; extract all fields.
  - **date** -- parse and set the @timestamp field.
  - **mutate** -- rename, add, remove, or transform fields.
  - **drop** -- discard logs matching a condition.
- **Output** -- send processed logs to destination (Elasticsearch, S3, HTTP).

```bash
# Logstash grok filter example
filter {
  grok {
    match => {
      "message" => "%{TIMESTAMP_ISO8601:timestamp} %{LOGLEVEL:level} \[%{DATA:service}\] %{GREEDYDATA:message}"
    }
  }
  date {
    match => ["timestamp", "ISO8601"]
    target => "@timestamp"
  }
  mutate {
    remove_field => ["@version", "host"]
  }
}
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### Filebeat (Lightweight Shipper)

- **Lightweight** -- low memory/CPU footprint compared to Logstash; suitable for agents on every host.
- **Prospector** -- discovers and tails files matching glob patterns.
- **Backpressure handling** -- stops tailing if output cannot keep up; prevents data loss.
- **Modules** -- pre-built parsing rules for common applications (nginx, apache, mysql, docker).
- **Output** -- sends logs to Elasticsearch directly or to Logstash for additional processing.

```bash
# Filebeat config
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/app/*.log
    fields:
      service: api
      env: prod
    json.keys_under_root: true
    json.add_error_key: true

filebeat.modules:
  - module: nginx
    access:
      enabled: true
      var.paths: ["/var/log/nginx/access.log"]
    error:
      enabled: true
      var.paths: ["/var/log/nginx/error.log"]

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  index: "app-%{+yyyy.MM.dd}"
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### Kibana Discover and Dashboards

- **Discover** -- ad-hoc query interface; filter logs, visualize distributions, export data.
  - **KQL (Kibana Query Language)** -- field:value syntax; supports ranges, logical operators, wildcards.
  - **Field analysis** -- view top values for a field, drill down into logs.
  - **Time picker** -- set query time range (last hour, last 7 days, custom).
- **Dashboard** -- save queries as panels; combine multiple visualizations.
  - **Visualization types** -- line charts, bar charts, tables, maps, metrics.
  - **Interactions** -- click a bar to drill down into logs, export CSV.
- **Alerting** -- run aggregation queries on schedule; notify on threshold breach.

```bash
# KQL query examples

# Simple filter
service:api

# Compound filter
service:api AND level:ERROR

# Range
@timestamp:[now-1h TO now]

# Wildcard
error:"connection*"

# NOT operator
NOT level:DEBUG

# Combined
service:api AND level:ERROR AND @timestamp:[now-1h TO now] AND error:"timeout*"
```

Related notes: [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md)

### Index Lifecycle Management (ILM)

- **Hot phase** -- actively receiving writes; index has primary shard.
- **Warm phase** -- no new writes; read-only; optionally force merge to save space.
- **Cold phase** -- older data; compress and move to cheaper storage (warm tier).
- **Delete phase** -- remove index after retention period (30 days, 1 year, etc.).

```bash
# ILM policy example
PUT _ilm/policy/app-policy
{
  "policy": "app-policy",
  "phases": {
    "hot": {
      "min_age": "0d",
      "actions": {
        "set_priority": { "priority": 100 }
      }
    },
    "warm": {
      "min_age": "3d",
      "actions": {
        "set_priority": { "priority": 50 },
        "forcemerge": { "max_num_segments": 1 }
      }
    },
    "cold": {
      "min_age": "10d",
      "actions": {
        "set_priority": { "priority": 0 },
        "searchable_snapshot": {}
      }
    },
    "delete": {
      "min_age": "30d",
      "actions": {
        "delete": {}
      }
    }
  }
}
```

Related notes: [001-logging-overview](./001-logging-overview.md)

### Loki vs ELK: Comparison and When to Choose

| Aspect                | Loki                        | ELK (Elasticsearch)              |
| :-------------------- | :-------------------------- | :------------------------------- |
| **Indexing**          | Labels only (low cost)      | Full-text (all fields)           |
| **Search speed**      | Fast (label filtering)      | Slower (full-text, aggregation) |
| **Storage cost**      | Low (simple, label-indexed) | High (inverted index, replicas) |
| **Full-text search**  | Slow (must grep content)    | Fast and powerful               |
| **Complexity**        | Simple (Loki, Promtail)     | Complex (Logstash, config)      |
| **Memory per node**   | Low (1-2GB baseline)        | High (8-16GB+ typical)           |
| **Operations**        | Easy (stateless agents)     | Complex (cluster tuning, ILM)   |
| **Use case**          | Modern apps, structured     | Legacy apps, unstructured text  |
| **Cardinality limit** | Strict (< 10k streams)      | Flexible (millions of fields)   |
| **Aggregations**      | Simple (count, rate)        | Complex (percentiles, nested)   |

**When to choose Loki:**
- Modern Kubernetes/containerized environment
- Structured JSON logs
- Low budget, want simplicity
- High-volume log streams (millions of logs/min)

**When to choose ELK:**
- Complex log analysis and deep searching needed
- Many unstructured logs or legacy formats
- Need advanced analytics (histograms, percentiles, geolocation)
- Mature team familiar with Elasticsearch

Related notes: [001-logging-overview](./001-logging-overview.md), [002-loki-and-promtail](./002-loki-and-promtail.md)

### Elasticsearch Cluster Operations

- **Cluster health** -- green (all shards allocated), yellow (replicas not allocated), red (primary shards missing).
- **Node roles** -- master (cluster coordination), data (stores shards), ingest (process data), ml (machine learning).
- **Sharding strategy** -- balance between query parallelism and overhead; typically 1-3 shards per index.
- **Replica count** -- 0 (fast writes, data loss risk), 1 (standard, balanced), 2+ (high availability, slower writes).

```bash
# Elasticsearch cluster commands

# check cluster health
curl -s http://elasticsearch:9200/_cluster/health | jq

# list nodes in cluster
curl -s http://elasticsearch:9200/_cat/nodes | head -20

# show all indices and their size
curl -s http://elasticsearch:9200/_cat/indices?v | head -20

# check shard allocation
curl -s http://elasticsearch:9200/_cat/shards | head -20

# set replica count on an index
curl -X PUT http://elasticsearch:9200/app-2026.03.17/_settings \
  -H 'Content-Type: application/json' \
  -d '{"number_of_replicas":2}'
```

Related notes: [001-logging-overview](./001-logging-overview.md)

---

# Practical Command Set (Core)

```bash
# -- Elasticsearch --

# check Elasticsearch cluster health
curl -s http://elasticsearch:9200/_cluster/health | jq '.status'

# list all indices
curl -s http://elasticsearch:9200/_cat/indices?v

# get index mapping (schema)
curl -s http://elasticsearch:9200/app-2026.03.17/_mapping | jq '.app-2026.03.17.mappings'

# count documents in an index
curl -s http://elasticsearch:9200/app-2026.03.17/_count | jq '.count'

# simple search query
curl -s http://elasticsearch:9200/app-2026.03.17/_search \
  -H 'Content-Type: application/json' \
  -d '{"query":{"match":{"level":"ERROR"}}, "size":10}' | jq '.hits.hits[]'

# search with KQL-like filter (bool query)
curl -s 'http://elasticsearch:9200/app-*/_search' \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "bool": {
        "must": [
          {"match": {"level": "ERROR"}},
          {"match": {"service": "api"}}
        ],
        "filter": [
          {"range": {"@timestamp": {"gte": "now-1h"}}}
        ]
      }
    },
    "size": 100
  }' | jq '.hits.hits[] | ._source'

# -- Logstash --

# check Logstash is running
systemctl status logstash
docker ps | grep logstash

# test Logstash config
logstash -f /etc/logstash/conf.d/app.conf --dry-run

# reload Logstash config
systemctl reload logstash

# tail Logstash logs
journalctl -u logstash -f
docker logs <logstash> -f

# -- Filebeat --

# check Filebeat status
systemctl status filebeat
filebeat test config

# test Filebeat output connectivity
filebeat test output

# reload Filebeat config
systemctl reload filebeat

# list files being tailed
filebeat modules list

# -- Kibana --

# check Kibana health
curl -s http://kibana:5601/api/status | jq '.state'

# list saved searches
curl -s http://kibana:5601/api/saved_objects/search | jq '.saved_objects[].attributes.title'
```

# Troubleshooting Flow (Quick)

```text
Problem: logs not appearing in Elasticsearch
    |
    v
[1] Is Filebeat/Logstash running?
    systemctl status filebeat / logstash
    docker ps | grep -E "filebeat|logstash"
    |
    +-- not running --> start it
    |
    v
[2] Is the log source generating logs?
    tail -f /var/log/app.log
    |
    +-- no new logs --> app not logging
    |
    v
[3] Is Filebeat/Logstash tailing the file?
    filebeat test config
    journalctl -u filebeat -f
    |
    +-- error in config --> fix and reload
    |
    v
[4] Can Filebeat/Logstash connect to Elasticsearch?
    filebeat test output
    curl http://elasticsearch:9200/_cluster/health
    |
    +-- failed --> check firewall, Elasticsearch URL, port
    |
    v
[5] Are logs being shipped to Elasticsearch?
    curl http://elasticsearch:9200/_cat/indices | grep app
    |
    +-- no indices --> parser may be failing, check Logstash logs
    |
    v
[6] Check Filebeat/Logstash logs for errors
    journalctl -u filebeat -f
    journalctl -u logstash -f
    |
    +-- parsing error, network error, or config issue
    |
    v
[7] Search Elasticsearch for logs
    curl 'http://elasticsearch:9200/app-*/_search?q=*' | jq '.hits.total'

Problem: Kibana Discover shows "No matching indices"
    |
    v
[1] Do any indices exist?
    curl http://elasticsearch:9200/_cat/indices
    |
    +-- empty --> no logs ingested yet, follow above flow
    |
    v
[2] Is the index pattern configured in Kibana?
    Kibana UI: Settings > Index Patterns
    |
    +-- not listed --> create new index pattern (e.g., "app-*")
    |
    v
[3] Is the time range correct?
    Kibana Discover: check time picker, verify data in time range
    |
    +-- future date or no data in range --> adjust time
    |
    v
[4] Check index mapping
    curl http://elasticsearch:9200/app-2026.03.17/_mapping | jq

Problem: Elasticsearch cluster health is yellow/red
    |
    v
[1] Check cluster status
    curl -s http://elasticsearch:9200/_cluster/health | jq
    |
    v
[2] Check unassigned shards
    curl -s http://elasticsearch:9200/_cat/shards | grep UNASSIGNED
    |
    v
[3] Investigate why shards are unassigned
    curl -s http://elasticsearch:9200/_cluster/allocation/explain | jq
    |
    v
[4] Most common causes:
    - insufficient nodes (add node or reduce replicas)
    - disk full on data nodes (free space)
    - node not available (restart node)
    |
    v
[5] Quick fix: reduce replica count
    curl -X PUT http://elasticsearch:9200/_settings \
      -d '{"number_of_replicas": 0}'
```

# Quick Facts (Revision)

- Elasticsearch indexes all fields using an inverted index; enables full-text search but requires more storage than Loki.
- Logstash is a powerful processing pipeline (input/filter/output); Filebeat is lightweight for simple log shipping.
- ILM (Index Lifecycle Management) moves indices through hot -> warm -> cold -> delete phases based on age or conditions.
- KQL (Kibana Query Language) uses field:value syntax; supports AND/OR/NOT and range queries.
- Shards enable parallel processing; replicas provide redundancy and read scaling.
- Cluster health: green (all shards allocated), yellow (replicas not allocated), red (primary shard missing).
- Choose Loki for structured logs and simplicity; choose ELK for complex analysis and unstructured logs.
- Grok is a regex-based pattern language for parsing unstructured logs; pre-built patterns available for common formats.
