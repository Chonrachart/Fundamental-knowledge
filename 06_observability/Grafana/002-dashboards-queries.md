panel
query
PromQL
variable
transform
annotation

---

# Panel Types

- **Time series**: Line/area graph over time; primary for metrics.
- **Stat**, **Gauge**: Single number or gauge; current value or summary.
- **Table**: Rows and columns; from query or transform.
- **Bar chart**, **Histogram**: Distribution or comparison.
- **Logs**: Log lines (Loki, Elasticsearch data source).

# Query

- Each panel has one or more queries; data source specific.
- **Prometheus**: PromQL (e.g. `rate(http_requests_total[5m])`).
- **InfluxDB**: Flux or InfluxQL.
- **Loki**: LogQL for logs.
- **Transform**: After query — rename, merge, filter, organize for visualization.

# PromQL (Prometheus)

- **Metric name**: `http_requests_total`; with labels: `{job="api", method="GET"}`.
- **rate()**: Per-second rate over window; for counters: `rate(counter[5m])`.
- **increase()**: Total increase over window.
- **sum by (label)**: Aggregate; group by label.
- **histogram_quantile()**: Percentile from histogram metrics.
- Example: `sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))` — error ratio.

# Variable

- Dashboard variable: dropdown or multi-select; use in queries as `$variable`.
- Types: query (from data source), custom, constant, interval.
- Use for env, host, job, or time interval so one dashboard fits many contexts.

# Annotation

- Mark events on time series (deploy, incident); from query (e.g. deployment events) or manual.
- Helps correlate changes with metric changes.
