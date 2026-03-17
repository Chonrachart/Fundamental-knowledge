# PromQL Deep Dive

- PromQL is Prometheus's query language for selecting, filtering, and aggregating time-series data stored in its TSDB.
- Every metric is a combination of a name and key-value labels; each data point is a (metric, timestamp, value) sample.
- The query-building flow is: select metric -> filter labels -> apply function (rate, increase) -> aggregate (sum, avg) -> format output.

# Architecture

```text
+------------+       +-----------+       +--------+       +-------------+       +---------+
|  Targets   |       | Scrape    |       |  TSDB  |       |  PromQL     |       | Results |
| (app, node |------>| Engine    |------>| (time  |------>|  Engine     |------>| (table, |
|  exporter) |  pull | (interval |  store| series |  query| (parse,     |  out  |  graph, |
|            |       |  based)   |       | store) |       |  evaluate)  |       |  alert) |
+------------+       +-----------+       +--------+       +-------------+       +---------+

  /metrics              scrape_interval         queries from:
  endpoint              (e.g. 15s)              - Grafana dashboards
                                                - Alert rules
                                                - Recording rules
                                                - API / promtool
```

# Mental Model

```text
PromQL query-building flow:

  [1] Select metric        -->  http_requests_total
  [2] Filter labels        -->  http_requests_total{job="api", code=~"5.."}
  [3] Apply function       -->  rate(http_requests_total{job="api", code=~"5.."}[5m])
  [4] Aggregate            -->  sum(rate(...)) by (code)
  [5] Format / combine     -->  divide by total for error ratio
```

```text
Example: error rate calculation step by step

  Step 1: select counter       http_requests_total
  Step 2: filter 5xx codes     http_requests_total{code=~"5.."}
  Step 3: per-second rate      rate(http_requests_total{code=~"5.."}[5m])
  Step 4: sum all instances    sum(rate(http_requests_total{code=~"5.."}[5m]))
  Step 5: divide by total      sum(rate(http_requests_total{code=~"5.."}[5m]))
                                / sum(rate(http_requests_total[5m]))

  Result: fraction of requests returning 5xx over the last 5 minutes
```

# Core Building Blocks

### Prometheus Data Model

- **Metric** = name + optional **labels** (key-value pairs); **sample** = (metric, timestamp, value).
- **Metric types**:
  - **Counter** -- monotonically increasing (e.g. total requests); resets on restart.
  - **Gauge** -- goes up and down (e.g. CPU usage, temperature, queue length).
  - **Histogram** -- observations sorted into configurable buckets + count + sum.
  - **Summary** -- pre-calculated quantiles on the client side + count + sum.
- **Selectors**: `name{label="value"}`; operators: `=`, `!=`, `=~` (regex match), `!~` (regex not match).
- Example: `http_requests_total{job="api", code=~"5.."}` selects all 5xx requests for the api job.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md), [../000-core](../000-core.md)

### rate(), increase(), irate()

- **rate(metric[window])**: Per-second average rate over the window (e.g. 5m); use with counters only; smooths spikes.
- **increase(metric[window])**: Total increase over the window; approximately rate * seconds; use for "how many in the last 5m".
- **irate(metric[window])**: Instant rate calculated from the last two data points; more sensitive to spikes; use for fast-changing counters.
- Always apply a range with counters: `rate(http_requests_total[5m])` -- never use a bare counter in dashboards.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md)

### Aggregation Operators

- **sum**, **avg**, **min**, **max**, **count**, **count_values** -- aggregate across label dimensions.
- **by (label)**: Keep only the specified labels in the result (group by).
- **without (label)**: Remove the specified labels and aggregate the rest.
- Example: `sum(rate(http_requests_total[5m])) by (code)` -- request rate grouped by status code.
- Aggregation removes label dimensions; choose `by` or `without` to control what remains.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md)

### Functions

- **histogram_quantile(quantile, ...)**: Calculate percentile from histogram buckets; inner expression is usually `sum(rate(bucket[5m])) by (le, ...)`.
- **absent(metric)**: Returns 1 if the metric has no series; useful for "alert if metric is missing".
- **label_replace(v, dst, replacement, src, regex)**: Rewrite or create labels using regex capture groups.
- **label_join(v, dst, separator, src1, src2, ...)**: Concatenate label values into a new label.
- **delta(gauge[window])**: Difference between first and last value of a gauge over the window.
- **idelta(gauge[window])**: Instant delta from the last two points of a gauge.

