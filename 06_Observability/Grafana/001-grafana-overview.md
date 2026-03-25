# Grafana Overview

- Grafana is an open-source platform for visualization, monitoring, and alerting across multiple data sources.
- It connects to backends (Prometheus, InfluxDB, Loki, Elasticsearch, CloudWatch) and renders unified dashboards in the browser.
- Core workflow: add data source, build dashboards with panels, configure alert rules and contact points.

# Architecture

```text
+----------------+   +----------------+   +----------------+
|  Prometheus    |   |  InfluxDB      |   |  Loki          |
|  (metrics)     |   |  (metrics/ts)  |   |  (logs)        |
+-------+--------+   +-------+--------+   +-------+--------+
        |                     |                     |
        +----------+----------+----------+----------+
                   |                     |
                   v                     v
          +--------+---------------------+--------+
          |           Grafana Server               |
          |                                        |
          |  +-------------+  +----------------+   |
          |  | Query Engine|  | Alerting Engine |   |
          |  +------+------+  +-------+--------+   |
          |         |                 |             |
          |  +------v-----------------v--------+   |
          |  |  Dashboard / Panel Renderer     |   |
          |  +---------------------------------+   |
          |                                        |
          |  +----------------------------------+  |
          |  | Plugin System (data src + panel) |  |
          |  +----------------------------------+  |
          +-------------------+--------------------+
                              |
                              v
                   +----------+----------+
                   |   Browser UI        |
                   |  (dashboards,       |
                   |   explore, alerts)  |
                   +---------------------+
```

# Mental Model

```text
Grafana workflow:

  [1] Add data source     -->  configure URL + auth, test connection
  [2] Create dashboard    -->  new dashboard in a folder
  [3] Add panels          -->  choose visualization, write query (PromQL/LogQL/Flux)
  [4] Set variables       -->  dropdowns for host, env, job
  [5] Configure alerts    -->  threshold on query, assign contact point
  [6] Share / organize    -->  folders, permissions, snapshots
```

```text
Example: monitor API error rate

  Data source:  Prometheus at http://prometheus:9090
  Dashboard:    "API Health"
  Panel query:  sum(rate(http_requests_total{code=~"5.."}[5m]))
                / sum(rate(http_requests_total[5m]))
  Alert rule:   fire when error ratio > 0.05 for 5m
  Contact:      Slack channel #alerts
```

# Core Building Blocks

### Data Source

- Connection to a backend system (Prometheus, InfluxDB, Loki, Elasticsearch, CloudWatch, etc.).
- Configure URL, authentication (basic, token, TLS), and scrape interval.
- Test connection from the UI before building dashboards.
- Each panel query targets a specific data source.
- Grafana is a visualization and alerting platform; it does not store metrics itself.
- Data sources provide the backend connection; Prometheus, Loki, and InfluxDB are the most common.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md), [../000-core](../000-core.md)

### Dashboard

- Collection of panels arranged in a grid layout.
- Supports variables (dropdowns), time range picker, and auto-refresh.
- Organize dashboards into folders with role-based permissions.
- Share via link, snapshot, or export as JSON.
- Dashboards contain panels; each panel runs queries against a data source.
- Dashboard JSON model can be exported, version-controlled, and provisioned via config files.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md)

### Panel

- Single visualization unit inside a dashboard.
- Types: time series, stat, gauge, table, bar chart, histogram, logs.
- Each panel has one or more queries written in the data source language (PromQL, LogQL, Flux).
- Supports transforms (rename, merge, filter) and overrides for formatting.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md), [../Prometheus/001-prometheus-overview](../Prometheus/001-prometheus-overview.md)

### Alerting

- Alert rule evaluates a query condition at a defined interval.
- Alert states: OK, Pending, Alerting, No Data, Error.
- Contact points: email, Slack, PagerDuty, webhook, OpsGenie.
- Notification policies route alerts to contact points based on labels.
- Silences suppress alerts during maintenance windows.
- Alert rules evaluate query conditions and route notifications through contact points.

Related notes: [003-alerting](./003-alerting.md), [../Zabbix/001-zabbix-overview](../Zabbix/001-zabbix-overview.md)

### Explore

- Ad-hoc query interface without saving to a dashboard.
- Split view to compare metrics and logs side by side.
- Useful for debugging and investigation before building permanent panels.
- Explore mode is for ad-hoc queries without creating a dashboard.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md)

### Annotations

- Mark events on time series graphs (deploys, incidents, config changes).
- Can be manual or query-driven (e.g. pull deployment events from a data source).
- Help correlate metric changes with real-world events.
- Annotations mark events on graphs to correlate with metric changes.

Related notes: [002-dashboards-queries](./002-dashboards-queries.md)

### Plugins

- Extend Grafana with additional data sources and panel types.
- Install from the official plugin catalog or side-load manually.
- Categories: data source plugins, panel plugins, app plugins.
- Plugins extend data sources and panel types; installed from the catalog.

Related notes: [001-grafana-overview](./001-grafana-overview.md)

---

# Troubleshooting Guide

### Grafana dashboard shows "No Data"

1. Is the data source configured and reachable? Settings > Data Sources > Test. Test fails means check URL, auth, network/firewall.
2. Does the query return data in Explore? Copy panel query into Explore, run it. No results means wrong metric name, label filter, or time range.
3. Is the time range correct? Check dashboard time picker (top right). Too narrow or future means adjust range to match data retention.
4. Panel configuration issue: check visualization type, field mappings, and transform steps. Wrong field selected means fix field override or transform.
5. Check Grafana server logs: `journalctl -u grafana-server -f` or `docker logs grafana`.
