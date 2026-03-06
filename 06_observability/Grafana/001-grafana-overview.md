Grafana
dashboard
data source
panel
alert

---

# Grafana

- Open-source platform for visualization and alerting.
- Connects to many data sources (Prometheus, InfluxDB, Loki, Elasticsearch, etc.); build dashboards and alerts.

# Dashboard

- Collection of panels; each panel shows a query result (graph, table, gauge, etc.).
- Variables for dropdowns; time range; share and organize by folder.

# Data Source

- Connection to a backend (Prometheus, InfluxDB, Loki, CloudWatch, etc.).
- Configure URL and auth; test connection in UI.

# Panel

- Single visualization: time series, stat, table, bar gauge, etc.
- Query in data source language (e.g. PromQL for Prometheus); transform and format.

# Alert

- Rule based on panel query; threshold or condition; contact point (email, Slack, PagerDuty).
- Alert state: OK, Pending, Alerting, No Data.

# Key Concepts

- **Explore**: Ad-hoc query without saving to dashboard.
- **Annotations**: Mark events on graphs (deploys, incidents).
- **Plugins**: Data sources and panels; install from catalog.
