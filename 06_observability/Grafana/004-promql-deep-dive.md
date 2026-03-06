PromQL
metric
selector
rate
aggregation
function
histogram
recording rule

---

# Prometheus Data Model

- **Metric** = name + optional **labels**; **sample** = (metric, timestamp, value).
- **Types**: **Counter** (monotonically increasing), **Gauge** (up/down), **Histogram** (buckets + count/sum), **Summary** (quantiles).
- **Selector**: **name{label="value"}**; **=**, **!=**, **=~** (regex), **!~**; e.g. `http_requests_total{job="api", code=~"5.."}`.

# rate() and increase()

- **rate(metric[window])**: Per-second **average** rate over **window** (e.g. 5m); for **counters** only; smooths spikes.
- **increase(metric[window])**: Total increase over window ≈ rate * seconds; use for “total in last 5m”.
- **irate(metric[5m])**: Instant rate from last two points; more spikey; use for fast-changing counters.
- Always use **range** with counter: `rate(http_requests_total[5m])` not `http_requests_total`.

# Aggregation

- **sum(rate(...))**: Sum over labels (e.g. over all instances); **sum by (job)(rate(...))** group by **job**.
- **avg**, **min**, **max**, **count**, **count_values**; **without (label)** or **by (label)** to group.
- Example: **sum(rate(http_requests_total[5m])) by (code)** — request rate per status code.

# Functions

- **histogram_quantile(0.95, ...)**: 95th percentile from **histogram**; inner expr usually **sum(rate(bucket[5m])) by (le, ...)**.
- **absent(metric)**: 1 if metric has no series; for “alert if missing”.
- **label_replace**, **label_join**: Modify labels.
- **increase**, **delta** (for gauge); **idelta** for instant delta.

# Histogram — Buckets and Quantiles

- **Metric**: **name_bucket** (le=upper bound), **name_count**, **name_sum**.
- **rate(name_bucket[5m])** gives per-second rate of observations in each bucket; **histogram_quantile(0.9, sum(rate(...)) by (le))** = 90th percentile.
- **Recording rule**: Pre-compute heavy expr (e.g. `rate(http_request_duration_seconds_bucket[5m])`) so dashboards/alerts are fast.

# Recording Rules

- **Pre-compute** in Prometheus; **rule file** defines **record** (new metric name) and **expr** (PromQL).
- Reduces load and latency for dashboards/alerts; store in same or separate Prometheus (e.g. for long retention).

# Example Queries (Summary)

- Error rate: `sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))`
- Request rate by path: `sum(rate(http_requests_total[5m])) by (path)`
- 99th latency: `histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))`
