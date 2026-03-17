# Exporters and Instrumentation

- Exporters are agents or libraries that expose application or infrastructure metrics in Prometheus format at a /metrics endpoint.
- Applications can instrument themselves directly with client libraries (Go, Python, Java, Node.js) or use exporters to scrape existing systems.
- Instrumentation captures counters (requests, errors), gauges (CPU, memory), histograms (latency), and summaries (quantiles).

# Architecture

```text
+------------------+                    +------------------+
|  Application     |                    |  3rd-party System|
|  (instrumented)  |                    |  (e.g. database) |
|  client library  |                    |  no instrumentation
+--------+---------+                    +--------+---------+
         |                                      |
         | metrics recorded                     | system queries
         | in-memory                            |
         v                                      v
    +--------+                            +-----------+
    | /metrics                            | Exporter  |
    | endpoint                            | (scraper) |
    | (Prometheus text format)            | translates
    +---+----+                            | to Prometheus
        |    |                            | format
        |    +--------+                   |
        |             |                   |
        +-----+-------+---+--------+------+
              |           |
              v           v
        +---------+   +----------+
        |Prometheus|  |Alertmanager
        |  scrapes |  |sends alerts
        |targets   |  |
        +---------+   +----------+
```

# Mental Model

```text
Instrumentation flow:

  [1] Application initializes Prometheus client library
      (Go: github.com/prometheus/client_golang)
      (Python: prometheus-client)
      (Java: micrometer)
      |
      v
  [2] Define metrics: counters, gauges, histograms, summaries
      Example: http_requests_total, request_duration_seconds
      |
      v
  [3] Instrument code to record observations
      counter.Inc()  # when request completes
      histogram.Observe(latency)  # measure latency
      |
      v
  [4] Library aggregates data in-memory by labels
      http_requests_total{method="GET", path="/api/users", status="200"} = 1045
      |
      v
  [5] Application exposes /metrics endpoint (HTTP listener)
      GET /metrics returns all metrics in Prometheus text format
      |
      v
  [6] Prometheus scrapes /metrics periodically (default 15s)
      Stores time series with timestamp and labels
```

```text
Example: Instrument a web request handler

Go:
  var httpRequestsTotal = prometheus.NewCounterVec(
    prometheus.CounterOpts{Name: "http_requests_total"},
    []string{"method", "path", "status"},
  )

  func handleRequest(w http.ResponseWriter, r *http.Request) {
    start := time.Now()

    // ... handle request ...

    status := "200"
    httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, status).Inc()
    requestDuration.WithLabelValues(r.Method).Observe(time.Since(start).Seconds())
  }

Python:
  from prometheus_client import Counter, Histogram

  http_requests_total = Counter(
    'http_requests_total',
    'Total requests',
    ['method', 'path', 'status']
  )
  request_duration = Histogram(
    'request_duration_seconds',
    'Request latency'
  )

  http_requests_total.labels(method='GET', path='/api', status='200').inc()
  request_duration.observe(0.123)  # seconds
```

# Core Building Blocks

### Node Exporter

- Official Prometheus exporter for infrastructure metrics (Linux, BSD, macOS).
- Exposes system metrics: CPU, memory, disk, network, interrupts, filesystem, thermal, power.
- Runs as a service and exposes /metrics at default port 9100.
- Metric names follow pattern: `node_<metric>_<unit>` e.g. `node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`.
- Installation: download binary or `apt install prometheus-node-exporter`.

```bash
# start node exporter
node_exporter --collector.textfile.directory=/var/lib/node_exporter/textfile_collector

# available collectors (can be enabled/disabled)
node_exporter --help | grep collector

# common collectors: cpu, memory, disk, network, filesystem, systemd
# custom metrics via textfile collector: create .prom files in a directory
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../000-core](../000-core.md)

### Application Instrumentation (Client Libraries)

- Official client libraries: Go, Python, Java, Node.js, Ruby, C++, Rust, PHP.
- Each library provides Prometheus, Counter, Gauge, Histogram, and Summary metric types.
- Metrics are registered with the default registry and exposed via an HTTP listener.
- Typical flow: initialize client, register metrics, record observations in code, expose /metrics endpoint.

```bash
# Go client library
go get github.com/prometheus/client_golang

# Python client library
pip install prometheus-client

