# Grafana Alloy Overview

- Grafana Alloy is Grafana's OpenTelemetry-compatible telemetry collector -- the successor to the deprecated Grafana Agent
- It uses the same receiver/processor/exporter pipeline model as the OTel Collector but configured with **River syntax** (HCL-like) instead of YAML
- Supports all OTel protocols: receives OTLP (gRPC on 4317, HTTP on 4318), Prometheus scrape, syslog, filelog
- Exports to Prometheus (remote write), Loki (push API), Tempo (OTLP), and any OTel-compatible backend
- Key advantage over vanilla OTel Collector: tighter Grafana ecosystem integration (native Loki/Tempo/Mimir components), built-in web UI, and live config reloading

# Architecture

```text
+------------------+    +------------------+    +------------------+
|  Application A   |    |  Application B   |    |  Application C   |
| (OTel SDK/Auto)  |    | (OTel SDK/Auto)  |    | (OTel SDK/Auto)  |
+--------+---------+    +--------+---------+    +--------+---------+
         |                       |                       |
         |  OTLP (gRPC/HTTP)    |  OTLP                 |  OTLP
         v                       v                       v
+-----------------------------------------------------------------------+
|                         Grafana Alloy                                 |
|                                                                       |
|  +------------------+    +------------------+    +-----------------+  |
|  |    Receivers     | -> |   Processors     | -> |   Exporters     |  |
|  |                  |    |                  |    |                 |  |
|  | otelcol.receiver |    | otelcol.processor|    | otelcol.exporter|  |
|  |   .otlp          |    |   .batch         |    |   .prometheus   |  |
|  | prometheus.scrape|    |   .filter        |    |   .loki         |  |
|  | loki.source      |    |   .attributes    |    |   .otlp (Tempo) |  |
|  +------------------+    +------------------+    +-----------------+  |
|                                                                       |
|  Web UI :12345  -- component graph, pipeline status, config debug     |
+-----------------------------------------------------------------------+
         |                       |                        |
         v                       v                        v
  +------------+          +------------+           +------------+
  | Prometheus |          |    Loki    |           |   Tempo    |
  | (metrics)  |          |   (logs)   |           |  (traces)  |
  +------------+          +------------+           +------------+
```

```text
Alloy vs OTel Collector comparison:

                OTel Collector              Grafana Alloy
Config format:  YAML                        River (HCL-like)
Pipeline model: receivers -> processors     components wired together
                -> exporters                (source -> process -> export)
Debug UI:       metrics endpoint (8888)     full web UI (:12345)
Ecosystem:      vendor-neutral              Grafana-native components
Protocol:       OTLP + community receivers  OTLP + Grafana-specific
Reload:         restart required            live reload supported
```

# Mental Model

1. **Apps emit telemetry** -- applications instrumented with OTel SDK send metrics, logs, and traces over OTLP to Alloy
2. **Alloy receives via otelcol.receiver.otlp** -- listens on gRPC (4317) and HTTP (4318), accepts all three signal types
3. **Processor components transform data** -- `otelcol.processor.batch` groups telemetry for efficiency; additional processors filter, add attributes, or limit memory
4. **Exporter components route to backends** -- each signal type is wired to its backend: `otelcol.exporter.prometheus` for metrics, `otelcol.exporter.loki` for logs, `otelcol.exporter.otlp` for traces to Tempo
5. **Backends store and query** -- Prometheus stores metrics, Loki stores logs, Tempo stores traces; Grafana queries all three

Example Alloy configuration (River syntax):

