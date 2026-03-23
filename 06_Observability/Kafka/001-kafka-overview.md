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

Related notes: [OpenTelemetry overview](../OpenTelemetry/001-opentelemetry-overview.md), [Loki and Promtail](../Logging/002-loki-and-promtail.md)

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

Related notes: [Loki and Promtail](../Logging/002-loki-and-promtail.md), [Tempo overview](../Tracing/001-tempo-overview.md)

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

# Practical Command Set (Core)

```bash
# --- Topic Management ---
# Create a topic with 3 partitions and replication factor 3
kafka-topics.sh --bootstrap-server localhost:9092 --create --topic logs-raw --partitions 3 --replication-factor 3

# List all topics
kafka-topics.sh --bootstrap-server localhost:9092 --list

# Describe a topic (partitions, replicas, ISR)
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic logs-raw

# --- Produce / Consume Test Messages ---
# Produce a test message to a topic (interactive, Ctrl+C to stop)
echo '{"level":"info","msg":"test log"}' | kafka-console-producer.sh --bootstrap-server localhost:9092 --topic logs-raw

# Consume messages from the beginning of a topic
kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic logs-raw --from-beginning --max-messages 10

# --- Consumer Lag ---
# Check consumer group lag (critical for monitoring pipeline health)
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group otel-logs-consumer --describe

# List all consumer groups
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list
```

# Troubleshooting Guide

### Consumer Lag Keeps Growing

1. Check current lag per partition: `kafka-consumer-groups.sh --bootstrap-server localhost:9092 --group <group> --describe`
2. Identify which partitions have the highest lag -- this points to a slow or stuck consumer instance
3. Verify the consumer application logs for errors (e.g., Loki returning 429 rate-limit or OOM kills)
4. Scale up consumer instances (must not exceed partition count -- extra consumers sit idle)
5. If a single partition is hot, check your partitioning key; consider repartitioning to spread load

### Broker Not Responding

1. Check broker pod status: `kubectl get pods -n kafka` -- look for CrashLoopBackOff or pending state
2. Inspect broker logs: `kubectl logs <broker-pod> -n kafka` -- look for disk full, OOM, or leader election failures
3. Verify persistent volume is bound and has free space: `kubectl exec <broker-pod> -- df -h /var/lib/kafka`
4. Check network policies or service mesh configs blocking inter-broker communication on ports 9091-9093
5. If using KRaft, verify controller quorum: `kafka-metadata.sh --snapshot /var/lib/kafka/data/__cluster_metadata-0/00000000000000000000.log --cluster-id <id>`

### Topic Not Receiving Data

1. Verify the producer can reach the bootstrap server: `kafka-broker-api-versions.sh --bootstrap-server localhost:9092`
2. Check that the topic exists and is not marked for deletion: `kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic <topic>`
3. Confirm the OTel Collector Kafka exporter config: correct `brokers`, `topic`, `protocol_version`, and `encoding` fields
4. Produce a test message manually to isolate whether the issue is the producer or the cluster
5. Check broker logs for authorization errors if ACLs or SASL are enabled