# Java/Spring Boot (Micrometer)
<dependency>
  <groupId>io.micrometer</groupId>
  <artifactId>micrometer-core</artifactId>
</dependency>

# Node.js client
npm install prom-client
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md)

### Common Exporters (Pre-built)

- **Blackbox Exporter**: probes HTTP/HTTPS, TCP, ICMP endpoints for availability and latency (e.g. website uptime, health checks).
- **Node Exporter**: infrastructure metrics (CPU, memory, disk, network, thermal, process).
- **MySQLd Exporter**: MySQL server and replication metrics (slow queries, connections, table locks).
- **PostgreSQL Exporter**: PostgreSQL database metrics (connections, queries, replication lag, table/index bloat).
- **Redis Exporter**: Redis memory, keys, commands, replication metrics.
- **MongoDB Exporter**: MongoDB operations, replication, storage metrics.
- **Elasticsearch Exporter**: cluster health, node stats, shards, indices metrics.
- **HAProxy Exporter**: load balancer connections, bytes, requests.
- **Nginx/Apache Exporter**: web server connections, requests, status codes.
- **AWS CloudWatch Exporter**: scrape CloudWatch API and expose as Prometheus metrics.

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../000-core](../000-core.md)

### Metric Types Exposed by Exporters

- **Counter**: always increases or resets (http_requests_total, errors_total, bytes_transmitted).
- **Gauge**: current value up or down (memory_bytes, cpu_percent, active_connections).
- **Histogram**: distribution of observations in buckets (request_duration_seconds_bucket, response_size_bytes_bucket).
- **Summary**: quantile observations (p50, p95, p99 of latency); deprecated in favor of histograms for Prometheus 1.0+.
- Exporters emit metrics in Prometheus text format: `metric_name{label1="value1", label2="value2"} value timestamp`.

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../Grafana/004-promql-deep-dive](../Grafana/004-promql-deep-dive.md)

### Custom Exporters and Collectors

- Build a custom exporter if no existing one covers your system (proprietary app, legacy service, custom metrics).
- Exporters are minimal HTTP servers that query the target system and translate responses to Prometheus format.
- Approach: define what to collect, query the system (REST API, CLI, database), parse response, emit metrics.

```text
Example custom exporter flow:

[1] Read config (target URL, credentials, endpoints to query)
[2] On each /metrics request:
    - Query target API or system
    - Parse response (JSON, XML, text)
    - Calculate metrics (counters, gauges, rates)
    - Write Prometheus text format
    - Return 200 OK
[3] Prometheus scrapes /metrics at interval
```

```bash
# minimal custom exporter in Python
from prometheus_client import Counter, Gauge, generate_latest, start_http_server
import requests
import time

http_requests = Counter('custom_http_requests_total', 'Total requests', ['service'])
latency_gauge = Gauge('custom_latency_ms', 'Latency', ['endpoint'])

def collect_metrics():
    while True:
        resp = requests.get('http://myapp:8080/api/stats')
        data = resp.json()

        for req in data['requests']:
            http_requests.labels(service=req['service']).inc()

        latency_gauge.labels(endpoint='/api').set(data['latency_ms'])

        time.sleep(15)  # scrape interval

# start HTTP server on port 8000
start_http_server(8000)
collect_metrics()
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../000-core](../000-core.md)

### Pushgateway

- Pushgateway is used when applications cannot be scraped (ephemeral batch jobs, short-lived processes).
- Application pushes metrics to Pushgateway via HTTP POST; Prometheus scrapes the Pushgateway.
- Useful for: cron jobs, batch tasks, Lambda functions, scheduled reports (anything that exits before next scrape).
- Pushgateway stores metrics per job and instance; allows multiple pushes to the same job/instance (appends).

```text
Typical push flow:

Cron job / Batch task:
  [1] Calculate metrics
  [2] HTTP POST /metrics/job/my_job/instance/host1
  [3] Metric stored in Pushgateway
  [4] Task exits

Prometheus:
  [1] Scrape Pushgateway every 15s
  [2] Retrieve metrics for all jobs/instances
  [3] Store in TSDB
```

```bash
# Pushgateway default port: 9091

# start Pushgateway
pushgateway --persistence.file=/var/lib/pushgateway/metrics.db

# push metrics from a job
curl -X POST --data-binary @metrics.txt http://pushgateway:9091/metrics/job/my_batch_job/instance/host1

