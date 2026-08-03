# RustFS Observability

Pigsty keeps the RustFS integration deliberately small:

```text
RustFS -- OTLP/HTTP ------------------> first Infra / VictoriaMetrics
Grafana -- PromQL/MetricsQL ----------> VictoriaMetrics
minio job -- blackbox HTTPS ----------> RustFS /minio/health/ready
RustFS stdout --> journald -- existing generic syslog path --> VictoriaLogs
```

RustFS sends metrics directly to one VictoriaMetrics OTLP/HTTP endpoint. If
`rustfs_metrics_endpoint` is empty, the role selects the first host in the
`infra` inventory group and uses `/opentelemetry/v1/metrics`. It does not install a
Collector and does not add or modify a Vector source, transform, or sink.

This has an important multi-infra consequence. Independent single-node
VictoriaMetrics databases do not replicate pushed samples, so only the
selected receiver contains RustFS metrics. A load balancer over those databases
would shard samples rather than copy them. Sites that require replicated
metrics should set `rustfs_metrics_endpoint` to an existing VictoriaMetrics
Cluster/VIP endpoint whose storage architecture already owns replication.

RustFS application logs remain in systemd journal at `warn` level by default
and may flow through Pigsty's existing generic syslog path. The generic stream
stores RustFS's structured JSON in `_msg`; Dashboard queries apply LogsQL
`unpack_json` at query time so the embedded level, component, subsystem, event,
message, and error fields are displayed correctly. No collection-pipeline
change is required.

## Identity and Freshness

The rendered OTLP metrics endpoint appends these VictoriaMetrics `extra_label`
parameters:

- `job=minio`
- `flavor=rustfs`
- `cls=<minio_cluster>`
- `ins=<minio_cluster>-<minio_seq>`
- `ip=<inventory_hostname>`
- `instance=<inventory_hostname>:<minio_port>`

RustFS also exports OTEL resource attributes such as `service.name`,
`service.version`, `deployment.environment.name`, and
`network.local.address`. The Pigsty labels are authoritative: a VM or container
may report a NAT-side `network.local.address` that is not its management IP.
Resource attributes can also change after a restart or upgrade and therefore
create a new physical time series. Recording rules and dashboards aggregate
away those attributes by the stable `cls`, `ins`, and `ip` identity; otherwise
Grafana can display the old and new process as two values in the same panel.

`rustfs_start_total` is exported on every metrics interval and is used as a
freshness heartbeat. Independent HTTPS probes are stored beside MinIO targets
under `/infra/targets/minio` and are evaluated by the same `job=minio` scrape
configuration. They provide expected-instance discovery and `rustfs_up`; this
distinguishes a healthy process with broken telemetry from a process that is
actually unavailable.

## Dashboard Query Rules

- Cluster capacity, bucket, drive, and erasure-set metrics are reported by
  every node. Use `max` or `min` grouped by the object identity to deduplicate;
  never sum these repeated cluster snapshots.
- Process and HTTP transport counters are node-local. Sum their rates when a
  cluster total is required.
- Collapse OTEL resource dimensions before presentation: use `max`/`min` for
  gauges and `sum(rate())` or `sum(increase())` for counters. Preserve only
  semantic dimensions such as `method`, `status_class`, `operation`, `drive`,
  and `failure_type`.
- Use `rate()` for counters and `increase()` for error counts over an incident
  window.
- The beta11 generic HTTP latency histogram has a five-second smallest non-zero
  bucket. The dashboards intentionally use `rate(sum) / rate(count)` for an
  exact average instead of displaying misleading p95/p99 values.
- Use `rustfs_s3_operations_total{op=...}` for application-facing S3 operation
  rate. `rustfs_http_server_*` covers the whole transport, including S3,
  admin, health, console, and internode HTTP, so it remains useful for total
  load and error diagnosis but is not an S3-only request family.

## MinIO Mapping

