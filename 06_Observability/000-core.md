# Observability

# Overview
- **Why it exists** —
- **What it is** —
- **One-liner** —

# Architecture

# Core Building Blocks

### Stack Overview

### How the Stack Connects

### Data Types and Query Languages

### Correlation: The Real Power

### Suggested Learning and Deployment Order

### Three Pillars (Metrics, Logs, Traces)

### Metrics

### Logs

### Traces

### SLI / SLO / SLA

### Monitoring and Alerting

### Grafana

### Zabbix

# Topic Map



- [Prometheus/001-prometheus-overview](./Prometheus/001-prometheus-overview.md) — TSDB, scrape config, targets, service discovery, federation, PromQL
- [Prometheus/002-exporters-and-instrumentation](./Prometheus/002-exporters-and-instrumentation.md) — Node exporter, application instrumentation, custom exporters, Pushgateway
- [Prometheus/003-alertmanager](./Prometheus/003-alertmanager.md) — Alert routing, grouping, inhibition, silences, receivers
- [Logging/001-logging-overview](./Logging/001-logging-overview.md) — Structured vs unstructured logs, log levels, log aggregation pipeline
- [Logging/002-loki](./Logging/002-loki.md) — Loki architecture, label-based indexing, LogQL, retention, Loki vs ELK
- [Logging/003-logql-deep-dive](./Logging/003-logql-deep-dive.md) — LogQL pipeline stages, label filters, metric queries from logs
- [Tracing/001-tempo-overview](./Tracing/001-tempo-overview.md) — Tempo architecture, trace storage, span discovery, Grafana integration
- [Tracing/002-traceql-deep-dive](./Tracing/002-traceql-deep-dive.md) — TraceQL structural queries, span filtering, resource/span attributes
- [OpenTelemetry/001-opentelemetry-overview](./OpenTelemetry/001-opentelemetry-overview.md) — OTel standard, OTLP, SDK, auto-instrumentation, collector concepts
- [Alloy/001-alloy-overview](./Alloy/001-alloy-overview.md) — Grafana Alloy collector, River syntax, component model, K8s deployment
- [Kafka/001-kafka-overview](./Kafka/001-kafka-overview.md) — Kafka in observability, broker/topic/partition, telemetry buffering
- [Grafana/001-grafana-overview](./Grafana/001-grafana-overview.md) — Dashboard, data source, panel, alert
- [Grafana/002-dashboards-queries](./Grafana/002-dashboards-queries.md) — Panels, queries, variables, transforms
- [Grafana/003-alerting](./Grafana/003-alerting.md) — Grafana alert rule, contact point, notification policy
- [Zabbix/001-zabbix-overview](./Zabbix/001-zabbix-overview.md) — Host, item, trigger, action
- [Zabbix/002-items-triggers](./Zabbix/002-items-triggers.md) — Item types, key, trigger expression
- [Zabbix/003-actions-templates](./Zabbix/003-actions-templates.md) — Action, escalation, templates, LLD
- [Zabbix/004-monitoring-patterns](./Zabbix/004-monitoring-patterns.md) — Agent/agentless, dependent items, preprocessing
