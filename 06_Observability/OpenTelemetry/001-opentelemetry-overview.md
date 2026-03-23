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

Related notes: [Prometheus overview](../Prometheus/001-prometheus-overview.md), [Loki and Promtail](../Logging/002-loki-and-promtail.md)

### OTel Collector

- **Receivers** -- ingest data: `otlp` (native), `prometheus` (scrape targets), `syslog`, `filelog`, `hostmetrics`
- **Processors** -- transform in-flight: `batch` (group for efficiency), `filter` (drop unwanted), `attributes` (add/remove labels), `memory_limiter` (backpressure)
- **Exporters** -- send to backends: `prometheusremotewrite`, `loki`, `otlp` (for Tempo/Jaeger), `debug` (stdout for testing)
- The collector runs as a standalone binary (`otelcol`) or as a Kubernetes pod; use `otelcol-contrib` for the full set of community components
- Pipeline definition lives in `service.pipelines` -- each pipeline binds receivers, processors, and exporters for one signal type

Related notes: [Prometheus overview](../Prometheus/001-prometheus-overview.md), [Tempo overview](../Tracing/001-tempo-overview.md)

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

Related notes: [Prometheus overview](../Prometheus/001-prometheus-overview.md), [Loki and Promtail](../Logging/002-loki-and-promtail.md), [Tempo overview](../Tempo/001-tempo-overview.md)

### Deployment Patterns

- **Sidecar** -- collector runs as a sidecar container alongside each app pod; gives per-pod isolation but higher resource overhead
- **DaemonSet** -- one collector per node; good balance of isolation and efficiency for most Kubernetes clusters
- **Gateway** -- centralized collector deployment (Deployment + Service); all telemetry funnels through it for aggregation and routing
- Common pattern: DaemonSet collectors forward to a Gateway collector for cross-cluster export and advanced processing
- Start with DaemonSet for simplicity; add Gateway when you need centralized processing or multi-cluster aggregation

Related notes: [../000-core](../000-core.md)

### Kubernetes Integration

- **OTel Operator** -- Kubernetes operator that manages collector deployments and auto-instrumentation injection via CRDs
- Auto-instrumentation injection adds the SDK agent to pods via annotation: `instrumentation.opentelemetry.io/inject-python: "true"`
- The operator creates an `Instrumentation` CR that defines which languages to instrument and where to send telemetry
- Collector deployed as DaemonSet receives telemetry from all pods on the node via OTLP
- Helm chart: `open-telemetry/opentelemetry-collector` for the collector, `open-telemetry/opentelemetry-operator` for the operator

Related notes: [../000-core](../000-core.md)

# Practical Command Set (Core)

```bash
# -- Deploy OTel Collector via Helm --
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace observability --create-namespace \
  -f otel-collector-values.yaml

# -- Deploy OTel Operator --
helm install otel-operator open-telemetry/opentelemetry-operator \
  --namespace observability --set admissionWebhooks.certManager.enabled=false

# -- Check collector pod status --
kubectl get pods -n observability -l app.kubernetes.io/name=opentelemetry-collector

# -- View collector logs --
kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector --tail=50

# -- Test OTLP gRPC endpoint with grpcurl --
grpcurl -plaintext localhost:4317 list

# -- Test OTLP HTTP endpoint --
curl -v http://localhost:4318/v1/traces -H "Content-Type: application/json" -d '{"resourceSpans":[]}'

# -- View collector internal metrics (self-monitoring) --
curl -s http://localhost:8888/metrics | head -30

# -- Port-forward collector for local testing --
kubectl port-forward -n observability svc/otel-collector-opentelemetry-collector 4317:4317 4318:4318

# -- Check OTel Operator CRDs --
kubectl get crd | grep opentelemetry

# -- List auto-instrumentation configs --
kubectl get instrumentation -A
```

# Troubleshooting Guide

### Collector Not Receiving Data

1. Verify the collector pod is running: `kubectl get pods -n observability -l app.kubernetes.io/name=opentelemetry-collector`
2. Check that receiver ports are exposed: `kubectl get svc -n observability` -- confirm ports 4317 (gRPC) and 4318 (HTTP) are listed
3. Confirm the application's `OTEL_EXPORTER_OTLP_ENDPOINT` points to the correct collector service DNS (e.g., `http://otel-collector.observability.svc.cluster.local:4317`)
4. Check collector logs for receiver errors: `kubectl logs -n observability -l app.kubernetes.io/name=opentelemetry-collector | grep -i error`
5. Test connectivity from the app pod: `kubectl exec -it <app-pod> -- curl -v http://otel-collector.observability:4318/v1/traces`

### Exporter Connection Failures

1. Check collector logs for exporter errors: look for `exporting failed` or `connection refused` messages
2. Verify the backend endpoint is reachable from the collector: `kubectl exec -it <collector-pod> -- wget -qO- http://prometheus:9090/-/healthy`
3. Confirm TLS settings match -- if the backend uses plain HTTP, set `tls.insecure: true` in the exporter config
4. Check for network policies blocking traffic between the collector namespace and the backend namespace
5. Validate exporter config syntax: run `otelcol validate --config=/etc/otelcol/config.yaml` inside the collector pod

### High Memory Usage / OOMKilled

1. Check if `memory_limiter` processor is configured -- it must be the first processor in every pipeline
2. Review `memory_limiter` settings: `limit_mib` should be ~80% of the pod's memory limit (e.g., 400 MiB limit for 512 MiB pod)
3. Check batch processor settings: reduce `send_batch_size` or `timeout` if batches grow too large
4. Look for high cardinality metrics: `curl -s http://localhost:8888/metrics | grep otelcol_exporter_sent` -- unexpected volume indicates cardinality explosion
5. Scale horizontally (add replicas for Gateway pattern) or switch from Gateway to DaemonSet to distribute load across nodes