| MinIO metric | RustFS metric or expression | Fit |
|--------------|-----------------------------|-----|
| `minio_cluster_bucket_total` | `rustfs_cluster_buckets_total` | Direct |
| `minio_cluster_capacity_raw_total_bytes` | `rustfs_cluster_capacity_raw_total_bytes` | Direct |
| `minio_cluster_capacity_usable_total_bytes` | `rustfs_cluster_capacity_usable_total_bytes` | Direct |
| `minio_cluster_capacity_usable_free_bytes` | `rustfs_cluster_capacity_free_bytes` | Near-direct |
| `minio_cluster_usage_total_bytes` | `rustfs_cluster_capacity_used_bytes` | Near-direct |
| `minio_cluster_drive_online_total` | `rustfs_cluster_health_drives_online_count` | Direct |
| `minio_cluster_drive_offline_total` | `rustfs_cluster_health_drives_offline_count` | Direct |
| `minio_cluster_nodes_offline_total` | `rustfs_cluster_servers_offline_total` | Direct |
| `minio_cluster_usage_object_total` | `rustfs_cluster_objects_total` | Direct |
| `minio_node_process_cpu_total_seconds` | `rustfs_system_process_cpu_total_seconds` | Direct |
| `minio_node_process_resident_memory_bytes` | `rustfs_system_process_resident_memory_bytes` | Direct |
| `minio_node_file_descriptor_open_total` | `rustfs_system_process_file_descriptor_open_total` | Direct |
| `minio_node_io_read_bytes` | `rustfs_system_process_io_read_bytes` | Direct |
| `minio_s3_requests_total{api=...}` | `rustfs_s3_operations_total{op=...}` | Near-direct; operation label is `op` |
| `minio_s3_requests_errors_total` | `rustfs_http_server_failures_total{status_class=...}` | Partial; transport-wide |
| `minio_s3_traffic_received_bytes` | `rustfs_http_server_request_body_bytes_total` | Partial; transport-wide |
| `minio_s3_traffic_sent_bytes` | `rustfs_http_server_response_body_bytes_total` | Partial; transport-wide |
| `minio_software_version_info` | OTEL `service.version` resource label | Partial; beta11 reports `1.0.0` |

RustFS additionally exposes detailed erasure-set health, drive runtime states,
internode operations, scanner cycles, allocator/cgroup memory, TLS runtime,
IAM synchronization, ILM, replication, and object-path metrics that are not
present in Pigsty's MinIO v2 scrape today.

## Dashboards

- `rustfs-overview.json`: selectable cluster identity and member inventory,
  standard Pigsty load/alert strip, capacity, buckets, erasure health, HTTP
  transport, drives, internode RPC, scanner, ILM, replication, and logs.
- `rustfs-instance.json`: one selected instance, its cluster member context,
  standard Pigsty load/alert strip, process resources, HTTP transport, drive
  observations, internode RPC, scanner, allocator, TLS runtime, and logs.

The Pigsty Home, Node Overview, Node Cluster, Node Instance, PGSQL Cluster,
and PGSQL Instance status panels also expose `rustfs_up` with the same pink
MinIO-family component color and deep links to the RustFS instance dashboard.

Empty feature-specific panels are expected when ILM, replication, or a given
I/O path has not been used. Metric instruments are created lazily by RustFS.

## Four-Node Validation Snapshot

Validated on 2026-08-03 with four Ubuntu 24.04 ARM64 nodes, the Pigsty INFRA
`rustfs` package `1.0.0-b11`, TLS, and VictoriaMetrics `v1.148.0`:

- all four RustFS services and all four independent readiness probes were up;
- native OTLP/HTTP ingestion was validated directly against VictoriaMetrics;
- the configured 15-second export interval was observed at exactly 15 seconds;
- 396 active native metric names and about 5,986 active application series were seen
  after scanner and S3 activity (counts are workload- and feature-dependent);
- all 116 Dashboard metric queries parsed successfully; 112 returned live
  data and the only four empty results were the expected firing/pending alert
  series while no alert was active. All four LogsQL queries executed
  successfully, all 10 RustFS queries added to shared Pigsty dashboards
  returned data, and the recording/alert file passed `vmalert -dryRun`;
- the generic HTTP histogram reported a roughly 18 ms mean while its coarse
  buckets produced a misleading 4.75 s p95, confirming the decision to show
  the exact mean instead of percentile panels;
- `UNEXPECTED_EOF` TLS noise tracked the readiness probe cadence and was
  incorporated into the alert baseline described below.

## Production Defaults

- Keep a 15-second export interval and alert after 90 seconds without fresh
  telemetry to tolerate transient export failures.
- Keep the readiness probe separate from the OTLP path.
- Keep `rustfs_log_level: warn` for normal operation. RustFS `info` logging is
  dominated by internode HTTP/RPC traffic. Logs remain in journald and can use
  Pigsty's existing generic syslog collection without a RustFS-specific route.
- In the tested beta11 build, each successful HTTPS readiness probe also
  increments `rustfs_tls_handshake_failures{failure_type="UNEXPECTED_EOF"}`
  at a stable baseline. The bundled alert is calibrated per instance while
  retaining a lower threshold for every other TLS failure type. Recheck this
  behavior when upgrading RustFS.
- Restrict VictoriaMetrics ingestion to the management network. Use
  `RUSTFS_OBS_ENDPOINT_METRICS_HEADERS` through `minio_extra_vars` when an
  authenticated remote endpoint is required.
- Audit active-series cardinality after enabling new RustFS features. Avoid
  adding bucket, object key, request ID, or peer address as custom labels.
- Preserve raw RustFS metrics and normalize only with recording rules. This
  keeps future upstream metric changes observable and avoids pretending that
  partial MinIO mappings are exact.
