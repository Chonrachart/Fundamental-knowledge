# Logging Overview

- Logging captures discrete events from applications, systems, and infrastructure; logs provide context unavailable in metrics alone.
- Log aggregation pipelines collect logs from multiple sources, parse them, and ship them to central storage for search and analysis.
- Centralized logging enables rapid incident response: correlate events by timestamp and service, trace execution flow, and identify root cause.

# Architecture

```text
+---------------+   +---------------+   +---------------+
|  Application  |   |  Application  |   |  System/Kernel|
|  (stdout,     |   |  (syslog)     |   |  (journald)   |
|   files)      |   |               |   |               |
+-------+-------+   +-------+-------+   +-------+-------+
        |                   |                   |
        |                   v                   v
        |           +-----------+      +------------------+
        |           | /var/log/ |      | systemd-journald |
        |           +-----------+      +------------------+
        |                   |                   |
        +---+-------+-------+---+-------+-------+
            |               |               |
            v               v               v
        +-------+       +-------+       +--------+
        |Promtail|      |Filebeat|      |Fluent-d|
        |LogAgent|      |Logstash|      |  Agent |
        +---+----+       +---+---+       +----+---+
            |               |                |
            +---+-------+---+---+-------+----+
                |               |
                v               v
        +------------------+  +------------------+
        |  Loki            |  | Elasticsearch    |
        | (log database)   |  | (search index)   |
        +-------+----------+  +----------+-------+
                |                       |
                +----------+----------+
                           |
                           v
                    +------------------+
                    |     Grafana      |
                    |  (logs + search) |
                    +------------------+
```

# Mental Model

```text
Log aggregation workflow:

  [1] Application outputs log line
       --> stdout, file, syslog, or event stream
       |
       v
  [2] Log agent scrapes or tails log source
       --> Promtail (Loki), Filebeat (Elasticsearch), Logstash
       --> apply parsing rules, relabel, filter
       |
       v
  [3] Log agent ships to backend
       --> batch, compress, retry on failure
       |
       v
  [4] Backend stores and indexes
       --> Loki (label-based), Elasticsearch (full-text)
       --> retention policy applied
       |
       v
  [5] User queries logs via UI or API
       --> Grafana, Kibana, LogQL, KQL filters
       |
       v
  [6] Correlate with metrics/traces
       --> search by timestamp, service, trace ID
```

```bash
# Example: application logs
echo '{"timestamp":"2026-03-17T10:15:30Z","level":"ERROR","service":"api","msg":"database connection failed"}' | \
  tee -a /var/log/app.log

# Log agent picks it up, parses, adds labels (job=api, env=prod), ships to Loki/Elasticsearch

# Query in Grafana:
# LogQL: {job="api"} | json | level="ERROR" | stats count by msg
# or Kibana KQL: service:"api" AND level:"ERROR"
```

# Core Building Blocks

### Structured vs Unstructured Logs

- **Structured logs** (JSON, key-value) have explicit fields that are parsed and indexed; easier to query and correlate.
- **Unstructured logs** (plain text) require regex or grok patterns for extraction; slower to search, higher cardinality risk.
- Best practice: emit structured logs (JSON) from applications; legacy unstructured logs can be parsed by agents.
- Structured logs (JSON) are faster to search and parse than unstructured (plain text); prefer JSON from applications.

```text
Unstructured:
  2026-03-17 10:15:30 ERROR [api] Connection to db failed after 5s retries

Structured (JSON):
  {"timestamp":"2026-03-17T10:15:30Z","level":"ERROR","service":"api","error":"Connection timeout","duration_ms":5000,"retries":5}
```

Related notes: [002-loki](./002-loki.md)
### Log Levels

- **DEBUG** -- verbose output for development; typically disabled in production.
- **INFO** -- significant events, state changes, startup/shutdown.
- **WARN** -- unusual conditions that may need attention but are recoverable.
- **ERROR** -- serious problem that failed; service still running.
- **FATAL** -- unrecoverable error; service is shutting down immediately.
- Log levels: DEBUG, INFO, WARN, ERROR, FATAL; use appropriate level to control verbosity.

Related notes: [../000-core](../000-core.md)

### Centralized Logging

- **Distributed systems** generate logs on many hosts; without centralization, debugging requires SSH to multiple machines.
- **Central repository** provides unified search across all services, time windows, and severity levels.
- **Incident response** accelerated: search by error message, trace ID, or service name to correlate events.
- **Compliance** and **audit trails** require persistent, tamper-proof log storage.
- Centralized logging accelerates incident response: search all services by timestamp, error message, or trace ID.

Related notes: [002-loki](./002-loki.md)
### Log Aggregation Pipeline

- **Collection** -- agents scrape logs from files, sockets, or event streams (Promtail, Filebeat, Logstash, Fluentd).
- **Parsing** -- extract fields using regex, JSON parsing, or grok patterns; add metadata (hostname, container ID).
- **Filtering** -- drop noisy logs, sample high-volume streams, drop PII.
- **Shipping** -- batch logs and send to backend; retry and queue on failure.
- **Storage** -- log database stores compressed logs with configurable retention (24h to years).
- **Querying** -- search via full-text (Elasticsearch) or label filters (Loki); correlate with metrics/traces.
- Log aggregation pipeline: collection (agent scrapes logs) -> parsing (extract fields) -> shipping (batch to backend) -> storage (Loki/Elasticsearch).

Related notes: [002-loki](./002-loki.md)
### Loki + Promtail + Grafana Stack