```river
// -- Receive OTLP telemetry from apps --
otelcol.receiver.otlp "default" {
  grpc { endpoint = "0.0.0.0:4317" }
  http { endpoint = "0.0.0.0:4318" }
  output {
    metrics = [otelcol.processor.batch.default.input]
    logs    = [otelcol.processor.batch.default.input]
    traces  = [otelcol.processor.batch.default.input]
  }
}

// -- Batch telemetry for efficiency --
otelcol.processor.batch "default" {
  timeout = "5s"
  send_batch_size = 1024
  output {
    metrics = [otelcol.exporter.prometheus.default.input]
    logs    = [otelcol.exporter.loki.default.input]
    traces  = [otelcol.exporter.otlp.tempo.input]
  }
}

// -- Export metrics to Prometheus --
otelcol.exporter.prometheus "default" {
  forward_to = [prometheus.remote_write.default.receiver]
}
prometheus.remote_write "default" {
  endpoint {
    url = "http://prometheus:9090/api/v1/write"
  }
}

// -- Export logs to Loki --
otelcol.exporter.loki "default" {
  forward_to = [loki.write.default.receiver]
}
loki.write "default" {
  endpoint {
    url = "http://loki:3100/loki/api/v1/push"
  }
}

// -- Export traces to Tempo --
otelcol.exporter.otlp "tempo" {
  client {
    endpoint = "tempo:4317"
    tls { insecure = true }
  }
}
```

# Core Building Blocks

### River Syntax

- Alloy uses **River** -- an HCL-like configuration language that replaces the YAML used by vanilla OTel Collector
- Each component is declared as `component_type "label" { ... }` with nested blocks for settings
- Components are wired together by referencing outputs: `output { metrics = [next_component.label.input] }`
- River supports **live reload** -- config changes are applied without restarting the Alloy process, unlike the OTel Collector which requires a restart
- Comments use `//` (single-line) syntax
- Variables and expressions are supported: string interpolation, conditionals, and references to other component exports

Related notes: [../OpenTelemetry/001-opentelemetry-overview](../OpenTelemetry/001-opentelemetry-overview.md), [../Logging/002-loki](../Logging/002-loki.md), [../Tracing/001-tempo-overview](../Tracing/001-tempo-overview.md)

### Component Model

- Alloy's pipeline is built from **components** -- each component has a type, a label, inputs, and outputs
- **Receivers** -- ingest telemetry data:
  - `otelcol.receiver.otlp` -- accepts OTLP over gRPC (4317) and HTTP (4318)
  - `prometheus.scrape` -- scrapes Prometheus-format metrics from targets
  - `loki.source.file` / `loki.source.kubernetes` -- collects logs from files or K8s pods
- **Processors** -- transform data in-flight:
  - `otelcol.processor.batch` -- groups data for efficient export (configurable `timeout` and `send_batch_size`)
  - `otelcol.processor.filter` -- drops unwanted telemetry based on rules
  - `otelcol.processor.attributes` -- adds, removes, or modifies attributes/labels
  - `otelcol.processor.memory_limiter` -- applies backpressure to prevent OOM
- **Exporters** -- send data to backends:
  - `otelcol.exporter.prometheus` -- forwards metrics to `prometheus.remote_write`
  - `otelcol.exporter.loki` -- forwards logs to `loki.write`
  - `otelcol.exporter.otlp` -- sends traces (or any signal) to OTLP-compatible backends like Tempo
- **Grafana-native components** -- `prometheus.remote_write`, `loki.write`, `pyroscope.write` provide tight integration with the Grafana stack without going through generic OTel exporters

Related notes: [../OpenTelemetry/001-opentelemetry-overview](../OpenTelemetry/001-opentelemetry-overview.md), [../Logging/002-loki](../Logging/002-loki.md), [../Tracing/001-tempo-overview](../Tracing/001-tempo-overview.md)

### Web UI

- Alloy exposes a built-in **web UI** on port **12345** by default
- The UI shows a **component graph** -- a visual DAG of all configured components and how they are wired together
- Each component displays its **health status** (green = healthy, yellow = degraded, red = error) with detailed error messages on click
- **Pipeline status** shows throughput metrics: accepted, refused, and dropped counts per component
- **Config debugging** -- view the running configuration and identify misconfigured components without reading log files
- Access in Kubernetes via port-forward: `kubectl port-forward -n monitoring svc/alloy 12345:12345`
- Also exposes a Prometheus-compatible metrics endpoint for alerting on Alloy's own health

Related notes: [../OpenTelemetry/001-opentelemetry-overview](../OpenTelemetry/001-opentelemetry-overview.md), [../Logging/002-loki](../Logging/002-loki.md), [../Tracing/001-tempo-overview](../Tracing/001-tempo-overview.md)

### Kubernetes Deployment

