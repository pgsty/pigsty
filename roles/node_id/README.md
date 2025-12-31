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
└── vars/                     # OS-specific variables (~700 vars each)
    ├── el7.x86_64.yml        # EL7 x86_64 (legacy, EOL)
    ├── el8.x86_64.yml        # EL8 x86_64
    ├── el8.aarch64.yml       # EL8 ARM64
    ├── el9.x86_64.yml        # EL9 x86_64
    ├── el9.aarch64.yml       # EL9 ARM64
    ├── el10.x86_64.yml       # EL10 x86_64
    ├── el10.aarch64.yml      # EL10 ARM64
    ├── d12.x86_64.yml        # Debian 12 x86_64
    ├── d12.aarch64.yml       # Debian 12 ARM64
    ├── d13.x86_64.yml        # Debian 13 x86_64
    ├── d13.aarch64.yml       # Debian 13 ARM64
    ├── u22.x86_64.yml        # Ubuntu 22 x86_64
    ├── u22.aarch64.yml       # Ubuntu 22 ARM64
    ├── u24.x86_64.yml        # Ubuntu 24 x86_64
    └── u24.aarch64.yml       # Ubuntu 24 ARM64
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

| Variable             | Default | Description                            |
|----------------------|---------|----------------------------------------|
| `nodename`           | (auto)  | Override node name                     |
| `node_cluster`       | `nodes` | Default cluster name                   |
| `node_id_from_pg`    | `true`  | Derive nodename from pg_cluster/pg_seq |
| `nodename_overwrite` | `true`  | Overwrite hostname with nodename       |
| `nodename_exchange`  | `false` | Exchange nodename among play hosts     |

> **Note**: `nodename_overwrite` and `nodename_exchange` are defined here but
> used by the [`node`](../node) role. They control whether the derived nodename
> is applied to the system hostname and shared across hosts via `/etc/hosts`.


## Identity Derivation

The `nodename` is determined by priority:

1. **Explicit `nodename`**: If set in inventory, use it directly
2. **PostgreSQL identity**: If `node_id_from_pg=true` and `pg_cluster`/`pg_seq` exist, use `<pg_cluster>-<pg_seq>`
3. **System hostname**: Fallback to the node's original hostname

The `node_cluster` follows similar logic:

1. **Explicit `node_cluster`**: If set (not `nodes`), use it directly
2. **PostgreSQL cluster**: If `node_id_from_pg=true` and `pg_cluster` exists, use it
3. **Default**: Use `nodes`


## OS-Specific Variables

Each vars file (`vars/<os_code>.<arch>.yml`) provides ~700 variables including:

- `systemd_dir`: Path to systemd service files
- `node_packages_default`: Default packages to install
- `infra_packages_default`: Infrastructure packages
- `repo_upstream_default`: Repository configurations
- `pg_home_map`: PostgreSQL installation paths

**Fallback Mechanism**: If the detected OS code doesn't have a vars file,
the role falls back to: `el10` (rpm), `u24` (ubuntu), `d12` (debian).


## Supported Operating Systems

| OS              | Code   | Package | Note |
|-----------------|--------|---------|------|
| RHEL/Rocky 7    | `el7`  | rpm     | Legacy, x86_64 only, EOL |
| RHEL/Rocky 8    | `el8`  | rpm     | |
| RHEL/Rocky 9    | `el9`  | rpm     | |
| RHEL/Rocky 10   | `el10` | rpm     | |
| Debian 12       | `d12`  | deb     | |
| Debian 13       | `d13`  | deb     | |
| Ubuntu 22.04    | `u22`  | deb     | |
| Ubuntu 24.04    | `u24`  | deb     | |


## See Also

- [`node`](../node): Node provisioning
- [`pg_id`](../pg_id): PostgreSQL identity derivation
- [NODE Configuration](https://pigsty.io/docs/node/config): Configuration documentation
