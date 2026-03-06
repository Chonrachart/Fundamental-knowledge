overview of

    observability
    metrics
    logs
    traces
    monitoring
    alerting

---

# Observability

- Ability to understand system state from outputs: metrics, logs, traces.
- Enables debugging and reasoning about behavior in production.

# Metrics

- Numeric values over time (CPU, request rate, error rate).
- Aggregated; good for dashboards and alerting.

# Logs

- Event records; structured or plain text; search and filter for debugging.

# Traces

- Request flow across services; trace ID links spans; used in distributed systems.

# Monitoring and Alerting

- **Monitoring**: Collect and visualize metrics/logs; dashboards.
- **Alerting**: Notify when thresholds or conditions are breached (e.g. PagerDuty, Slack).

# Three Pillars

- **Metrics**: Time-series numbers; scrape or push; store in Prometheus, InfluxDB, etc.
- **Logs**: Events; aggregate and search (e.g. Loki, Elasticsearch).
- **Traces**: Request path across services; OpenTelemetry, Jaeger; correlate with logs/metrics.

# SLO and SLI

- **SLI**: Service Level Indicator — measurable (e.g. error rate, latency p99).
- **SLO**: Service Level Objective — target (e.g. 99.9% availability).
- **SLA**: Contract with user; SLO is internal target; alert when SLO at risk.

# Topic Map (basic → advanced)

- [Grafana/001-grafana-overview](./Grafana/001-grafana-overview.md) — Dashboard, data source, panel, alert (start here)
- [Grafana/002-dashboards-queries](./Grafana/002-dashboards-queries.md) — Panels, PromQL, variables
- [Grafana/003-alerting](./Grafana/003-alerting.md) — Alert rule, contact point, notification
- [Grafana/004-promql-deep-dive](./Grafana/004-promql-deep-dive.md) — PromQL, rate, aggregation, histogram
- [Zabbix/001-zabbix-overview](./Zabbix/001-zabbix-overview.md) — Host, item, trigger, action
- [Zabbix/002-items-triggers](./Zabbix/002-items-triggers.md) — Item types, key, trigger expression
- [Zabbix/003-actions-templates](./Zabbix/003-actions-templates.md) — Action, escalation, templates
- [Zabbix/004-monitoring-patterns](./Zabbix/004-monitoring-patterns.md) — Agent/agentless, LLD, dependent items
