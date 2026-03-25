# Prometheus Overview

- Prometheus is an open-source time-series database and monitoring system that pulls (scrapes) metrics from targets via HTTP.
- It stores metrics in a local TSDB with automatic compaction; PromQL query language enables flexible metric analysis and alerting.
- Core architecture: scrape configs define targets, service discovery finds them dynamically, TSDB stores with retention, Alertmanager routes notifications.

# Architecture

```text
+------------------------+   +------------------------+   +------------------------+
|   Application          |   |   Application          |   |   Node / Infrastructure |
|   (instrumented)       |   |   (instrumented)       |   |   (host metrics)       |
|   :8080/metrics        |   |   :9090/metrics        |   |   :9100/metrics        |
+--------+-------+-------+   +--------+-------+-------+   +--------+-------+-------+
         |       |                   |       |                   |       |
         |       +-------------------+-------+-------------------+-------+
         |                           |
         v                           v
    +----+-----+              +------+------+
    | pull/    |              | Service    |
    | scrape   |<-------------|  Discovery |
    +----+-----+              | (k8s_sd,   |
         |                    |  file_sd,  |
         |                    |  consul_sd)|
         v                    +------------+
    +---------------------------+
    |   Prometheus Server       |
    |                           |
    | +-------+   +------+      |
    | | TSDB  |   | WAL  |      |
    | +-------+   +------+      |
    |                           |
    | +-----+   +--------+      |
    | |Rules|   |Alerting|      |
    | +-----+   +--------+      |
    +---------------------------+
         |              |
         v              v
    +---------+    +------------------+
    | PromQL  |    | Alertmanager     |
    | Query   |    | (group, inhibit, |
    | (API)   |    |  route, notify)  |
    +---------+    +------------------+
         |              |
         v              v
   +----------+    +----------+
   | Grafana  |    | Webhooks |
   | /Tools   |    | /Slack   |
   +----------+    +----------+
```

# Mental Model

```text
Prometheus scrape cycle:

  [1] Read scrape config (targets, interval, timeout)
      |
      v
  [2] Resolve target addresses (service discovery expands groups)
      |
      v
  [3] HTTP GET /metrics on each target (default port 9090)
      |
      v
  [4] Parse Prometheus text format (metric_name{labels} value timestamp)
      |
      v
  [5] Write to TSDB with retention policy (default 15 days)
      |
      v
  [6] Evaluate alert rules against stored metrics
      |
      v
  [7] Fire alerts to Alertmanager when conditions breached
      |
      v
  [8] PromQL queries read from TSDB, aggregate, and return results
```

```text
Config structure example:

global:
  scrape_interval: 15s    # default scrape interval
  evaluation_interval: 15s # alert rule eval interval
  retention_time: 15d      # data retention (default)

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'nodes'
    static_configs:
      - targets: ['node1:9100', 'node2:9100']
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance

  - job_name: 'kubernetes'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: [default]
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:
  - '/etc/prometheus/rules/*.yml'
```

```bash
# once Prometheus is running, query metrics via HTTP API
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result'

# instant query for current value
curl -s 'http://localhost:9090/api/v1/query?query=node_cpu_seconds_total&time=1645500000'

# range query for time series
curl -s 'http://localhost:9090/api/v1/query_range?query=rate(http_requests_total[5m])&start=1645000000&end=1645100000&step=30s'
```

# Core Building Blocks

### Targets and Scrape Configs

- A target is a job (application, exporter, or infrastructure) that exposes metrics at a host:port.
- Scrape config defines how to reach targets (static_configs, service discovery), scrape interval, timeout, and metric relabeling.
- Prometheus uses pull/scrape model: periodically HTTP GET /metrics and parse the response.
- Targets must expose an HTTP endpoint on `/metrics` (or custom path via `metrics_path` param).
- Prometheus uses pull (scrape) model: HTTP GET /metrics on targets; targets push model uses Pushgateway.
- Scrape interval (default 15s), evaluation interval (default 15s), retention (default 15d) are configurable.

Related notes: [002-exporters-and-instrumentation](./002-exporters-and-instrumentation.md), [../000-core](../000-core.md)

### Static Configs vs Service Discovery

