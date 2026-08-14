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

```text
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

```text
minio (full role)
│
├── minio-id                   # Validate identity parameters
│
├── minio_install              # Install Silo
│   ├── minio_os_user          # Create minio OS user
│   ├── minio_pkg              # Install silo/mcli packages
│   └── minio_dir              # Create data directories
│
├── minio_config               # Configure Silo
│   ├── minio_conf             # Generate config files
│   ├── minio_cert             # TLS certificates
│   └── minio_dns              # DNS registration
│
├── minio_launch               # Start Silo service
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

| Variable        | Level            | Description                                        |
|-----------------|------------------|----------------------------------------------------|
| `minio_type`    | GLOBAL / CLUSTER | Engine selector; currently only `silo` is accepted |
| `minio_cluster` | CLUSTER          | Silo cluster name                                  |
| `minio_seq`     | INSTANCE         | Instance sequence number                           |

### Network

| Variable           | Default      | Description          |
|--------------------|--------------|----------------------|
| `minio_port`       | `9000`       | Silo S3 API port     |
| `minio_admin_port` | `9001`       | Silo console port    |
| `minio_domain`     | `sss.pigsty` | External domain name |

### Storage

| Variable        | Default       | Description                                                   |
|-----------------|---------------|---------------------------------------------------------------|
| `minio_data`    | `/data/minio` | Filesystem directory (supports `{x...y}` for multiple drives) |
| `minio_volumes` | (auto)        | Volume specification                                          |

### Security

| Variable           | Default        | Description     |
|--------------------|----------------|-----------------|
| `minio_https`      | `true`         | Enable HTTPS    |
| `minio_access_key` | `minioadmin`   | Root access key |
| `minio_secret_key` | `S3User.MinIO` | Root secret key |

### Provisioning

| Variable           | Default | Description              |
|--------------------|---------|--------------------------|
| `minio_provision`  | `true`  | Run provisioning tasks   |
| `minio_alias`      | `sss`   | mcli alias name          |
| `minio_buckets`    | `[...]` | Buckets to create        |
| `minio_users`      | `[...]` | Users to create          |


## Storage Paths

`minio_data` is a filesystem path, not a raw block device. The role creates
the directory and sets ownership and permissions, but does not format or mount
production storage.

- A single-node, single-drive instance may use a regular directory on the root
  filesystem for development or testing.
- Distributed and multi-drive deployments require persistent data paths on
  non-root filesystems. Silo rejects a distributed path on the root filesystem
  with `drive is part of root drive, will not be used`.
- `/data/minio` is valid when `/data` is a separate mount. It is not valid for
  distributed mode when `/data` is only a directory under `/`.
- Each expanded path in a multi-drive expression such as
  `/data{1...4}/minio` should map to a separate filesystem.

Verify the backing mounts before deployment:

```bash
findmnt -T /
findmnt -T /data/minio
```

Mount a local disk, cloud volume, partition, or LVM logical volume first, then
pass the mount point or a directory beneath it to Silo. Production mounts must
survive reboot, and drives in one storage pool should have similar capacities.


## Cluster Topology

Silo supports single-node and multi-node distributed modes through the same
inventory model:

Every Silo group must define `minio_cluster` explicitly in its
cluster variables. The inventory group name and cluster identifier may differ;
do not put `minio_cluster` in `all.vars`, where it would mark every host as a
Silo member.

### Single Node

```yaml
minio:
  hosts:
    10.10.10.10: { minio_seq: 1 }
  vars:
    minio_type: silo
    minio_cluster: minio
```

### Three-Node Single-Drive

```yaml
minio:
  hosts:
    10.10.10.10: { minio_seq: 1 }
    10.10.10.11: { minio_seq: 2 }
    10.10.10.12: { minio_seq: 3 }
  vars:
    minio_type: silo
    minio_cluster: minio
    minio_data: /data/minio
```

This generates `https://minio-{1...3}.pigsty:9000/data/minio`. A three-drive
set uses EC:1 by default: two data shards, one parity shard, and read/write
quorum of two. It tolerates one unavailable node or drive and provides about
two-thirds raw capacity efficiency before filesystem and metadata overhead.

This is compact HA, not a replacement for multi-drive production storage. An
existing single-node pool cannot be converted in place by adding two members;
create a new cluster and migrate objects.

### Multi-Node Multi-Drive

```yaml
minio:
  hosts:
    10.10.10.11: { minio_seq: 1 }
    10.10.10.12: { minio_seq: 2 }
    10.10.10.13: { minio_seq: 3 }
    10.10.10.14: { minio_seq: 4 }
  vars:
    minio_type: silo
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

The managed unit is `/etc/systemd/system/silo.service`. It reads the legacy
`/etc/default/minio` file first for upgrade compatibility and then
`/etc/default/silo`, whose values take precedence; it also conflicts with a
running `minio.service`. New deployments should configure only the Silo file.


## See Also

- `minio_remove`: Remove Silo deployment
- `ca`: Certificate Authority
- `pg_pitr`: pgBackRest (uses an S3-compatible Silo repository)
- [MINIO Module Guide](https://pigsty.io/docs/minio/): Configuration documentation
