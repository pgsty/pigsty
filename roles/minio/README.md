# Role: minio

> Deploy Silo S3-compatible object storage

| **Module**        | [MINIO](https://pigsty.io/docs/minio) |
|-------------------|---------------------------------------|
| **Docs**          | https://pigsty.io/docs/minio/         |
| **Related Roles** | `minio_remove`, `ca`                  |


## Overview

The `minio` role deploys **Silo**. `minio_type` remains the engine extension
point, but the current release accepts only `silo`:

- Calculate cluster topology from inventory
- Install Silo and the MinIO-compatible `mcli` client
- Configure TLS certificates
- Create data directories
- Launch the Silo object storage service
- Register Silo pull metrics
- Provision buckets and users

Silo is used for pgBackRest remote backup storage with the S3 protocol.

Each Silo instance registers one `/minio/metrics/v3` target. The V3 root
endpoint provides cluster, system, API, and aggregate usage metrics. Pigsty
drops samples with a non-empty `bucket` label and does not register the
dedicated per-bucket API or replication endpoints.


## Playbooks

| Playbook       | Description          |
|----------------|----------------------|
| `minio.yml`    | Deploy Silo cluster  |
| `minio-rm.yml` | Remove Silo cluster  |


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
    ├── minio.env             # Reserved, not selectable in this release
    ├── minio.svc             # Reserved, not selectable in this release
    ├── silo.env              # Silo environment config
    ├── silo.svc              # Silo systemd service
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
| `minio_type`   | GLOBAL / CLUSTER | Engine selector; currently only `silo` is accepted |
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

### Provisioning

| Variable           | Default | Description              |
|--------------------|---------|--------------------------|
| `minio_provision`  | `true`  | Run provisioning tasks   |
| `minio_alias`      | `sss`   | mcli alias name          |
| `minio_buckets`    | `[...]` | Buckets to create        |
| `minio_users`      | `[...]` | Users to create          |


## Cluster Topology

Silo supports single-node and multi-node distributed modes through the same
inventory model:

Every Silo group must define `minio_cluster` explicitly in its
cluster variables. The inventory group name and cluster identifier may differ;
do not put `minio_cluster` in `all.vars`, where it would mark every host as a
MinIO member.

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

Multiple object-storage clusters may coexist in one inventory. Give each one a
distinct `minio_cluster`; when provisioning more than one cluster, also use
distinct `minio_alias`, `minio_domain`, and `minio_endpoint` values to avoid
overwriting shared client aliases on INFRA nodes.


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

Silo uses TLS certificates signed by the Pigsty CA:

- **CA**: `files/pki/ca/ca.crt`
- **Server Cert**: `/home/minio/.minio/certs/public.crt`
- **Server Key**: `/home/minio/.minio/certs/private.key`
- **CA on Server**: `/home/minio/.minio/certs/CAs/ca.crt`


## See Also

- `minio_remove`: Remove Silo deployment
- `ca`: Certificate Authority
- `pg_pitr`: pgBackRest (uses MinIO for S3 backups)
- [MinIO Guide](https://pigsty.io/docs/minio/): Configuration documentation
