# Role: minio

> Deploy MinIO or RustFS S3-compatible object storage

| **Module**        | [MINIO](https://pigsty.io/docs/minio) |
|-------------------|---------------------------------------|
| **Docs**          | https://pigsty.io/docs/minio/         |
| **Related Roles** | `minio_remove`, `ca`                  |


## Overview

The `minio` role deploys **MinIO** by default, or **RustFS** when
`minio_type: rustfs` is selected:

- Calculate cluster topology from inventory
- Install the selected server and the MinIO-compatible `mcli` client
- Configure TLS certificates
- Create data directories
- Launch MinIO service
- Register MinIO pull metrics or RustFS native OTLP metrics and readiness probe
- Provision buckets and users

MinIO is used for pgBackRest remote backup storage with S3 protocol.


## Playbooks

| Playbook       | Description          |
|----------------|----------------------|
| `minio.yml`    | Deploy MinIO cluster |
| `minio-rm.yml` | Remove MinIO cluster |


## File Structure

```
roles/minio/
├── defaults/
│   └── main.yml              # Default variables
├── handlers/
│   └── main.yml              # Handler definitions
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point
│   ├── install.yml           # [minio_install] Installation
│   ├── config.yml            # [minio_config] Configuration
│   └── provision.yml         # [minio_provision] Bucket/user setup
└── templates/
    ├── minio.env             # MinIO environment config
    ├── minio.svc             # MinIO systemd service
    ├── rustfs.env            # RustFS environment config
    ├── rustfs.svc            # RustFS systemd service
    └── policy.json           # Bucket policy template
```


## Tags

### Tag Hierarchy

```
minio (full role)
│
├── minio-id                   # Validate identity parameters
│
├── minio_install              # Install MinIO
│   ├── minio_os_user          # Create minio OS user
│   ├── minio_pkg              # Install minio/mcli packages
│   └── minio_dir              # Create data directories
│
├── minio_config               # Configure MinIO
│   ├── minio_conf             # Generate config files
│   ├── minio_cert             # TLS certificates
│   └── minio_dns              # DNS registration
│
├── minio_launch               # Start MinIO service
│
├── minio_register             # Register to monitoring
│   └── add_metrics            # Add Victoria targets
│
└── minio_provision            # Provision resources
    ├── minio_alias            # Configure mcli alias
    ├── minio_bucket           # Create buckets
    └── minio_user             # Create users/policies
```


## Key Variables

### Identity (Required)

| Variable       | Level    | Description              |
|----------------|----------|--------------------------|
| `minio_type`   | GLOBAL / CLUSTER | Engine: `minio` or `rustfs` |
| `minio_cluster`| CLUSTER  | MinIO cluster name       |
| `minio_seq`    | INSTANCE | Instance sequence number |

### Network

| Variable          | Default           | Description              |
|-------------------|-------------------|--------------------------|
| `minio_port`      | `9000`            | MinIO API port           |
| `minio_admin_port`| `9001`            | MinIO console port       |
| `minio_domain`    | `sss.pigsty`      | External domain name     |

### Storage

| Variable      | Default        | Description                    |
|---------------|----------------|--------------------------------|
| `minio_data`  | `/data/minio`  | Data directory (supports `{x...y}` for multiple drives) |
| `minio_volumes`| (auto)        | Volume specification           |

### Security

| Variable          | Default         | Description              |
|-------------------|-----------------|--------------------------|
| `minio_https`     | `true`          | Enable HTTPS             |
| `minio_access_key`| `minioadmin`    | Root access key          |
| `minio_secret_key`| `S3User.MinIO`  | Root secret key          |

### RustFS Observability

| Variable                     | Default      | Description |
|------------------------------|--------------|-------------|
| `rustfs_metrics_enabled`     | `true`       | Export RustFS metrics with OTLP/HTTP |
| `rustfs_metrics_endpoint`    | `''`         | Explicit single OTLP endpoint; empty uses VictoriaMetrics on the first infra host |
| `rustfs_metrics_interval`    | `15`         | Metrics export interval in seconds |
| `rustfs_metrics_environment` | `production` | OTEL deployment environment resource attribute |
| `rustfs_log_enabled`         | `true`       | Emit structured application logs to systemd journal |
| `rustfs_log_level`           | `warn`       | RustFS log level; `info` is very verbose |

By default RustFS sends OTLP/HTTP metrics directly to VictoriaMetrics on the
first host in inventory group `infra`. This deliberately adds no Collector,
relay, or RustFS-specific Vector configuration. The endpoint receives the
standard `job`, `cls`, `ins`, `ip`, and `instance` labels as VictoriaMetrics
`extra_label` query parameters. RustFS deliberately uses `job=minio` plus
`flavor=rustfs`, so it stays in the existing MinIO module namespace while its
native metric names remain distinguishable.

An independent VictoriaMetrics process on every infra node is not a replicated
push target: only the selected receiver stores RustFS samples. If complete
multi-infra copies are required, set `rustfs_metrics_endpoint` to an existing
VictoriaMetrics Cluster/VIP endpoint whose storage layer owns replication.
Do not point it at a load balancer over independent single-node databases,
because that would shard samples instead of copying them.

RustFS application logs go to systemd journal at `warn` level by default. They
may be collected through Pigsty's existing generic syslog path; the role does
not add or alter any Vector source, transform, or sink.

The role also registers the RustFS HTTPS readiness endpoint in the existing
`/infra/targets/minio` directory. The `minio` scrape job sends only targets
marked `flavor=rustfs` through `blackbox_exporter`, since a push-only source
cannot report that it has stopped.

The two bundled dashboards are `RustFS Overview` and `RustFS Instance`. See
`files/grafana/rustfs/README.md` for metric mappings, query rules, limitations,
and production guidance.

### Provisioning

| Variable           | Default | Description              |
|--------------------|---------|--------------------------|
| `minio_provision`  | `true`  | Run provisioning tasks   |
| `minio_alias`      | `sss`   | mcli alias name          |
| `minio_buckets`    | `[...]` | Buckets to create        |
| `minio_users`      | `[...]` | Users to create          |


## Cluster Topology

Both engines support single-node and multi-node distributed modes through the
same inventory model:

### Single Node

```yaml
minio:
  hosts:
    10.10.10.10: { minio_seq: 1 }
  vars:
    minio_cluster: minio
```

### Multi-Node Distributed

```yaml
minio:
  hosts:
    10.10.10.11: { minio_seq: 1 }
    10.10.10.12: { minio_seq: 2 }
    10.10.10.13: { minio_seq: 3 }
    10.10.10.14: { minio_seq: 4 }
  vars:
    minio_cluster: minio
    minio_data: '/data{1...4}/minio'  # Multiple drives
```

For RustFS, select the engine and install the package from the Pigsty INFRA
repository:

```yaml
minio:
  hosts:
    10.10.10.11: { minio_seq: 1 }
    10.10.10.12: { minio_seq: 2 }
    10.10.10.13: { minio_seq: 3 }
    10.10.10.14: { minio_seq: 4 }
  vars:
    minio_type: rustfs
    minio_cluster: rustfs
    minio_data: /data/rustfs
```

Ensure the `rustfs` package is available from the configured Pigsty INFRA
repository. Add it to `repo_extra_packages` when building an offline repository.


## Default Provisioning

Default buckets and users for pgBackRest:

```yaml
minio_buckets:
  - { name: pgsql }
  - { name: meta, versioning: true }
  - { name: data }

minio_users:
  - { access_key: pgbackrest, secret_key: S3User.Backup, policy: pgsql }
  - { access_key: s3user_meta, secret_key: S3User.Meta, policy: meta }
  - { access_key: s3user_data, secret_key: S3User.Data, policy: data }
```


## TLS Configuration

Both engines use TLS certificates signed by the Pigsty CA. RustFS uses its
required certificate names and trusts the system CA bundle for node-to-node
TLS:

- **CA**: `files/pki/ca/ca.crt`
- **Server Cert**: `/home/minio/.minio/certs/public.crt`
- **Server Key**: `/home/minio/.minio/certs/private.key`
- **CA on Server**: `/home/minio/.minio/certs/CAs/ca.crt`
- **RustFS Cert**: `/home/minio/.rustfs/certs/rustfs_cert.pem`
- **RustFS Key**: `/home/minio/.rustfs/certs/rustfs_key.pem`


## RustFS Compatibility Notes

- S3 access, `mcli` aliases, bucket creation, versioning, object lock, IAM
  users, and bucket policies use the existing MinIO provisioning flow.
- RustFS uses its own package, binary, environment names, certificate layout,
  systemd unit, and data directory. It is an S3/API replacement, not a literal
  replacement of the `minio` executable. This role does not support reusing an
  existing MinIO data directory in place.
- The RustFS console is served under `/rustfs/console/` on
  `minio_admin_port`.
- RustFS does not expose MinIO's `/minio/v2/metrics/cluster` endpoint. Native
  OTLP metrics are pushed to VictoriaMetrics, while the existing `minio` job
  conditionally probes `flavor=rustfs` readiness targets through
  `blackbox_exporter`. Target files remain under `/infra/targets/minio`.
- `minio_extra_vars` remains available, but RustFS-specific overrides must use
  `RUSTFS_*` environment variable names.


## See Also

- `minio_remove`: Remove MinIO deployment
- `ca`: Certificate Authority
- `pg_pitr`: pgBackRest (uses MinIO for S3 backups)
- [MinIO Guide](https://pigsty.io/docs/minio/): Configuration documentation