# or via command line
curl -X POST --data 'my_metric_total 42' http://pushgateway:9091/metrics/job/test_job

# view Pushgateway UI
http://pushgateway:9091

# delete metrics for a job
curl -X DELETE http://pushgateway:9091/metrics/job/test_job
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../000-core](../000-core.md)

### Exporter Best Practices

- One exporter per system: avoid collecting from multiple sources in one exporter (separation of concerns).
- Use descriptive metric names: follow `exporter_metric_type` convention (e.g. `mysql_connections`, `redis_keys_total`).
- Include unit suffix: _seconds, _bytes, _total, _percent (helps with PromQL unit inference).
- Avoid high cardinality labels: too many unique label combinations cause memory bloat and poor performance.
- Document metrics: include help text describing what each metric means.
- Test metrics: ensure all series are emitted, values are correct, no label explosion.
- Handle errors gracefully: if query fails, exporter returns error but Prometheus still marks target as up (remove problematic collector).
- Keep scrape time short: target exporter should respond in <10s to avoid timeouts.

```bash
# check for high cardinality (number of unique time series)
curl -s 'http://prometheus:9090/api/v1/query?query=count(count({exporter="mysql"}) by (__name__))' | jq '.data.result'

# if count is millions, investigate label cardinality
curl -s 'http://prometheus:9090/api/v1/query?query=count by (label_name) (mysql_metric)' | jq '.data.result'
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../000-core](../000-core.md)

### Instrumentation Guidelines

- Instrument business logic: track application-specific events (user signups, orders, errors).
- Track the four golden signals: latency (request duration), traffic (requests per second), errors (error rate), saturation (resource utilization).
- Use appropriate metric types: counter for cumulative totals, gauge for instantaneous values, histogram for distributions.
- Keep label cardinality low: don't use user IDs or request IDs as labels; use aggregates (by endpoint, service, method).
- Initialize metrics before code execution: register all metrics at startup, not dynamically during requests.
- Avoid blocking on metric recording: publish metrics asynchronously to prevent latency impact.

```bash
# Go example: instrumenting a web service
package main

import (
  "github.com/prometheus/client_golang/prometheus"
  "github.com/prometheus/client_golang/prometheus/promhttp"
  "net/http"
  "time"
)

var (
  httpDuration = prometheus.NewHistogramVec(
    prometheus.HistogramOpts{
      Name: "http_request_duration_seconds",
      Buckets: prometheus.DefBuckets,
    },
    []string{"method", "path", "status"},
  )
)

func init() {
  prometheus.MustRegister(httpDuration)
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
  start := time.Now()
  defer func() {
    status := "200"  // simplified; should capture actual status
    httpDuration.WithLabelValues(r.Method, r.URL.Path, status).Observe(time.Since(start).Seconds())
  }()

  // ... handle request ...
  w.WriteHeader(http.StatusOK)
}

func main() {
  http.HandleFunc("/api/users", handleRequest)
  http.Handle("/metrics", promhttp.Handler())
  http.ListenAndServe(":8080", nil)
}
```

Related notes: [001-prometheus-overview](./001-prometheus-overview.md), [../000-core](../000-core.md)

---

# Practical Command Set (Core)

```bash
# -- Node Exporter --
# start node exporter on port 9100
node_exporter

# check node metrics
curl -s http://localhost:9100/metrics | head -20

# test a specific metric
curl -s http://localhost:9100/metrics | grep 'node_cpu_seconds_total'

# -- Custom Exporter / Instrumentation --
# start a simple exporter (if built as server)
./my_custom_exporter --port=9999

# push metrics to Pushgateway
echo "my_metric 42" | curl -X POST --data-binary @- http://pushgateway:9091/metrics/job/test

# check Pushgateway contents
curl http://pushgateway:9091/metrics | grep my_metric

# -- Testing Metrics --
# validate Prometheus text format
curl -s http://localhost:8080/metrics | promtool query instant

# check metric syntax for exporter endpoint
curl -s http://exporter:9100/metrics | grep -E '^[a-zA-Z_:][a-zA-Z0-9_:]*\{' | head -5

# count number of unique metrics
curl -s http://localhost:9100/metrics | grep -v '^#' | cut -d'{' -f1 | sort -u | wc -l

