# OpenTelemetry Overview

- OpenTelemetry (OTel) is a vendor-neutral observability framework that provides APIs, SDKs, and tooling to generate, collect, and export telemetry data (metrics, logs, traces)
- It acts as the glue layer between instrumented applications and observability backends -- you instrument once, then route to any supported backend
- It is a CNCF project and the industry standard for telemetry collection, replacing fragmented vendor-specific agents with a single unified pipeline

# Architecture

```text
+---------------------+     +---------------------+     +---------------------+
|   Application A     |     |   Application B     |     |   Application C     |
|  (OTel SDK / Auto)  |     |  (OTel SDK / Auto)  |     |  (OTel SDK / Auto)  |
+--------+------------+     +--------+------------+     +--------+------------+
         |                           |                           |
         |  OTLP (gRPC/HTTP)        |  OTLP                    |  OTLP
         v                           v                           v
+------------------------------------------------------------------------+
|                        OTel Collector                                   |
|                                                                        |
|  +--------------+     +-----------------+     +-------------------+    |
|  |  Receivers   | --> |   Processors    | --> |    Exporters      |    |
|  |              |     |                 |     |                   |    |
|  | - otlp       |     | - batch         |     | - prometheusremote|   |
|  | - prometheus  |     | - filter        |     |   write           |    |
|  | - syslog     |     | - attributes    |     | - loki            |    |
|  | - filelog    |     | - memory_limiter|     | - otlp (to Tempo) |    |
|  +--------------+     +-----------------+     +-------------------+    |
+------------------------------------------------------------------------+
         |                       |                        |
         v                       v                        v
  +------------+          +------------+           +------------+
  | Prometheus |          |    Loki    |           |   Tempo    |
  | (metrics)  |          |   (logs)   |           |  (traces)  |
  +------------+          +------------+           +------------+
```

# Mental Model

1. **Instrument the app** -- add OTel SDK to your application code, or enable auto-instrumentation (zero-code agent injection)
2. **SDK generates telemetry** -- the SDK produces metrics, logs, and traces in OpenTelemetry-native format
3. **Collector receives via OTLP** -- telemetry is pushed to the OTel Collector over OTLP (gRPC on port 4317, HTTP on port 4318)
4. **Collector processes** -- data passes through a pipeline: batch for efficiency, filter to drop noise, memory_limiter to prevent OOM
5. **Collector exports to backends** -- each signal is routed to the appropriate backend (metrics to Prometheus, logs to Loki, traces to Tempo)

Example collector configuration:

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 5s
    send_batch_size: 1024
  memory_limiter:
    limit_mib: 512
    check_interval: 5s

exporters:
  prometheusremotewrite:
    endpoint: http://prometheus:9090/api/v1/write
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
  otlp/tempo:
    endpoint: http://tempo:4317
    tls:
      insecure: true

service:
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheusremotewrite]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [loki]
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp/tempo]
```

# Core Building Blocks

### What OpenTelemetry Solves

- Provides a single vendor-neutral standard for all telemetry -- no more Datadog agent + Prometheus exporter + Jaeger client
- One SDK instruments metrics, logs, and traces; swap backends without changing application code
- Decouples telemetry generation from telemetry storage -- the collector handles routing and transformation
- Eliminates vendor lock-in; OTLP is the universal wire protocol

Related notes: [Prometheus overview](../Prometheus/001-prometheus-overview.md), [Loki](../Logging/002-loki.md)

### OTel Collector

- **Receivers** -- ingest data: `otlp` (native), `prometheus` (scrape targets), `syslog`, `filelog`, `hostmetrics`
- **Processors** -- transform in-flight: `batch` (group for efficiency), `filter` (drop unwanted), `attributes` (add/remove labels), `memory_limiter` (backpressure)
- **Exporters** -- send to backends: `prometheusremotewrite`, `loki`, `otlp` (for Tempo/Jaeger), `debug` (stdout for testing)
- The collector runs as a standalone binary (`otelcol`) or as a Kubernetes pod; use `otelcol-contrib` for the full set of community components
- Pipeline definition lives in `service.pipelines` -- each pipeline binds receivers, processors, and exporters for one signal type

Related notes: [Prometheus overview](../Prometheus/001-prometheus-overview.md), [Tempo overview](../Tracing/001-tempo-overview.md), [Alloy overview](../Alloy/001-alloy-overview.md)

### Instrumentation

- **SDK instrumentation** -- manually add spans and metrics in code using OTel API (e.g., `opentelemetry-api` for Python, `@opentelemetry/api` for Node.js)
- **Auto-instrumentation** -- zero-code agents that hook into frameworks automatically (Java agent JAR, Python `opentelemetry-instrument`, .NET agent)
- Supported languages: Java, Python, Go, JavaScript/Node.js, .NET, Rust, C++, PHP, Ruby, Swift
- All instrumentation emits data over **OTLP** (OpenTelemetry Protocol) -- gRPC or HTTP/protobuf
- Environment variables configure the SDK: `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, `OTEL_RESOURCE_ATTRIBUTES`

Related notes: [../000-core](../000-core.md)

### Signals

- **Metrics** -- counters, gauges, histograms; exported to Prometheus or any metrics backend
- **Logs** -- structured log records with trace context correlation; exported to Loki or similar
- **Traces** -- distributed traces composed of spans with parent-child relationships; exported to Tempo or Jaeger
- Each signal type has its own pipeline in the collector, allowing independent processing and routing
- Trace context propagation (W3C TraceContext headers) links logs and metrics to their originating trace

Related notes: [Prometheus overview](../Prometheus/001-prometheus-overview.md), [Loki](../Logging/002-loki.md), [Tempo overview](../Tracing/001-tempo-overview.md)

### Deployment Patterns

- **Sidecar** -- collector runs as a sidecar container alongside each app pod; gives per-pod isolation but higher resource overhead
- **DaemonSet** -- one collector per node; good balance of isolation and efficiency for most Kubernetes clusters
- **Gateway** -- centralized collector deployment (Deployment + Service); all telemetry funnels through it for aggregation and routing
- Common pattern: DaemonSet collectors forward to a Gateway collector for cross-cluster export and advanced processing
- Start with DaemonSet for simplicity; add Gateway when you need centralized processing or multi-cluster aggregation

Related notes: [../000-core](../000-core.md), [Alloy overview](../Alloy/001-alloy-overview.md)

### Kubernetes Integration

- **OTel Operator** -- Kubernetes operator that manages collector deployments and auto-instrumentation injection via CRDs
- Auto-instrumentation injection adds the SDK agent to pods via annotation: `instrumentation.opentelemetry.io/inject-python: "true"`
- The operator creates an `Instrumentation` CR that defines which languages to instrument and where to send telemetry
- Collector deployed as DaemonSet receives telemetry from all pods on the node via OTLP
- For Grafana Alloy as an OTel-compatible collector in K8s, see [../Alloy/001-alloy-overview](../Alloy/001-alloy-overview.md)

Related notes: [../000-core](../000-core.md)