- **Loki** -- log database that indexes on **labels only** (not full-text); uses label-based filtering and metric aggregation (counts, rates).
- **Promtail** (legacy, replaced by **Grafana Alloy**) -- log agent that scrapes files or journald, applies pipeline stages (parse, relabel, drop), ships to Loki.
- **Grafana** -- unified visualization; panels query Loki with LogQL for logs and metrics (rate, count) from same timestamp.
- **Advantage** -- simple, low cost, integrates seamlessly with Prometheus metrics.
- **Trade-off** -- LogQL is more limited than full-text search; requires good label design.
- Promtail (now replaced by Grafana Alloy) is a lightweight agent for Loki; Filebeat is lightweight for Elasticsearch; Logstash is more powerful but heavier.

Related notes: [002-loki](./002-loki.md), [003-logql-deep-dive](./003-logql-deep-dive.md), [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md)

### ELK Stack (Elasticsearch, Logstash, Kibana)

- **Elasticsearch** -- distributed search and analytics engine; indexes all fields, supports full-text search and complex queries.
- **Logstash** -- processing pipeline (input/filter/output); parses logs, enriches with data, filters or transforms.
- **Kibana** -- visualization and search UI; Discover tab for ad-hoc search, dashboards, and alerts.
- **Filebeat** -- lightweight shipper (alternative to Logstash) that reads files and forwards to Elasticsearch or Logstash.
- **Advantage** -- powerful full-text search, flexible data model, extensive plugins and ecosystem.
- **Trade-off** -- higher resource use, more complex configuration, steeper learning curve.
- Loki indexes labels only (low cardinality); Elasticsearch indexes all fields (full-text search, higher resource use).

Related notes: [002-loki](./002-loki.md), [../Grafana/002-dashboards-queries](../Grafana/002-dashboards-queries.md)

### Syslog and Journald

- **Syslog** -- standard protocol (RFC 3164 / RFC 5424) for sending log messages to a central facility.
  - Format: `<PRI>HEADER TAG[PID]: MESSAGE`
  - Severity levels (emerg, alert, crit, err, warning, notice, info, debug) and facilities (kern, user, mail, daemon, syslog, lpr, news, uucp, cron, local0-7).
  - Reliable transport via UDP (lossy) or TCP (reliable).
- **Journald** -- systemd journal service that captures kernel messages, service logs, and container output.
  - Binary format with structured fields; query with `journalctl`.
  - Persistent storage in `/var/log/journal` or volatile in `/run/log/journal`.
- Journald is the systemd journal; query with `journalctl`. Syslog is a protocol for sending logs to a remote server.

Related notes: [002-loki](./002-loki.md)

### Log Rotation (logrotate)

- **Purpose** -- prevent log files from consuming unlimited disk space; archive old logs and free space.
- **Configuration** -- `/etc/logrotate.d/*` defines rotation policy per log file (daily, weekly, monthly, by size).
- **Options** -- rotate N old copies, compress, delete after X days, run scripts on rotation (e.g., reload service).
- **Manual trigger** -- `logrotate -f /etc/logrotate.d/nginx` forces rotation.
- Log rotation prevents disk space exhaustion; configure with `/etc/logrotate.d/` and rotate daily/weekly or by size.

```bash
# Example: /etc/logrotate.d/app
/var/log/app/*.log {
    daily                      # rotate every day
    rotate 7                   # keep 7 old logs
    compress                   # gzip old logs
    delaycompress              # delay compress to next rotation
    missingok                  # don't error if log is missing
    notifempty                 # don't rotate empty logs
    postrotate
        systemctl reload app 2>/dev/null || true
    endscript
}
```

Related notes: [../000-core](../000-core.md)

### Incident Response and Debugging

- **Log search** identifies which service or component failed and when; narrow down by error message, log level, or trace ID.
- **Correlation** across logs, metrics, and traces: a metric spike visible 10s before error logs helps pinpoint cause.
- **Context** from structured logs (request ID, user ID, service version) speeds root cause analysis.
- **Alerting on logs** -- query logs in aggregator and fire alert if error rate threshold breached (e.g., "ERROR" count > 10/min).

Related notes: [../000-core](../000-core.md), [../Grafana/003-alerting](../Grafana/003-alerting.md)

---

# Troubleshooting Guide

### Missing or delayed logs in centralized system

1. Are logs being generated on the source? `tail -f /var/log/app.log` or `journalctl -u app -f`. No logs means app not running or not configured to log.
2. Is the log agent running and tailing the file? `ps aux | grep promtail` / `systemctl status promtail`. Not running means start the agent.
3. Does the agent config point to the right log source? `cat /etc/promtail/config.yml | grep -A5 scrape_configs`. Wrong path or pattern means fix config and reload agent.
4. Can the agent connect to the backend? `curl -v http://loki:3100/loki/api/v1/status` or `curl -v http://elasticsearch:9200/_cluster/health`. Connection refused/timeout means check firewall and backend running.
5. Is the backend receiving logs? Loki: `curl http://loki:3100/loki/api/v1/label`. Elasticsearch: `curl http://elasticsearch:9200/_cat/indices`. No indices/labels means agent not shipping.
6. Check agent logs for errors: `journalctl -u promtail -f` or `docker logs <agent-container>`. Debug errors in agent config or backend connectivity.
7. Query backend to verify logs are indexed. Grafana Explore: query `{job="app"}`. Kibana: search `service:app`.