- Static configs list targets explicitly by hostname or IP in `prometheus.yml`; simple but requires manual updates.
- Service discovery integrates with infrastructure platforms (Kubernetes, Consul, DNS, EC2, Azure, GCP, file_sd) to dynamically discover targets.
- Service discovery resolves targets dynamically from Kubernetes, Consul, DNS, files, cloud providers, etc.
- Common SD mechanisms:
  - `kubernetes_sd_configs`: discover pods/services from Kubernetes API
  - `consul_sd_configs`: query Consul catalog for registered services
  - `file_sd_configs`: reload targets from JSON/YAML files (useful for custom scripts)
  - `dns_sd_configs`: resolve DNS A/SRV records to targets
  - EC2/Azure/GCP SD: query cloud provider APIs for instances

Related notes: [../000-core](../000-core.md), [002-exporters-and-instrumentation](./002-exporters-and-instrumentation.md)

### Metric Types Exposed by Prometheus

- Prometheus supports four metric types: counter, gauge, histogram, and summary — see [../000-core](../000-core.md) for definitions

Related notes: [../000-core](../000-core.md)

### TSDB Storage and Compaction

- Prometheus TSDB stores data locally in `./data/` directory (or configured via `--storage.tsdb.path`).
- Each chunk is time-ordered and compressed; blocks are immutable after 2 hours and auto-compacted into larger blocks.
- WAL (Write-Ahead Log) in `./data/wal/` ensures crash recovery; data is persisted before acknowledged.
- Retention policy: `--storage.tsdb.retention.time` (default 15 days) controls how long data is kept.
- Disk usage: ~1-2 bytes per sample at high compression; 1 million samples/s with 300 targets consumes ~50 GB/month.
- TSDB compaction: data written to WAL, then into 2-hour blocks, auto-compacted into larger blocks.

Related notes: [../000-core](../000-core.md), [003-alertmanager](./003-alertmanager.md)

### Remote Write and Read

- Remote write: Prometheus can send metrics to a remote TSDB (VictoriaMetrics, Cortex, Thanos, InfluxDB) for long-term storage, scale, or multi-region setup.
- Remote read: query remote TSDB transparently when local data is unavailable (retention has expired).
- Use cases: long-term retention (>15 days), federated monitoring, high-availability Prometheus clusters, cross-datacenter aggregation.
- Remote write/read enables long-term storage (Thanos, VictoriaMetrics) and high-availability setups; federation aggregates multiple Prometheus instances.

```text
Prometheus <--write--> Remote TSDB (e.g. Thanos, VictoriaMetrics)
            <--read---

Benefits:
  - Separate hot (local) and cold (remote) storage
  - High availability via multiple remote replicas
  - Global metrics view via Thanos query frontend
```

Related notes: [../000-core](../000-core.md)

### Federation

- Prometheus can scrape the `/federate` endpoint of another Prometheus instance to aggregate metrics.
- Useful for hierarchical monitoring: leaf Prometheus instances scrape targets locally, federated Prometheus aggregates them.
- Selector-based: federated query returns only matching series and supports relabeling.

```text
Leaf Prometheus (datacenter A):
  - scrapes local targets

Leaf Prometheus (datacenter B):
  - scrapes local targets

Federated Prometheus (global):
  - scrapes /federate from both leaf instances
  - aggregates and alerts on global view
```

Related notes: [../000-core](../000-core.md), [003-alertmanager](./003-alertmanager.md)

### Alerting Rules

- Alert rule defined in YAML: a PromQL query with a threshold, for duration, and labels/annotations.
- Prometheus evaluates rules at `evaluation_interval` (default 15s); when a condition is true for `for` duration, alert fires and sends to Alertmanager.
- Rules can be organized into multiple files (e.g. per job or service) and loaded via `rule_files` config.
- Alert rules written in YAML; evaluated at `evaluation_interval`; fire to Alertmanager after `for` duration is met.

```yaml
groups:
  - name: http_errors
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: |
          (sum(rate(http_requests_total{status=~"5.."}[5m]))
           / sum(rate(http_requests_total[5m]))) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High HTTP error rate on {{ $labels.instance }}"
          description: "Error rate is {{ $value | humanizePercentage }}"
```

Related notes: [003-alertmanager](./003-alertmanager.md), [../Grafana/003-alerting](../Grafana/003-alerting.md)

### PromQL Basics

