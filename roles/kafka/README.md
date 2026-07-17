# Role: kafka

> Deploy Apache Kafka 4.x cluster in native dynamic KRaft mode

| **Module**        | [KAFKA](https://pigsty.io/docs/kafka)                      |
|-------------------|------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/kafka                               |
| **Related Roles** | [`node_id`](../node_id), [`kafka_remove`](../kafka_remove) |


## Overview

The `kafka` role deploys production-ready Kafka 4.x clusters with:

- **Dynamic KRaft** quorum: no ZooKeeper, no static `controller.quorum.voters`
- **Bootstrap manifest** freezing cluster identity, initial controllers, and replication policy
- **Safe lifecycle**: parallel bootstrap for fresh clusters, one-at-a-time gated broker
  admission and rolling restart for healthy clusters; a no-change run restarts nothing
- **Declarative resources**: topics, users, ACLs, and quotas reconciled against live metadata
- **Security profiles**: `plaintext` for trusted networks, or the `scram` production profile
  with Pigsty-CA node certs, controller mTLS, SASL_SSL + SCRAM-SHA-512, and default-deny ACLs
- **Monitoring**: per-JVM JMX exporter plus at most two protocol exporter replicas,
  registered to VictoriaMetrics on infra nodes

The role converges one cluster to its declared state in a single idempotent pass and
never wipes an existing cluster: teardown lives in [`kafka_remove`](../kafka_remove).


## Playbooks

| Playbook       | Description                                            |
|----------------|--------------------------------------------------------|
| `kafka.yml`    | Init / converge kafka cluster (id + kafka)             |
| `kafka-rm.yml` | Remove cluster (use [`kafka_remove`](../kafka_remove)) |

Every lifecycle run must select every member of exactly one `kafka_cluster`:

```bash
./kafka.yml --check -l kf-main    # dry run first
./kafka.yml -l kf-main            # bootstrap, or converge to declared state
```


## File Structure

```
roles/kafka/
├── defaults/
│   └── main.yml              # Public API: 15 persistent variables
├── handlers/
│   └── main.yml              # Intentionally empty: restarts are owned by launch.yml
├── files/
│   ├── kafka_health.py       # Role-owned health predicate (pigsty-kafka-health)
│   └── kafka_provision.py    # Declarative provision helper (pigsty-kafka-provision)
├── tasks/
│   ├── main.yml              # Entry point: orchestrates all subtasks
│   ├── identity.yml          # [kafka-id] Derive & assert identity and topology
│   ├── install.yml           # [kafka_install] Create OS user & install packages
│   ├── config.yml            # [kafka_config] Config, manifest, security, format, lifecycle
│   ├── security.yml          # [kafka_security] Secrets, certs, keystores, admin channels
│   ├── launch.yml            # [kafka_launch] Converge / admit / roll / commission
│   ├── admit.yml             # One gated broker admission (looped by launch.yml)
│   ├── roll.yml              # One gated rolling restart (looped by launch.yml)
│   ├── provision.yml         # [kafka_provision] Users, ACLs, quotas & topics
│   └── monitor.yml           # [kafka_monitor] Exporters & victoria registration
└── templates/
    ├── server.properties.j2  # Kafka server configuration
    ├── admin.properties.j2   # Role-owned broker admin channel
    ├── controller.properties.j2  # Role-owned controller admin channel
    ├── kafka.env.j2          # JVM heap & agent environment
    ├── kafka.service         # Kafka systemd unit
    ├── kafka_exporter.env.j2 # Protocol exporter options
    ├── kafka_exporter.service # Protocol exporter systemd unit
    ├── jmx_exporter.yml.j2   # Bounded JMX metric rules
    └── log4j2.yaml.j2        # Journald logging configuration
```

Every cluster node keeps authoritative copies of the bootstrap facts:
`/etc/kafka/manifest.yml` (cluster identity, initial controllers, frozen
replication policy) and `/etc/kafka/secrets.yml` (role-owned scram secrets).
The admin-side `files/kafka/<kafka_cluster>/` dir is only a convenience cache:
when lost or relocated it is transparently recovered from any cluster member,
and issued certificates are simply re-signed from the pigsty CA. A stale
manifest paired with empty data disks still fails closed.


## Tags

### Tag Hierarchy

```
kafka (full role)
│
├── kafka-id                   # Derive & assert identity (always runs)
│
├── kafka_install              # Software installation
│   ├── kafka_user             # Create kafka OS user & group
│   └── kafka_pkg              # Install kafka-stack & java-runtime packages
│
├── kafka_config               # Configuration & storage
│   ├── kafka_dir              # Create data & config directories
│   ├── kafka_meta             # Inspect on-disk KRaft metadata identity
│   ├── kafka_manifest         # Load / reconstruct / create bootstrap manifest
│   ├── kafka_security         # Secrets, Pigsty-CA certs, keystores, admin channels
│   ├── kafka_fingerprint      # Static-config fingerprint (restart trigger)
│   ├── kafka_format           # Format uninitialized storage (dynamic quorum)
│   └── kafka_lifecycle        # Classify run as converge or strict rolling
│
├── kafka_launch               # Service lifecycle
│   ├── converge               # Parallel bootstrap of fresh/unhealthy cluster
│   ├── admit                  # Gated one-at-a-time broker admission
│   ├── roll                   # Quorum/minISR-gated rolling restart
│   └── kafka_commission       # Commission manifest & record proven state
│
├── kafka_provision            # Provision users, ACLs, quotas & topics
│
└── kafka_monitor              # Monitoring [monitor]
    ├── kafka_exporter         # Protocol exporter on selected nodes
    └── kafka_register         # Register targets [register, add_metrics]
```

Phase tags are sequencing markers within the single-pass role; only
`kafka_install` and `register` are meaningful standalone entrypoints, and
everything else converges through a full run.

### Usage Examples

```bash
# Full deployment / convergence
./kafka.yml -l kf-main

# Install packages only
./kafka.yml -l kf-main -t kafka_install

# Re-register victoria monitoring targets
./kafka.yml -l kf-main -t register

# Protected credential / certificate rotation (scram clusters)
./kafka.yml -l kf-main -e kafka_rotate_credentials=true  -e kafka_rotate_confirm=kf-main
./kafka.yml -l kf-main -e kafka_rotate_certificates=true -e kafka_rotate_confirm=kf-main

# Remove a cluster (honors kafka_safeguard)
./kafka-rm.yml -l kf-main
```


## Key Variables

### Identity (Required)

| Variable        | Level        | Description                                  |
|-----------------|--------------|----------------------------------------------|
| `kafka_cluster` | **CLUSTER**  | Cluster name (required)                      |
| `kafka_seq`     | **INSTANCE** | Unique KRaft `node.id` (required)            |
| `kafka_role`    | **INSTANCE** | `combined` (default), `broker`, `controller` |

### Cluster

| Variable                | Default         | Description                                      |
|-------------------------|-----------------|--------------------------------------------------|
| `kafka_data`            | `/data/kafka`   | Role-owned data root                             |
| `kafka_heap_opts`       | `-Xms1G -Xmx1G` | JVM heap options                                 |
| `kafka_port`            | `9092`          | Broker / client listener                         |
| `kafka_controller_port` | `9093`          | KRaft controller listener                        |
| `kafka_rack`            | unset           | Optional broker placement label (all or none)    |
| `kafka_parameters`      | `{}`            | Extra non-role-owned broker settings             |
| `kafka_cluster_id`      | unset           | Recovery/adoption assertion; bootstrap is random |

### Security

| Variable         | Default     | Description                                     |
|------------------|-------------|-------------------------------------------------|
| `kafka_security` | `plaintext` | `plaintext` or the production `scram` profile   |
| `kafka_users`    | `[]`        | Declarative credential, ACL, and quota objects  |
| `kafka_topics`   | `[]`        | Declarative topic objects                       |
| `cert_validity`  | `7300d`     | Node cert validity (shared Pigsty CA parameter) |

### Monitoring

| Variable                     | Default | Description                          |
|------------------------------|---------|--------------------------------------|
| `kafka_jmx_exporter_port`    | `9404`  | JMX exporter port                    |
| `kafka_exporter_port`        | `9308`  | Protocol exporter port               |

Topology, listeners, storage paths, replication safety, authorizer, TLS, and SASL
keys are role-owned and cannot be overridden through `kafka_parameters`.

Full parameter reference: [KAFKA Configuration](https://pigsty.io/docs/kafka/config)


## Operation Notes

- New clusters bootstrap with a **random Cluster ID** and random initial controller
  directory IDs; after first healthy convergence the manifest is `commissioned` and
  those identities are frozen.
- Initial replication policy derives from broker count:
  `RF = min(3, brokers)`, `minISR = max(1, RF - 1)`, then freezes in the manifest.
- A healthy cluster with static changes performs a strict one-at-a-time rolling
  restart with pre/post quorum, offline-partition, under-minISR, and ISR catch-up
  gates; expansion admits newly formatted pure brokers one at a time.
- A sole controller/broker cannot restart without downtime: such a restart
  proceeds with a logged warning and a brief unavoidable outage.
- An empty controller disk under a commissioned manifest **fails closed**: reusing a
  frozen directory ID would be a Raft identity replay. Controller membership changes
  require the explicit Kafka `add-controller`/`remove-controller` procedure (not yet
  orchestrated by this role; a Beta limitation).
- `default.replication.factor` and existing topic RF never change automatically after
  expansion; use a reviewed `kafka-reassign-partitions.sh` plan.
- Clients must resolve and reach every broker's `inventory_hostname` directly:
  do not front the Kafka data plane with haproxy / VIP / L4 LB.
- The default 1GiB heap suits ≥4GiB nodes; pair smaller lab nodes with a smaller heap.


## See Also

- [`kafka_remove`](../kafka_remove): Remove kafka cluster (`kafka_safeguard` protected)
- [`node_id`](../node_id): Node identity & package alias resolution
- [KAFKA Docs](https://pigsty.io/docs/kafka): Config, playbook, admin, monitor, FAQ
