# Kafka role

This role deploys Apache Kafka 4.x in native dynamic KRaft mode. It owns the
bootstrap manifest, safe converge/rolling state machine, declarative topics and
users, TLS/SCRAM security profile, JMX monitoring, and at most two protocol
exporter replicas. ZooKeeper and static `controller.quorum.voters` are not used.

The 2026-07-16 package payload was verified as Kafka 4.3.1,
`kafka_exporter` 1.9.0, and JMX Exporter 1.6.0. Installation still uses
`package_map['java-runtime']` and `package_map['kafka-stack']`, so repository
package policy remains authoritative.

## Required operating discipline

Every lifecycle run must select every member of exactly one `kafka_cluster`:

```bash
./kafka.yml --check -l kf-main
./kafka.yml -l kf-main
```

The role rejects a missing, partial, or cross-cluster limit. A normal run uses
one health predicate to select its path:

- unhealthy or stopped cluster: start stopped controllers without restarting
  surviving members, require a caught-up dynamic quorum, then expose brokers;
- healthy cluster expansion: admit newly formatted pure brokers one at a time
  and verify registration before rolling any existing member;
- healthy cluster with static changes: strict `serial: 1` rolling restart with
  pre/post caught-up quorum, offline-partition, under-minISR, and ISR catch-up
  gates;
- healthy cluster without static changes: no Kafka restart.

The desired static fingerprint is persisted only after the rendered files are
proven live by a successful start or health-gated restart. If repair and a
static change coincide, converge first restores quorum without restarting live
controllers, then hands still-pending changes to strict rolling. An interrupted
run therefore cannot lose a pending static restart on the next invocation.

Formatting is one-time and explicit. Existing `meta.properties` is validated
for cluster and node identity and is never reformatted by a normal run.
Adding or replacing a controller is an explicit Kafka membership procedure:
format it for the existing cluster, start and catch it up, then run the Kafka
`add-controller` operation. Inventory membership alone is rejected; controller
removal likewise requires the corresponding explicit admin workflow.

## Inventory

The compact default is a combined cluster. Omit `kafka_role` on every member:

```yaml
kf-main:
  hosts:
    10.10.10.11: { kafka_seq: 1 }
    10.10.10.12: { kafka_seq: 2 }
    10.10.10.13: { kafka_seq: 3 }
  vars:
    kafka_cluster: kf-main
```

Split topology must declare every role explicitly. The only valid roles are
`combined`, `controller`, and `broker`:

```yaml
kf-main:
  hosts:
    10.10.10.11: { kafka_seq: 1, kafka_role: controller }
    10.10.10.12: { kafka_seq: 2, kafka_role: controller }
    10.10.10.13: { kafka_seq: 3, kafka_role: controller }
    10.10.10.21: { kafka_seq: 4, kafka_role: broker }
    10.10.10.22: { kafka_seq: 5, kafka_role: broker }
    10.10.10.23: { kafka_seq: 6, kafka_role: broker }
  vars:
    kafka_cluster: kf-main
```

Node IDs are unique cluster-wide. Broker-capable nodes either all declare
`kafka_rack` or all omit it. Controller port 9095 avoids Pigsty
AlertManager's 9093.

## Persistent public API

The role deliberately exposes only these 16 persistent variables:

| Variable | Default | Meaning |
|---|---|---|
| `kafka_cluster` | required | Cluster identity |
| `kafka_seq` | required | Unique KRaft `node.id` |
| `kafka_role` | `combined` | `combined`, `broker`, or `controller` |
| `kafka_cluster_id` | unset | Recovery/adoption assertion; bootstrap is random |
| `kafka_data` | `/data/kafka` | Role-owned data root |
| `kafka_heap_opts` | `-Xms1G -Xmx1G` | JVM heap |
| `kafka_port` | `9092` | Broker/client listener |
| `kafka_controller_port` | `9095` | Controller listener |
| `kafka_rack` | unset | Optional all-or-none broker placement label |
| `kafka_parameters` | `{}` | Non-role-owned broker settings |
| `kafka_jmx_exporter_enabled` | `true` | Per-JVM JMX endpoint |
| `kafka_jmx_exporter_port` | `9404` | JMX endpoint port |
| `kafka_exporter_port` | `9308` | Protocol exporter port |
| `kafka_security` | `plaintext` | `plaintext` or production `scram` profile |
| `kafka_users` | `[]` | Credential, ACL, and quota objects |
| `kafka_topics` | `[]` | Declarative topic objects |

Topology, listeners, storage paths, replication safety, authorizer, TLS, and
SASL keys are role-owned and cannot be overridden through `kafka_parameters`.

## Dynamic KRaft identity

New clusters receive a random Kafka Cluster ID and random initial controller
directory IDs. Every node formats with either `--initial-controllers` or
`--no-initial-controllers`; after startup, `kraft.version` must be dynamic.

Bootstrap-only facts live in:

```text
files/kafka/<kafka_cluster>/manifest.yml
```

The manifest contains only cluster identity, initial controller identities,
security mode, and frozen initial replication/minISR policy. The live cluster
remains authoritative. A stale manifest with empty disks, an identity mismatch,
or a security-mode mismatch fails closed. A healthy dynamic cluster can
reconstruct a missing manifest without reformatting; secure reconstruction also
requires its existing role-owned secrets.