Related notes: [003-alerting](./003-alerting.md)

### Histogram -- Buckets and Quantiles

- Histogram exposes three metric families: `name_bucket{le="..."}` (cumulative counts), `name_count`, `name_sum`.
- Each bucket counts observations with value <= the `le` (less-than-or-equal) upper bound.
- To get percentiles: `histogram_quantile(0.9, sum(rate(name_bucket[5m])) by (le))` = 90th percentile.
- The `le="+Inf"` bucket equals `name_count` (all observations).
- Accuracy depends on bucket boundaries -- more buckets near the expected range gives better precision.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md)

### Recording Rules

- Pre-compute expensive PromQL expressions and store the result as a new time series in Prometheus.
- Defined in a rule file with **record** (new metric name) and **expr** (the PromQL expression).
- Reduces query load and latency for dashboards and alert rules that use heavy expressions.
- Naming convention: `level:metric:operations` (e.g. `job:http_requests_total:rate5m`).
- Evaluated on a configurable interval; results are written to TSDB like any scraped metric.

Related notes: [003-alerting](./003-alerting.md)

### Example Queries

- **Error rate**: `sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))`
- **Request rate by path**: `sum(rate(http_requests_total[5m])) by (path)`
- **p99 latency**: `histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))`
- **Saturation (memory)**: `node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes`
- **Alert if metric missing**: `absent(up{job="api"})` -- returns 1 when the api job has no `up` metric.

Related notes: [003-alerting](./003-alerting.md), [002-dashboards-queries](./002-dashboards-queries.md)

---

# Practical Command Set (Core)

```bash
# query Prometheus directly via API (instant query)
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq .

# query with a time range (range query, last 5 minutes, 15s step)
curl -s 'http://localhost:9090/api/v1/query_range?query=rate(http_requests_total[5m])&start=2024-01-01T00:00:00Z&end=2024-01-01T00:05:00Z&step=15s' | jq .

# list all metric names
curl -s 'http://localhost:9090/api/v1/label/__name__/values' | jq .

# list label values for a specific label
curl -s 'http://localhost:9090/api/v1/label/job/values' | jq .

# check recording and alerting rules
curl -s 'http://localhost:9090/api/v1/rules' | jq .

# validate a rules file before loading
promtool check rules /etc/prometheus/rules/*.yml
```

# Troubleshooting Guide

```text
Problem: PromQL query returns no data or unexpected results
    |
    v
[1] Does the metric exist?
    Prometheus UI > search metric name, or:
    curl localhost:9090/api/v1/label/__name__/values | grep metric_name
    |
    +-- not found --> target not scraped, or metric name wrong
    |
    v
[2] Are the labels correct?
    Run bare selector: metric_name{job="api"} in Prometheus UI
    |
    +-- no results --> label mismatch; check actual labels with metric_name{}
    |
    v
[3] Is the range vector window appropriate?
    rate(metric[5m]) needs at least 2 samples in 5m
    |
    +-- too short window for scrape interval --> increase window
    |   (window should be >= 4x scrape_interval)
    |
    v
[4] Is the aggregation dropping needed labels?
    Check by/without clause; missing "by (le)" in histogram_quantile
    |
    +-- wrong grouping --> add or remove labels in by/without
    |
    v
[5] Is a recording rule stale or misconfigured?
    Check /api/v1/rules for errors; verify rule file syntax with promtool
    |
    +-- rule error --> fix expr and reload Prometheus (kill -HUP or /-/reload)
    |
    v
[6] Check Prometheus targets and scrape health
    Prometheus UI > Status > Targets -- look for DOWN targets or scrape errors
```

# Quick Facts (Revision)

- Metric = name + labels; sample = (metric, timestamp, value); four types: counter, gauge, histogram, summary.
- rate() for per-second average over a window; increase() for total over a window; irate() for instant rate -- all for counters only.
- Always use a range vector with counters: `rate(counter[5m])`, never a bare counter.
- Aggregation operators (sum, avg, min, max) use `by` to keep labels or `without` to drop labels.
- histogram_quantile(q, sum(rate(bucket[5m])) by (le)) -- the `by (le)` is mandatory for correct percentile calculation.
- Recording rules pre-compute heavy expressions; naming convention: `level:metric:operations`.
- absent(metric) returns 1 when no series exist -- use for "is this target alive" alerts.
- Window should be at least 4x the scrape_interval to guarantee enough data points for rate().