- PromQL query language for selecting and aggregating time series.
- Instant vector: current value of a metric at a given time.
- Range vector: time series values over a time window (e.g. `http_requests_total[5m]`).
- Functions: `rate()`, `sum()`, `avg()`, `max()`, `histogram_quantile()`, etc.
- Common patterns: rate of change (`rate(counter[5m])`), error rate (`sum(rate(...[5m])) / sum(rate(...[5m]))`), quantiles (`histogram_quantile(0.99, ...)`).
- PromQL queries instant vectors (now) or range vectors (time window); functions like rate(), sum(), histogram_quantile().

Related notes: see PromQL subsections below

### Relabeling and Label Manipulation

- Relabeling transforms target labels before storage or dropping targets entirely.
- Used to rename labels, drop unwanted targets, extract info from URLs, or add custom metadata.
- Applied at two stages: target relabeling (before scrape) and metric relabeling (after scrape).

```yaml
relabel_configs:
  - source_labels: [__scheme__, __address__, __metrics_path__]
    separator: ';'
    regex: 'https?://([^:]+)(?::(\d+))?(.+)'
    replacement: '${1}:${2}'
    target_label: __address__
```

Related notes: [002-exporters-and-instrumentation](./002-exporters-and-instrumentation.md), [../000-core](../000-core.md)

### PromQL

- **Metric** = name + optional **labels** (key-value pairs); **sample** = (metric, timestamp, value).
- For metric type definitions (counter, gauge, histogram, summary), see [../000-core](../000-core.md)
- **Selectors**: `name{label="value"}`; operators: `=`, `!=`, `=~` (regex match), `!~` (regex not match).
- Example: `http_requests_total{job="api", code=~"5.."}` selects all 5xx requests for the api job.
- Query-building flow: select metric -> filter labels -> apply function (rate, increase) -> aggregate (sum, avg) -> format output.

Related notes: [../Grafana/002-dashboards-queries](../Grafana/002-dashboards-queries.md), [../000-core](../000-core.md)

### rate(), increase(), irate()

- **rate(metric[window])**: Per-second average rate over the window (e.g. 5m); use with counters only; smooths spikes.
- **increase(metric[window])**: Total increase over the window; approximately rate * seconds; use for "how many in the last 5m".
- **irate(metric[window])**: Instant rate calculated from the last two data points; more sensitive to spikes; use for fast-changing counters.
- Always apply a range with counters: `rate(http_requests_total[5m])` -- never use a bare counter in dashboards.

Related notes: [../Grafana/002-dashboards-queries](../Grafana/002-dashboards-queries.md)

### Aggregation Operators

- **sum**, **avg**, **min**, **max**, **count**, **count_values** -- aggregate across label dimensions.
- **by (label)**: Keep only the specified labels in the result (group by).
- **without (label)**: Remove the specified labels and aggregate the rest.
- Example: `sum(rate(http_requests_total[5m])) by (code)` -- request rate grouped by status code.
- Aggregation removes label dimensions; choose `by` or `without` to control what remains.

Related notes: [../Grafana/002-dashboards-queries](../Grafana/002-dashboards-queries.md)

### PromQL Functions

- **histogram_quantile(quantile, ...)**: Calculate percentile from histogram buckets; inner expression is usually `sum(rate(bucket[5m])) by (le, ...)`.
- **absent(metric)**: Returns 1 if the metric has no series; useful for "alert if metric is missing".
- **label_replace(v, dst, replacement, src, regex)**: Rewrite or create labels using regex capture groups.
- **label_join(v, dst, separator, src1, src2, ...)**: Concatenate label values into a new label.
- **delta(gauge[window])**: Difference between first and last value of a gauge over the window.
- **idelta(gauge[window])**: Instant delta from the last two points of a gauge.

Related notes: [../Grafana/003-alerting](../Grafana/003-alerting.md)

### Histogram Buckets and Quantiles

- Histogram exposes three metric families: `name_bucket{le="..."}` (cumulative counts), `name_count`, `name_sum`.
- Each bucket counts observations with value <= the `le` (less-than-or-equal) upper bound.
- To get percentiles: `histogram_quantile(0.9, sum(rate(name_bucket[5m])) by (le))` = 90th percentile.
- The `le="+Inf"` bucket equals `name_count` (all observations).
- Accuracy depends on bucket boundaries -- more buckets near the expected range gives better precision.

Related notes: [../Grafana/002-dashboards-queries](../Grafana/002-dashboards-queries.md)

### Recording Rules

