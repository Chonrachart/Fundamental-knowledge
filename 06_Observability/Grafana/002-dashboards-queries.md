# Dashboards and Queries

- Dashboards are built from panels; each panel runs one or more queries against a data source and renders a visualization.
- Queries use data-source-specific languages (PromQL, LogQL, Flux); transforms reshape results before display.
- Variables, annotations, and panel linking make dashboards dynamic and reusable across environments.

# Architecture

```text
+-----------------+     +-----------------+     +-----------------+
|  Prometheus     |     |  Loki           |     |  InfluxDB       |
|  (PromQL)       |     |  (LogQL)        |     |  (Flux)         |
+--------+--------+     +--------+--------+     +--------+--------+
         |                        |                       |
         +------------+-----------+-----------+-----------+
                      |
                      v
            +---------+---------+
            |   Query Engine    |
            |  (parse, execute, |
            |   return frames)  |
            +---------+---------+
                      |
                      v
            +---------+---------+
            |    Transforms     |
            |  (rename, merge,  |
            |   filter, calc)   |
            +---------+---------+
                      |
                      v
            +---------+---------+
            |   Visualization   |
            |  (time series,    |
            |   stat, gauge,    |
            |   table, logs)    |
            +---------+---------+
                      |
                      v
            +---------+---------+
            |   Dashboard       |
            |  (panels + vars   |
            |   + annotations)  |
            +-------------------+
```

# Mental Model

```text
Dashboard building workflow:

  [1] Choose panel type    -->  time series, stat, gauge, table, bar chart, logs
  [2] Write query          -->  PromQL / LogQL / Flux targeting a data source
  [3] Apply transforms     -->  rename fields, merge queries, filter rows, add calculations
  [4] Set variables        -->  $host, $env, $job as dropdown filters
  [5] Add annotations      -->  mark deploys/incidents on time series
  [6] Arrange and share    -->  grid layout, folder permissions, JSON export
```

```text
Example: CPU usage dashboard with host selector

  Panel type:   Time series
  Data source:  Prometheus
  Query:        100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle", instance=~"$host"}[5m])) * 100)
  Variable:     $host = label_values(node_cpu_seconds_total, instance)
  Transform:    Rename field "instance" to "Host"
  Annotation:   Query deployment events from Loki
```

# Core Building Blocks

### Panel Types

- **Time series** -- line/area graph over time; the primary panel for metrics.
- **Stat** -- single large number; shows current value, mean, or last value.
- **Gauge** -- arc or bar showing value against min/max thresholds.
- **Table** -- rows and columns; from raw query results or after transforms.
- **Bar chart / Histogram** -- distribution or categorical comparison.
- **Logs** -- displays log lines from Loki or Elasticsearch data sources.
- Panel types: time series (primary), stat, gauge, table, bar chart, logs.

Related notes: [001-grafana-overview](./001-grafana-overview.md)

### Query

- Each panel has one or more queries; each query targets a data source.
- **Prometheus** -- PromQL: `rate(http_requests_total[5m])`.
- **InfluxDB** -- Flux or InfluxQL for time series data.
- **Loki** -- LogQL for log aggregation and filtering.
- Multiple queries in one panel overlay results for comparison.
- Query options: min interval, max data points, relative time shift.
- Each panel runs one or more queries in the data source language (PromQL, LogQL, Flux).
- Use Explore mode to test queries before adding them to a panel.

Related notes: [004-promql-deep-dive](./004-promql-deep-dive.md), [001-grafana-overview](./001-grafana-overview.md)

### Transforms

- Applied after query, before visualization.
- **Rename** -- change field/column names for display.
- **Merge** -- combine results from multiple queries into one table.
- **Filter** -- include/exclude rows by value or regex.
- **Organize fields** -- reorder, hide, or override field types.
- **Add field from calculation** -- compute new fields (e.g. ratio, difference).
- Transforms reshape query results before rendering: rename, merge, filter, calculate.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md)

### PromQL Basics

- **Metric name** -- `http_requests_total`; filter with labels: `{job="api", method="GET"}`.
- **rate()** -- per-second rate over a time window; use on counters: `rate(counter[5m])`.
- **increase()** -- total increase over a window; syntactic sugar for `rate() * seconds`.
- **sum by (label)** -- aggregate across series, group by one or more labels.
- **histogram_quantile()** -- compute percentiles from histogram metrics: `histogram_quantile(0.95, sum(rate(http_duration_bucket[5m])) by (le))`.
- **Error ratio example** -- `sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))`.
- PromQL essentials: rate() for counters, sum by() for aggregation, histogram_quantile() for percentiles.

Related notes: [004-promql-deep-dive](./004-promql-deep-dive.md), [../000-core](../000-core.md)

### Variables

- Dashboard variable creates a dropdown or multi-select; referenced in queries as `$variable`.
- **Query** type -- values fetched from a data source (e.g. `label_values(metric, label)`).
- **Custom** type -- hardcoded comma-separated list.
- **Constant** type -- single hidden value (e.g. datasource name).
- **Interval** type -- time interval values (1m, 5m, 15m) for `$__interval` overrides.
- Use variables for host, environment, job, or namespace so one dashboard serves many contexts.
- Variables (`$host`, `$env`) make dashboards reusable; query type fetches values dynamically.
- Dashboard JSON can be exported, version-controlled, and provisioned via `/etc/grafana/provisioning/`.

Related notes: [001-grafana-overview](./001-grafana-overview.md)

### Annotations

- Mark events on time series panels (deployments, incidents, config changes).
- **Query-based** -- pull events from a data source (e.g. deployment records from Loki or Prometheus).
- **Manual** -- click on a graph to add a point-in-time or region annotation.
- Correlate metric spikes with real-world changes visible on the same timeline.
- Annotations overlay events (deploys, incidents) on time series for correlation.

Related notes: [001-grafana-overview](./001-grafana-overview.md), [../Zabbix/001-zabbix-overview](../Zabbix/001-zabbix-overview.md)

---

# Practical Command Set (Core)

```bash
# provision a data source via config file (restart Grafana to apply)
cat /etc/grafana/provisioning/datasources/prometheus.yaml
# type: prometheus, url: http://prometheus:9090, access: proxy

# export a dashboard as JSON via API
curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
  http://localhost:3000/api/dashboards/uid/DASHBOARD_UID | jq .

# import a dashboard JSON via API
curl -s -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer $GRAFANA_TOKEN" \
  -d @dashboard.json http://localhost:3000/api/dashboards/db

# list all dashboards
curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
  http://localhost:3000/api/search?type=dash-db | jq '.[].title'

# test a data source connection via API
curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
  http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up
```

# Troubleshooting Guide

### Panel shows unexpected or missing data

1. Check the query in Explore: copy query, run in Explore with same time range. No data means metric does not exist or labels are wrong; data looks correct means problem is in panel config, skip to step 3.
2. Verify metric and labels: in Explore, type metric name, check autocomplete for available labels. Metric missing means target not scraped, check Prometheus targets page. Label mismatch means fix label selector in query.
3. Check transforms: disable transforms one by one to isolate the issue. Transform removes data means fix filter condition or field name.
4. Check variables: switch variable dropdown to a known-good value. Works with specific value means variable regex or query is wrong.
5. Check visualization settings: field mappings, unit, decimals, thresholds, axis range. Values exist but display wrong means fix override or unit config.