The initial internal-topic, future-topic default RF, and cluster minISR policy
remain frozen during broker expansion. Kafka 4.3 does not allow
`default.replication.factor` to be updated dynamically, so changing that static
default requires an explicit maintenance plan. The role never claims or
performs replication-factor upgrades for existing topics; those require an
explicit reassignment workflow.

## Security profile

`kafka_security: scram` is one production profile rather than a set of
independent switches. It enables:

- TLS with Pigsty-CA-signed per-node certificates;
- mutual TLS on the controller listener;
- SASL_SSL and SCRAM-SHA-512 on the broker listener and inter-broker channel;
- `StandardAuthorizer` with deny-by-default;
- role-owned admin, monitor, and dual-slot inter-broker principals;
- monitor ACL convergence before the protocol exporter starts.

Internal credentials and generated private PKI are stored under
`files/kafka/<cluster>/`, mode-protected, and ignored by Git. Never copy their
contents into inventory, logs, or tickets. Changing `kafka_security` after
format is intentionally rejected; online plaintext-to-secure migration is a
separate future admin workflow.

Example application resources:

```yaml
kafka_security: scram
kafka_users:
  - name: order-service
    password: "{{ vault_kafka_order_password }}"
    acls:
      - resource: topic
        name: order.
        pattern: prefixed
        operations: [Read, Write, Describe]
      - resource: group
        name: order.
        pattern: prefixed
        operations: [Read]
      - resource: transactional_id
        name: order.
        pattern: prefixed
        operations: [Write, Describe]
    quota:
      producer_byte_rate: 10485760
      consumer_byte_rate: 20971520
kafka_topics:
  - name: order.events
    partitions: 12
    replication_factor: 3
    config:
      min.insync.replicas: 2
      cleanup.policy: delete
```

Topic creation is idempotent, partitions only increase, and only declared
configs converge. Replication-factor changes fail with an explicit reassignment
instruction. Removing a topic from inventory never deletes it. User password
changes rotate SCRAM credentials; ACLs and declared quotas converge
idempotently.

### Protected internal rotation

Internal inter-broker credentials use active/standby principals. Rotation first
changes the inactive credential through the live admin channel, atomically
switches the protected local secret record, then uses the normal strict rolling
path. The old active principal remains valid as the next standby, making a
partial run recoverable.

Run check mode first, then the confirmed full-cluster action:

```bash
./kafka.yml --check -l kf-main \
  -e kafka_rotate_credentials=true -e kafka_rotate_confirm=kf-main
./kafka.yml -l kf-main \
  -e kafka_rotate_credentials=true -e kafka_rotate_confirm=kf-main
```

Certificate rotation first requires controller and node UTC clocks to be
within 30 seconds. It generates replacements in an isolated staging
workspace, verifies the complete set against the Pigsty CA, promotes them only
after every certificate passes, rebuilds keystores, verifies validity again on
each node's clock, and enters the same strict rolling path. A generation or
clock-preflight failure therefore leaves the active certificate set intact.

```bash
./kafka.yml --check -l kf-main \
  -e kafka_rotate_certificates=true -e kafka_rotate_confirm=kf-main
./kafka.yml -l kf-main \
  -e kafka_rotate_certificates=true -e kafka_rotate_confirm=kf-main
```

The two actions are mutually exclusive, require an already formatted, healthy
SCRAM cluster, and are transient operations rather than persistent API fields.

## Protected cleanup

Cleanup deletes only the selected cluster's Kafka data, node-local security
state, monitoring discovery targets, bootstrap manifest, and internal
secret/PKI directory. It is tagged `never` and requires an exact cluster limit
plus all three confirmations:

```bash
./kafka.yml --check -l kf-main --tags kafka_clean \
  -e kafka_clean=true -e kafka_clean_confirm=kf-main
./kafka.yml -l kf-main --tags kafka_clean \
  -e kafka_clean=true -e kafka_clean_confirm=kf-main
```

Treat the formal command as destructive: verify backup/rebuild intent and get
the production runbook's explicit user confirmation first.

## Observability

Every Kafka JVM optionally exposes bounded JMX metrics at port 9404 and is
registered under `/infra/targets/kafka/`. Lifecycle gates never depend on JMX.

The first at most two broker-capable nodes run `kafka_exporter` and register
under `/infra/targets/kafka_exporter/`; deselected nodes have the unit,
environment, CA copy, and target removed. Secure mode derives exporter
TLS/SCRAM arguments from the monitor principal. Protocol version 4.0.0 is the
newest supported by the bundled exporter client.

Kafka and exporter output goes to journald with identifiers `kafka` and
`kafka_exporter`, then follows the existing Vector/VictoriaLogs path.

## Validation

Useful non-destructive checks:

```bash
ansible-playbook -i pigsty.yml kafka.yml --syntax-check
ANSIBLE_ROLES_PATH="$PWD/roles" \
  ansible-playbook -i roles/kafka/tests/inventory.yml roles/kafka/tests/render.yml
python3 roles/kafka/tests/health.py
./kafka.yml --check -l <exact-cluster>
jq -e . files/grafana/kafka/*.json
```

See `DESIGN.md` for the complete contract and acceptance criteria and
`REVIEW.md` for the two adversarial design reviews.
