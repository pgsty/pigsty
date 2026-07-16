# Kafka role

This role deploys the Pigsty v4.4 first-phase Kafka module with Apache Kafka
4.x in KRaft mode. It does not install or configure ZooKeeper.

The 2026-07-16 repository snapshot was verified from the actual RPM and DEB
metadata and payloads:

- RPM: `kafka-4.3.1-1.noarch`, `kafka_exporter-1.9.0-1`
- DEB: `kafka_4.3.1_all`, `kafka-exporter_1.9.0`
- Kafka home: `/opt/kafka`
- Kafka config: `/etc/kafka/server.properties`
- Exporter binary: `/usr/bin/kafka_exporter`
- Package aliases: `package_map['java-runtime']` and `package_map['kafka']`

The role uses the package aliases rather than pinning those observed versions,
so a future repository update remains controlled by the normal Pigsty package
workflow.

## Inventory

`kafka_role` accepts:

- `controller`: combined broker/controller (kept for compatibility with the
  restored module)
- `combined`: explicit combined broker/controller
- `broker`: broker only
- `controller-only`: controller only; no exporter target is registered

Single-node sandbox:

```yaml
kf-main:
  hosts:
    10.10.10.10: { kafka_seq: 1, kafka_role: controller }
  vars:
    kafka_cluster: kf-main
    kafka_peer_port: 9095
```

Three controllers with separate brokers:

```yaml
kf-main:
  hosts:
    10.10.10.11: { kafka_seq: 1, kafka_role: controller-only }
    10.10.10.12: { kafka_seq: 2, kafka_role: controller-only }
    10.10.10.13: { kafka_seq: 3, kafka_role: controller-only }
    10.10.10.14: { kafka_seq: 4, kafka_role: broker }
    10.10.10.15: { kafka_seq: 5, kafka_role: broker }
  vars:
    kafka_cluster: kf-main
    kafka_peer_port: 9095
```

Every node id must be unique. Controller endpoints are rendered as a static
`controller.quorum.voters` set on every node. The default cluster id is a
stable Kafka UUID derived from `kafka_cluster`; set `kafka_cluster_id`
explicitly when joining an existing cluster.

## Safety and idempotency

Storage formatting uses `metadata/meta.properties` as an idempotency marker.
An existing marker is checked for the expected cluster and node ids; a mismatch
fails closed. The role never reformats an initialized directory.

Cleanup is disabled by default and carries Ansible's `never` tag. It requires
all of the following:

```bash
./kafka.yml -l <exact-target> --tags kafka_clean \
  -e kafka_clean=true -e kafka_clean_confirm=<exact-kafka-cluster>
```

Do not run that operation without the production runbook's explicit user
confirmation and backup checks.

## Observability

Broker nodes run `kafka_exporter` on port 9308 and register
`/infra/targets/kafka/<cluster>-<seq>.yml` with owner `victoria`, group `infra`,
and mode `0640`. Controller-only nodes remove a stale exporter target.
The exporter is explicitly pinned to Kafka protocol `4.0.0`, the newest level
supported by the bundled exporter 1.9.0 / Sarama 1.45.0 client. This avoids the
exporter's legacy `2.0.0` default, which Kafka 4.x no longer supports.

Kafka and exporter services write to journald with stable identifiers `kafka`
and `kafka_exporter`. The existing node Vector journald source forwards them to
VictoriaLogs as `job:syslog`; this role intentionally adds no file source.

Useful log queries:

```text
job:syslog unit:kafka
job:syslog app:kafka
job:syslog unit:kafka_exporter
```

## Migration audit

### MUST PORT

- Load RPM/DEB names through the current `node_id` `package_map`.
- Use the verified `/opt/kafka` and `/usr/bin/kafka_exporter` payload paths.
- Render Kafka 4.x KRaft identities, listeners, static controller quorum, and
  separate data/metadata directories.
- Make storage format idempotent and restart services only through handlers.
- Install distinct Kafka/exporter units and register exporter targets under
  `/infra/targets/kafka` for VictoriaMetrics.
- Send console output through journald, Vector, and VictoriaLogs.
- Keep Grafana metrics on `ds-prometheus` and logs on `ds-vlogs`.

### FIX DURING PORT

- Replace the undefined `kafka_packages`, stale 3.8/Scala variables, forced
  `/usr/kafka` link, and old profile script.
- Move the controller listener away from AlertManager's port 9093 and assert
  against that collision on infra nodes.
- Replace unconditional format/restart, unsafe list iteration, ignored cleanup
  failures, and the exporter template written over the node exporter unit.
- Override kafka_exporter's incompatible Kafka 2.0 protocol default with the
  newest protocol level its bundled Sarama client supports (`4.0.0`).
- Replace old Prometheus paths/ownership/tags and remove its duplicate rules.
- Correct consumer-rate recording rules and the exporter alert description.
- Replace stale dashboard queries, unrelated links, and Loki-style logging.

### DEFER PHASE 2

- TLS, SASL/SCRAM, ACLs, and secret distribution
- Dynamic KRaft controller membership, rack awareness, cross-site design, and
  complex HA operations
- Kafka Connect, Schema Registry, and MirrorMaker
- Online upgrades and migration of existing Kafka data
- Full three-node failover drills and production deployment
- Rack awareness and cross-datacenter topology
- Kafka Connect, Schema Registry, and MirrorMaker
- Online upgrades and migration of existing Kafka data
- Full three-node failure and recovery drills

## Validation boundary

Syntax, template rendering, JSON parsing, and check mode are safe first-phase
validation surfaces. A non-check playbook run, service operation, topic smoke
test, or real deployment requires separate explicit approval and an exact
target limit.
