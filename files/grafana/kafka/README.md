# Kafka Monitoring Model

Pigsty models Kafka monitoring with four dashboards. The split follows Kafka's
operational objects rather than exporter processes.

| Dashboard | Primary variable | Responsibility |
|------------|------------------|----------------|
| Kafka Overview | `cls` | One KRaft cluster: identity, member inventory, reliability, load, alerts, activity, exporters and logs |
| Kafka Instance | `ins` | One broker/controller JVM plus its request path, KRaft state and host resources joined through `ip` |
| Kafka Topic | `cls`, `topic` | Topic and partition topology, offsets, ISR health, append rate and attached consumers |
| Kafka Consumer | `cls`, `group` | Consumer group membership, committed offsets, lag and progress without invalid cross-topic offset arithmetic |

`Kafka Node` was intentionally retired. It duplicated the JVM and operating
system sections now owned by Kafka Instance. Generic host investigation remains
available through the Node Instance dashboard.

## Metric contract

There are two distinct scrape roles under `job="kafka"`:

- JMX targets have a non-empty `role` (`broker`, `controller`, or `combined`).
  Their `cls`, `ins`, `ip`, `node_id`, and `role` labels identify a real Kafka
  process. These targets are authoritative for instance inventory.
- kafka_exporter targets have no `role`. They query a whole cluster and expose
  broker, topic, partition and consumer-group protocol state. Two exporters may
  report identical logical series. Business queries must therefore apply
  `max without (ins, ip, instance)` before summing logical objects.

The JMX allow-list is maintained in
`roles/kafka/templates/jmx_exporter.yml.j2`. It intentionally excludes
per-client and per-partition MBeans: protocol detail belongs to kafka_exporter,
and the exclusion bounds cardinality.

| Operational question | Authoritative metrics | Presentation / rule |
|----------------------|-----------------------|---------------------|
| Is the cluster writable and replicated? | controller offline partitions, active controller, under-min-ISR, under-replicated partitions | Overview reliability, Instance replication, critical/warning alerts |
| Is KRaft healthy? | raft state/epoch/HW/LEO, controller elections, metadata apply lag/errors | Instance KRaft section |
| Where is request capacity exhausted? | request handler/network processor idle ratio, queues, API latency/errors | Instance request section and saturation alerts |
| Which topic/partition is unhealthy or hot? | leader, preferred leader, replicas, ISR, offsets and offset rate | Topic partition topology and append rate |
| Is a consumer falling behind? | group members, committed offset, partition lag, commit rate | Consumer lag/progress and sustained-growing-lag alert |
| Is storage or the host saturated? | offline log directories plus Node CPU, memory, filesystem, disk latency/utilization and network | Instance Node section; generic Node alerts remain authoritative |
| Is collection itself broken? | `up`, `jmx_scrape_error`, scrape duration/samples and exporter runtime | lightweight Exporter sections |

## Recording and alert rules

`files/victoria/rules/kafka.yml` records stable, reusable rates and lag:

- `kafka:topic:msg_rate{1m,5m}` and `kafka:cls:msg_rate{1m,5m}`
- `kafka:csg_topic:commit_rate5m`, `kafka:csg_topic:lag`,
  `kafka:csg:lag`, and `kafka:cls:lag`
- broker/JVM rates, request error rate, and cluster replication health

Offsets are never summed across topics before retaining `topic`. An offset is a
position within one partition, not a globally additive byte or time measure.
The consumer alert requires both a material backlog and continued growth for 30
minutes, avoiding alerts for a large but actively draining replay.

Dashboards consume `kafka:csg_topic:lag` directly for every headline lag number
(Overview, Topic and Consumer `Total Lag` stats and the lag-by-group panels), so
the number an operator sees is the same series the `KafkaConsumerLagGrowing`
alert evaluates. The `kafka_consumergroup_lag_sum` / `_current_offset_sum`
exporter families are not used: they are computed independently inside
kafka_exporter and can disagree with the per-partition series within one scrape.
Worst-partition lag on the Topic page is `max by (partition)` across all groups;
retaining `consumergroup` there would produce duplicate join keys and silently
drop groups from the table.

Kafka-specific rules cover process/exporter availability, scrape failure, JVM
deadlock/heap, request and network saturation, replica/ISR failure, offline log
directories/partitions, controller cardinality, fenced brokers, unclean leader
election, and sustained consumer lag. A few recorded aggregates
(`kafka:cls:msg_rate*`, `kafka:cls:lag`, `kafka:ins:jvm_gc_time_rate5m`,
`kafka:ins:request_error_rate5m`, `kafka:cls:under_replicated_partitions`,
`kafka:cls:offline_partitions`) are not consumed by any panel; they are kept
deliberately as stable query points for alerting, capacity scripts and API
consumers, while panels that want adaptive `$__rate_interval` windows compute
the same expressions inline. Host capacity alerts are not duplicated;
they are already evaluated by Pigsty's Node rules and are visible through the
shared `category`/`cls` alert panels.

## Dashboard conventions

- Kafka teal `#4bb39ce0` is the healthy/identity color; warning and critical
  states retain Pigsty amber/red conventions.
- Overview is always first. Exporter is deliberately the penultimate section
  and Logs is last.
- Topic and consumer pages select a single cluster. `topic` may be multi-value
  only where cross-topic group analysis is meaningful.
- All pages preserve time range and variables through the `KAFKA` dashboard
  navigation dropdown.
- Panels use the provisioned `ds-prometheus` and `ds-vlogs` data sources;
  no dashboard embeds environment-specific datasource IDs or credentials.
- Joined tables (identity, inventory, partition topology) follow the Grafana 13
  join contract: every instant query uses `format: table`, the join field is the
  meaningful label itself (`cls`, `ins`, `topic`, `consumergroup`, `partition`,
  or a `label_join`ed `key`), and only the join field keeps its plain name —
  any column name that collides across frames is suffixed (` 1`, ` 2`, …), so
  `organize` excludes must target the suffixed names and must never hide the
  join field, or the table loses its row identity.

## Compatibility and known gaps

The dashboard only uses metrics in the checked-in Kafka 4.x JMX allow-list or
the kafka_exporter protocol contract. Controller-only panels legitimately show
no data on broker-only processes. Consumer panels show no data until at least
one consumer group has committed offsets; this is not an exporter failure.

Kafka does not expose a portable per-topic byte-size metric through the current
bounded contract, so the Topic page uses retained offset span as a record-volume
indicator and does not mislabel it as bytes. Filesystem capacity is shown at the
instance/node level because mapping an arbitrary `log.dirs` path to a Node
Exporter mount point cannot be derived safely from the current labels.