- Pre-compute expensive PromQL expressions and store the result as a new time series in Prometheus.
- Defined in a rule file with **record** (new metric name) and **expr** (the PromQL expression).
- Reduces query load and latency for dashboards and alert rules that use heavy expressions.
- Naming convention: `level:metric:operations` (e.g. `job:http_requests_total:rate5m`).
- Evaluated on a configurable interval; results are written to TSDB like any scraped metric.

Related notes: [../Grafana/003-alerting](../Grafana/003-alerting.md)

### Example Queries

- **Error rate**: `sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))`
- **Request rate by path**: `sum(rate(http_requests_total[5m])) by (path)`
- **p99 latency**: `histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))`
- **Saturation (memory)**: `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes`
- **Alert if metric missing**: `absent(up{job="api"})` -- returns 1 when the api job has no `up` metric.

Related notes: [../Grafana/003-alerting](../Grafana/003-alerting.md), [../Grafana/002-dashboards-queries](../Grafana/002-dashboards-queries.md)

---

# Troubleshooting Guide

### Prometheus targets show as 'down'

1. Can Prometheus reach the target host? `ping <target>` / `curl http://<target>/metrics` -- network unreachable --> check firewall, routing, DNS.
2. Is the service running and listening on the expected port? `ss -tulnp | grep <port>` -- port not listening --> start service or check config.
3. Does the endpoint exist? `curl -v http://<target>:<port>/metrics` -- 404 or wrong path --> check metrics_path in scrape_config.
4. Check Prometheus scrape logs: `systemctl status prometheus` / `docker logs prometheus` -- connection timeout --> increase `scrape_timeout`; TLS error --> verify `ca_file`, `cert_file`, `key_file`.
5. Check target's application logs. Does the app have metrics enabled? Check instrumentation library.

### Alert not firing even though metric threshold is breached

1. Is the alert rule being evaluated? `curl http://localhost:9090/api/v1/rules | grep <alert_name>` -- rule not present --> check `rule_files` path in `prometheus.yml`; rule has syntax error --> `promtool check rules`.
2. Is the PromQL expression correct? `curl 'http://localhost:9090/api/v1/query?query=<expr>'` -- query returns no data --> wrong metric name or label filter.
3. Is the Alertmanager configured and reachable? `curl http://localhost:9093/-/healthy` -- Alertmanager not running --> start it or update alerting: config.
4. Check alert state transitions: `curl http://localhost:9090/api/v1/alerts | grep <alert_name>` -- state: Alerting --> check Alertmanager logs; state: Pending --> wait for 'for' duration to pass.
5. Review Prometheus logs for errors: `journalctl -u prometheus -f`.

### Prometheus disk usage growing too fast

1. How many samples per second are being scraped? `curl http://localhost:9090/api/v1/query?query=rate(prometheus_tsdb_symbol_table_size_bytes[5m])`.
2. Are there too many targets or high cardinality labels? Check number of active time series: `curl 'http://localhost:9090/api/v1/query?query=prometheus_tsdb_metric_chunks_created_total'` -- millions of series --> reduce targets or drop high-cardinality labels.
3. Is retention period too long? Check config: `--storage.tsdb.retention.time` -- reduce retention or implement remote write.
4. Check for memory/CPU saturation: `ps aux | grep prometheus` / `top` / `htop` -- memory high --> increase heap or enable WAL compression.
5. Consider remote write or splitting into multiple instances.

### PromQL query returns no data or unexpected results

1. Does the metric exist? Prometheus UI > search metric name, or: `curl localhost:9090/api/v1/label/__name__/values | grep metric_name`. Not found means target not scraped, or metric name wrong.
2. Are the labels correct? Run bare selector: `metric_name{job="api"}` in Prometheus UI. No results means label mismatch; check actual labels with `metric_name{}`.
3. Is the range vector window appropriate? `rate(metric[5m])` needs at least 2 samples in 5m. Too short window for scrape interval means increase window (window should be >= 4x `scrape_interval`).
4. Is the aggregation dropping needed labels? Check by/without clause; missing `by (le)` in histogram_quantile. Wrong grouping means add or remove labels in by/without.
5. Is a recording rule stale or misconfigured? Check `/api/v1/rules` for errors; verify rule file syntax with `promtool`. Rule error means fix expr and reload Prometheus (`kill -HUP` or `/-/reload`).
6. Check Prometheus targets and scrape health: Prometheus UI > Status > Targets -- look for DOWN targets or scrape errors.
