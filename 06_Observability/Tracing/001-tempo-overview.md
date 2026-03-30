# Tempo Overview

- Grafana Tempo is an open-source, high-scale distributed tracing backend that stores traces in object storage (S3, GCS, Azure Blob) with no indexing required.
- Traces are ingested via OpenTelemetry (OTLP), Jaeger, or Zipkin protocols; Tempo stores them as-is and retrieves by trace ID -- no sampling decisions at the backend.
- Key property: Tempo is cost-efficient because it only requires object storage (no Elasticsearch, no Cassandra); trade-off is that trace discovery relies on trace ID lookup, service graphs, or span metrics rather than full-text search.

# Architecture

```text
+-------------------+    +-------------------+    +-------------------+
|  App + OTel SDK   |    |  App + OTel SDK   |    |  App + Auto-Instr |
|  (OTLP exporter)  |    |  (Jaeger export)  |    |  (Zipkin export)  |
+--------+----------+    +--------+----------+    +--------+----------+
         |                        |                        |
         +------------------------+------------------------+
                                  |
                                  v
                      +-----------+-----------+
                      |     Distributor       |
                      | (receives spans,      |
                      |  hashes trace ID,     |
                      |  routes to ingester)  |
                      +-----------+-----------+
                                  |
                                  v
                      +-----------+-----------+
                      |      Ingester         |
                      | (batches spans in WAL,|
                      |  builds trace blocks) |
                      +-----------+-----------+
                                  |
                                  v
                      +-----------+-----------+
                      |     Compactor         |
                      | (merges small blocks, |
                      |  deduplicates,        |
                      |  builds bloom filters)|
                      +-----------+-----------+
                                  |
                                  v
                      +-----------+-----------+
                      |   Object Storage      |
                      |  (S3 / GCS / Azure /  |
                      |   local filesystem)   |
                      +-----------+-----------+
                                  ^
                                  |
                      +-----------+-----------+
                      |   Query Frontend      |
                      | (splits search jobs,  |
                      |  caches results,      |
                      |  serves Grafana)      |
                      +-----------------------+
```

# Mental Model

```text
Trace lifecycle in Tempo:

  [1] Application code creates spans via OpenTelemetry SDK
      |
      v
  [2] OTel collector/agent batches and exports spans via OTLP to Tempo
      |
      v
  [3] Distributor receives spans, hashes trace ID, routes to correct ingester
      |
      v
  [4] Ingester writes spans to WAL, assembles complete traces in memory
      |
      v
  [5] Ingester flushes trace blocks to object storage (S3/GCS)
      |
      v
  [6] Compactor merges small blocks into larger ones, builds bloom filters
      |
      v
  [7] Query frontend receives trace ID query from Grafana, searches storage
      |
      v
  [8] Grafana renders the trace waterfall with spans, durations, and tags
```

```bash
# concrete example: send a test trace via curl using OTLP HTTP
# Tempo default OTLP HTTP port: 4318
curl -X POST http://tempo.local:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "demo-svc"}}]},
      "scopeSpans": [{
        "spans": [{
          "traceId": "5b8aa5a2d2c872e8321cf37308d69df2",
          "spanId": "051581bf3cb55c13",
          "name": "GET /api/health",
          "kind": 2,
          "startTimeUnixNano": "1700000000000000000",
          "endTimeUnixNano":   "1700000000050000000",
          "attributes": [{"key": "http.method", "value": {"stringValue": "GET"}}]
        }]
      }]
    }]
  }'

# then query that trace by ID
curl -s http://tempo.local:3200/api/traces/5b8aa5a2d2c872e8321cf37308d69df2 | jq .
```

# Core Building Blocks

### What Is a Trace

- A trace represents the full journey of a request across services; composed of one or more spans linked by a shared trace ID.
- Each span has: trace ID, span ID, parent span ID, operation name, start/end time, attributes (tags), and status.
- Parent-child relationships form a DAG (directed acyclic graph); the root span has no parent.
- Context propagation passes trace ID across service boundaries via HTTP headers (`traceparent`, `b3`) or gRPC metadata.
- W3C Trace Context (`traceparent` header) is the standard; B3 headers are Zipkin-compatible legacy format.

Related notes: [../000-core](../000-core.md)

### Tempo Architecture

- **Distributor**: receives incoming spans (OTLP, Jaeger, Zipkin), validates, hashes trace ID to select target ingester.
- **Ingester**: buffers spans in a Write-Ahead Log (WAL), assembles traces, flushes completed blocks to object storage.
- **Compactor**: runs periodically to merge small blocks, deduplicate spans, and generate bloom filters for faster lookup.
- **Query Frontend**: splits search queries into sub-jobs, caches results, serves the Tempo API (port 3200 by default).
- **Storage Backend**: object storage (S3, GCS, Azure Blob, MinIO) holds all trace data; no additional database needed.

Related notes: [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md)

### Trace Discovery

- Primary lookup: query by exact trace ID via API or Grafana Explore (`GET /api/traces/<traceID>`).
- TraceQL: Tempo's query language for searching spans by attributes (e.g. `{ span.http.status_code = 500 }`).
- Service graph: auto-generated topology map from span data showing service-to-service dependencies and error rates.
- Span metrics: Tempo generates RED metrics (Rate, Errors, Duration) from spans; stored in Prometheus/Mimir for alerting.
- Exemplars: Prometheus metrics link to specific trace IDs, enabling metric-to-trace correlation.

Related notes: [../Grafana/002-dashboards-queries](../Grafana/002-dashboards-queries.md), [002-traceql-deep-dive](./002-traceql-deep-dive.md)

### Instrumentation

- OpenTelemetry SDK is the standard instrumentation library; available for Go, Java, Python, Node.js, .NET, and more.
- Auto-instrumentation injects tracing without code changes (Java agent, Python `opentelemetry-instrument`, Node.js `--require`).
- OTLP (OpenTelemetry Protocol) is the preferred export format; supports gRPC (port 4317) and HTTP (port 4318).
- OTel Collector sits between apps and Tempo: batches, retries, samples, and routes telemetry data.
- Set `OTEL_EXPORTER_OTLP_ENDPOINT` and `OTEL_SERVICE_NAME` environment variables to configure SDK exporters.

Related notes: [../Prometheus/002-exporters-and-instrumentation](../Prometheus/002-exporters-and-instrumentation.md)

### Grafana Integration

- Add Tempo as a data source in Grafana (type: Tempo, URL: `http://tempo:3200`).
- Trace-to-logs: link from a trace span directly to the corresponding log lines in Loki (correlated by trace ID label).
- Trace-to-metrics: link from a trace to related Prometheus/Mimir metrics dashboards filtered by service name.
- Logs-to-traces: Loki derived fields can parse trace IDs from log lines and create clickable links to Tempo.
- Node graph panel visualizes the service graph generated from Tempo span data.

Related notes: [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md), [../Logging/002-loki](../Logging/002-loki.md)

### Deployment on Kubernetes

- Helm chart: `grafana/tempo` (monolithic) or `grafana/tempo-distributed` (microservices mode).
- Monolithic mode: single binary, suitable for small-to-medium workloads; all components in one process.
- Microservices mode: each component (distributor, ingester, compactor, querier) runs as a separate Deployment/StatefulSet; scales independently.
- Storage config: point `storage.trace.backend` to `s3`, `gcs`, or `azure` with bucket credentials via Secret.
- Resource baseline: monolithic mode starts at ~512Mi memory, 0.5 CPU; scale ingesters for higher throughput.

Related notes: [../Grafana/001-grafana-overview](../Grafana/001-grafana-overview.md)
