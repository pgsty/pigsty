# Role: node_id

> Derive Node Identity and Operating System Information

| **Module**        | [NODE](https://pigsty.io/docs/node)                                                                        |
|-------------------|------------------------------------------------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/node/                                                                               |
| **Related Roles** | [`node`](../node), [`node_monitor`](../node_monitor), [`node_remove`](../node_remove), [`pg_id`](../pg_id) |


## Overview

The `node_id` role gathers and calculates **node identity** information. It runs as a prerequisite for most node operations and always runs with the `always` tag.

This role collects:

- Operating system information (vendor, version, architecture)
- Node resources (CPU count, memory size)
- Node identity (nodename, node_cluster)
- OS-specific variables (package manager, paths)

It runs on **target hosts** to gather facts, then processes them on the **control node**.


## Playbooks

This role is included in most playbooks as a prerequisite:

| Playbook                         | Description            |
|----------------------------------|------------------------|
| [`node.yml`](../../node.yml)     | Full node provisioning |
| [`pgsql.yml`](../../pgsql.yml)   | PostgreSQL deployment  |
| [`redis.yml`](../../redis.yml)   | Redis deployment       |
| [`etcd.yml`](../../etcd.yml)     | ETCD deployment        |
| [`minio.yml`](../../minio.yml)   | MinIO deployment       |


## File Structure

```
roles/node_id/
├── defaults/
│   └── main.yml              # Default identity parameters
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   └── main.yml              # Identity derivation logic
└── vars/
    ├── el7.x86_64.yml        # EL7 x86_64 specific vars
    ├── el8.x86_64.yml        # EL8 x86_64 specific vars
    ├── el9.x86_64.yml        # EL9 x86_64 specific vars
    ├── el9.aarch64.yml       # EL9 ARM64 specific vars
    ├── d12.x86_64.yml        # Debian 12 x86_64 specific vars
    ├── u22.x86_64.yml        # Ubuntu 22 x86_64 specific vars
    ├── u24.x86_64.yml        # Ubuntu 24 x86_64 specific vars
    └── ...
```


## Tags

```
node-id (always)               # Node identity derivation
```

The role runs with `tags: [always, node-id]`, ensuring it executes regardless of tag filters.


## Derived Variables

### Operating System

| Variable          | Example  | Description                     |
|-------------------|----------|---------------------------------|
| `os_vendor`       | `ubuntu` | OS distribution                 |
| `os_version`      | `22`     | Major version number            |
| `os_version_full` | `22.04`  | Full version string             |
| `os_codename`     | `jammy`  | Debian/Ubuntu codename or `el9` |
| `os_arch`         | `x86_64` | CPU architecture                |
| `os_package`      | `deb`    | Package manager type (deb/rpm)  |

### Node Resources

| Variable         | Example      | Description               |
|------------------|--------------|---------------------------|
| `node_cpu`       | `4`          | Number of CPU cores       |
| `node_mem_bytes` | `8589934592` | Memory in bytes           |
| `node_mem_mb`    | `8192`       | Memory in MB              |
| `node_mem_gb`    | `8`          | Memory in GB (rounded up) |

### Node Identity

| Variable        | Example      | Description       |
|-----------------|--------------|-------------------|
| `nodename`      | `pg-test-1`  | Node name         |
| `node_cluster`  | `pg-test`    | Node cluster name |
| `node_hostname` | `node-1`     | Original hostname |
| `node_os_code`  | `el9`, `u22` | Short OS code     |


## Input Variables

| Variable          | Default | Description                            |
|-------------------|---------|----------------------------------------|
| `node_id_from_pg` | `true`  | Derive nodename from pg_cluster/pg_seq |
| `nodename`        | (auto)  | Override node name                     |
| `node_cluster`    | `nodes` | Default cluster name                   |


## Supported Operating Systems

| OS              | Code   | Package |
|-----------------|--------|---------|
| RHEL/Rocky 7    | `el7`  | rpm     |
| RHEL/Rocky 8    | `el8`  | rpm     |
| RHEL/Rocky 9    | `el9`  | rpm     |
| Debian 11       | `d11`  | deb     |
| Debian 12       | `d12`  | deb     |
| Debian 13       | `d13`  | deb     |
| Ubuntu 20.04    | `u20`  | deb     |
| Ubuntu 22.04    | `u22`  | deb     |
| Ubuntu 24.04    | `u24`  | deb     |


## See Also

- [`node`](../node): Node provisioning
- [`pg_id`](../pg_id): PostgreSQL identity derivation
- [NODE Configuration](https://pigsty.io/docs/node/config): Configuration documentation