# -- Debugging Exporters --
# verbose curl to check headers and response time
curl -w '\nTime: %{time_total}s\n' -v http://localhost:9100/metrics 2>&1 | head -30

# test exporter health (HTTP 200)
curl -I -s -o /dev/null -w '%{http_code}\n' http://localhost:9100/metrics

# check if exporter is consuming high memory
ps aux | grep -E 'exporter|node_exporter' | grep -v grep
```

# Troubleshooting Guide

```text
Problem: Exporter endpoint returns no metrics or errors
    |
    v
[1] Is the exporter service running?
    curl http://localhost:9100/metrics
    |
    +-- connection refused --> start exporter
    +-- 500 error --> check exporter logs
    |
    v
[2] Check exporter logs for errors
    systemctl status node_exporter -l
    journalctl -u node_exporter -f
    |
    +-- permission denied --> run with correct user/privileges
    +-- config error --> validate exporter config file
    |
    v
[3] Does the exporter have access to system resources?
    node_exporter needs /proc, /sys readable
    ls -la /proc /sys
    |
    +-- permission denied --> check sudo, capabilities, or container mounts
    |
    v
[4] Check exporter response time
    curl -w '%{time_total}s\n' http://localhost:9100/metrics
    |
    +-- > 10 seconds --> exporter is slow, investigate target system
    |
    v
[5] Validate metrics format
    curl http://localhost:9100/metrics | head -10
    Should see: # HELP, # TYPE, metric_name{labels} value


Problem: Application instrumentation not working (no metrics in Prometheus)
    |
    v
[1] Is the /metrics endpoint exposed by the application?
    curl http://app:8080/metrics
    |
    +-- 404 --> application not exposing metrics, check code
    +-- connection refused --> application not running
    |
    v
[2] Are metrics being initialized in the code?
    Check application logs: "Prometheus metrics registered"
    |
    +-- not logged --> metrics not initialized at startup
    |
    v
[3] Is Prometheus scraping the application?
    curl http://prometheus:9090/api/v1/targets | grep <job_name>
    |
    +-- target down --> check firewall, port, application logs
    +-- target up but no data --> metrics not being recorded in code
    |
    v
[4] Review application instrumentation code
    Is the metric being incremented/observed?
    Add debug logging: "Recorded metric: counter=X"
    |
    v
[5] Check for label cardinality issues
    curl 'http://prometheus:9090/api/v1/query?query=count(my_app_metric)'
    |
    +-- value very large --> too many label combinations
    |
    v
[6] Restart application and scrape Prometheus again
    wait 15-30 seconds for data to appear


Problem: Pushgateway metrics disappear
    |
    v
[1] Did the job finish and timeout?
    Pushgateway default TTL is metric retention (check settings)
    |
    v
[2] Are you pushing with the same job and instance labels?
    curl -X POST http://pushgateway:9091/metrics/job/X/instance/Y
    |
    +-- different labels each push --> creates new series, old ones expire
    |
    v
[3] Is Prometheus configured to scrape Pushgateway?
    Check prometheus.yml: scrape_configs for pushgateway job
    |
    +-- not configured --> add it
    |
    v
[4] Check Pushgateway UI for metrics
    http://pushgateway:9091
    |
    +-- empty --> nothing was pushed
    |
    v
[5] Review Pushgateway persistence settings
    If not persistent, metrics lost after restart
```

# Quick Facts (Revision)

- Exporters expose system metrics in Prometheus format; applications instrument with client libraries or use exporters for legacy systems.
- Node Exporter scrapes infrastructure (CPU, memory, disk, network); runs on port 9100 by default.
- Metric types: counter (cumulative), gauge (instantaneous), histogram (distribution), summary (quantiles, deprecated).
- Metric naming: `exporter_name_unit` with help text (e.g. `mysql_connections_total`, `redis_memory_bytes`).
- Avoid high cardinality labels: don't use user ID, request ID, or unbounded dimensions as labels.
- Pushgateway for ephemeral jobs: batch/cron jobs push metrics instead of being scraped; Prometheus scrapes Pushgateway.
- Client libraries (Go, Python, Java, Node.js) record metrics in-memory and expose /metrics HTTP endpoint.
- Custom exporters query external systems and translate to Prometheus format; useful for proprietary or legacy applications.
- Exporter best practices: one per system, descriptive names, unit suffixes, low cardinality, error handling, fast response time.
