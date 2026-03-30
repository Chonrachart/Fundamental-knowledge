# Kafka in Observability

- Apache Kafka is a distributed event-streaming platform that acts as a high-throughput, durable buffer between telemetry producers and storage backends
- In observability stacks, Kafka sits between collectors/agents and backends (Loki, Tempo, Mimir), decoupling ingestion from processing
- Key property: Kafka retains data on disk with configurable retention, allowing consumers to read at their own pace and replay historical telemetry

# Architecture

```text
 PRODUCERS                    KAFKA CLUSTER                    CONSUMERS
 ─────────                    ─────────────                    ─────────
                          ┌─────────────────────┐
 App (OTel SDK) ──┐       │  Broker 0            │
                  │       │  ┌───────────────┐   │       ┌──> Loki (logs)
 Fluentbit    ────┼──────>│  │ logs-topic     │   │───────┤
                  │       │  │  P0 | P1 | P2  │   │       ├──> Tempo (traces)
 OTel Collector ──┘       │  ├───────────────┤   │       │
                          │  │ traces-topic   │   │───────┤
 Prometheus       ───────>│  │  P0 | P1       │   │       ├──> Mimir (metrics)
 (remote write)           │  ├───────────────┤   │       │
                          │  │ metrics-topic  │   │───────┘
                          │  │  P0 | P1 | P2  │   │
                          │  └───────────────┘   │
                          │  Broker 1, Broker 2   │
                          └─────────────────────┘

 P0, P1, P2 = partitions (parallelism units)
 Each topic is replicated across brokers for durability
```

# Mental Model

Step-by-step flow for a single log line:

1. Application emits a structured log via its OTel SDK
2. OTel Collector receives the log, batches it, and produces it to Kafka topic `logs-raw`
3. Kafka stores the message in a partition of `logs-raw`, replicates across brokers
4. A consumer (Loki's ingester, or a second OTel Collector) reads from `logs-raw` at its own pace
5. The consumer writes the log into Loki's storage
6. Grafana queries Loki and displays the log

Concrete example: A spike of 50k logs/sec hits during a deployment. Without Kafka, Loki's ingester gets overwhelmed and drops logs. With Kafka, the burst is absorbed into the topic. Loki catches up in seconds once the spike passes. Zero data loss.

# Core Building Blocks

### Why Kafka in Observability

- **Buffer spikes** -- absorbs sudden bursts of telemetry without back-pressuring applications or overloading backends
- **Decouple producers and consumers** -- collectors and backends evolve independently; backend downtime does not affect collection
- **Replay** -- reprocess historical telemetry by resetting consumer offsets (useful when fixing a broken pipeline or adding a new backend)
- **Fan-out** -- one topic can feed multiple consumers simultaneously (send logs to both Loki and a SIEM)

Related notes: [OpenTelemetry overview](../OpenTelemetry/001-opentelemetry-overview.md), [Loki](../Logging/002-loki.md)

### Core Concepts

- **Broker** -- a single Kafka server process; a cluster runs 3+ brokers for fault tolerance
- **Topic** -- a named stream of records (think: a category like `logs-raw` or `traces-ingest`)
- **Partition** -- a topic is split into partitions for parallelism; each partition is an ordered, append-only log
- **Producer** -- a client that writes records to a topic (e.g., OTel Collector with Kafka exporter)
- **Consumer / Consumer Group** -- a client that reads records; consumers in the same group split partition ownership for parallel processing

Related notes: [../000-core](../000-core.md)

### Topics for Telemetry

- Use separate topics per signal type: `logs-raw`, `traces-raw`, `metrics-raw` -- different retention, throughput, and consumer needs
- Partition by service name or trace ID to keep related data together and enable ordered processing
- Set retention based on your buffer needs, not long-term storage (e.g., 2-6 hours is common for observability pipelines)
- Replication factor of 3 is standard; ensures no data loss if a broker dies

Related notes: [Loki](../Logging/002-loki.md), [Tempo overview](../Tracing/001-tempo-overview.md)

### When You Need Kafka

- Ingestion rate exceeds ~100k events/sec sustained -- direct push to backends becomes unreliable
- Multiple consumers need the same telemetry stream (Loki + SIEM, or Tempo + custom analytics)
- You need replay capability -- reprocess data after a backend bug or config change
- Producers and consumers must be fully decoupled (different teams, different release cycles)

Related notes: [../000-core](../000-core.md)

### When You Do NOT Need Kafka

- Homelab or small clusters with <10k events/sec -- OTel Collector can push directly to Loki/Tempo
- Added operational complexity: Kafka itself needs monitoring, disk, memory, and tuning
- If you have a single consumer per signal, direct ingestion with OTel Collector batching and retry is usually sufficient
- Start without Kafka; add it when you hit back-pressure or need fan-out

Related notes: [OpenTelemetry overview](../OpenTelemetry/001-opentelemetry-overview.md)

### Deployment on Kubernetes

- **Strimzi Operator** -- the standard way to run Kafka on Kubernetes; manages brokers, topics, and users as CRDs
- **KRaft mode** -- Kafka's built-in consensus (replaces ZooKeeper); fewer moving parts, simpler operations; default since Kafka 3.5+
- Typical resource baseline: 3 broker pods, 2-4 CPU and 4-8 Gi memory each, persistent volumes for log segments
- Use `KafkaTopic` CRD to declaratively manage topics alongside your GitOps workflow

Related notes: [../000-core](../000-core.md)