- Deployed via Helm chart **`grafana/alloy`** from the Grafana Helm repository
- Default deployment mode is **DaemonSet** -- one Alloy instance per node collects telemetry from all pods on that node
- Apps send telemetry to Alloy's OTLP endpoint: `http://alloy.monitoring.svc.cluster.local:4317` (gRPC) or `:4318` (HTTP)
- Configure apps with environment variable: `OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.monitoring.svc.cluster.local:4317`
- The Helm chart exposes Alloy's web UI as a ClusterIP service on port 12345
- Alloy can also replace Promtail for log collection -- use `loki.source.kubernetes` to tail pod logs and forward to Loki
- For high-throughput clusters, scale with multiple replicas in Deployment mode behind a load balancer

Related notes: [../OpenTelemetry/001-opentelemetry-overview](../OpenTelemetry/001-opentelemetry-overview.md), [../Logging/002-loki](../Logging/002-loki.md), [../Tracing/001-tempo-overview](../Tracing/001-tempo-overview.md)

### Alloy vs OTel Collector

- Both implement the same pipeline concept (receive -> process -> export) but differ in configuration and ecosystem
- **Config format**: OTel Collector uses YAML with `service.pipelines` binding; Alloy uses River syntax with explicit component wiring
- **Debug tooling**: OTel Collector exposes a metrics endpoint on 8888; Alloy provides a full web UI on 12345 with component graph and health status
- **Ecosystem**: OTel Collector is vendor-neutral with community-contributed components; Alloy adds Grafana-native components (`prometheus.remote_write`, `loki.write`) for tighter stack integration
- **Config reload**: OTel Collector requires a restart for config changes; Alloy supports live reload
- **When to choose OTel Collector**: multi-vendor environments, need for vendor neutrality, established OTel ecosystem tooling
- **When to choose Alloy**: Grafana-based observability stack, want built-in debug UI, prefer HCL-style config over YAML

Related notes: [../OpenTelemetry/001-opentelemetry-overview](../OpenTelemetry/001-opentelemetry-overview.md), [../Logging/002-loki](../Logging/002-loki.md), [../Tracing/001-tempo-overview](../Tracing/001-tempo-overview.md)

# Troubleshooting Guide

### Alloy Not Receiving Data

1. Verify Alloy pod is running: `kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy`.
2. Check that receiver ports are exposed: `kubectl get svc -n monitoring` -- confirm ports 4317 (gRPC) and 4318 (HTTP) are listed.
3. Open Alloy web UI (`http://localhost:12345`) -- the component graph shows red/unhealthy components with error details.
4. Confirm the application's `OTEL_EXPORTER_OTLP_ENDPOINT` points to Alloy service DNS (e.g., `http://alloy.monitoring.svc.cluster.local:4317`).
5. Check Alloy logs for receiver errors: `kubectl logs -n monitoring -l app.kubernetes.io/name=alloy | grep -i error`.
6. Check accepted vs refused spans: `curl -s http://localhost:12345/metrics | grep otelcol_receiver` -- `refused` count > 0 indicates pipeline backpressure.

### Exporter Connection Failures

1. Check Alloy logs for exporter errors: look for `exporting failed` or `connection refused` messages.
2. Open Alloy web UI -- click the failing exporter component to see error details and last successful export time.
3. Verify the backend endpoint is reachable from Alloy pod: `kubectl exec -it <alloy-pod> -- wget -qO- http://loki:3100/ready`.
4. Confirm TLS settings match -- if the backend uses plain HTTP, set `tls { insecure = true }` in the exporter config.
5. Check for network policies blocking traffic between monitoring namespace and backend services.

### High Memory Usage / OOMKilled

1. Check if batch processor `send_batch_size` and `timeout` are too large -- reduce to limit in-flight data.
2. Review Alloy resource metrics: `curl -s http://localhost:12345/metrics | grep process_resident_memory_bytes`.
3. Look for high cardinality: `curl -s http://localhost:12345/metrics | grep otelcol_exporter_sent` -- unexpected volume indicates cardinality explosion.
4. Check Alloy component health in web UI -- components showing yellow/red may be buffering too much data.
5. Increase pod memory limits or scale Alloy replicas if throughput demands exceed single-instance capacity.
