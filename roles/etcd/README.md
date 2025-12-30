# Role: etcd

> Deploy ETCD Distributed Key-Value Store Cluster

| **Module**        | [ETCD](https://pigsty.io/docs/etcd)                                 |
|-------------------|---------------------------------------------------------------------|
| **Docs**          | https://pigsty.io/docs/etcd/                                        |
| **Related Roles** | [`etcd_remove`](../etcd_remove), [`pgsql`](../pgsql), [`ca`](../ca) |


## Overview

The `etcd` role deploys an **etcd cluster** for distributed consensus:

- Install etcd package
- Create data directories
- Generate TLS certificates
- Configure and launch etcd
- Enable RBAC authentication
- Register to monitoring

ETCD is used by Patroni for PostgreSQL HA consensus.


## Playbooks

| Playbook                           | Description         |
|------------------------------------|---------------------|
| [`etcd.yml`](../../etcd.yml)       | Deploy ETCD cluster |
| [`etcd-rm.yml`](../../etcd-rm.yml) | Remove ETCD cluster |


## File Structure

```
roles/etcd/
├── defaults/
│   └── main.yml              # Default variables
├── meta/
│   └── main.yml              # Role dependencies
├── tasks/
│   ├── main.yml              # Entry point
│   └── config.yml            # [etcd_config] Configuration
└── templates/
    ├── etcd.conf.j2          # ETCD configuration
    ├── etcd.service.j2       # Systemd service
    └── etcdctl.sh.j2         # CLI environment
```


## Tags

### Tag Hierarchy

```
etcd (full role)
│
├── etcd_assert                # Validate identity parameters
│
├── etcd_install               # Install etcd package
│
├── etcd_dir                   # Create directories
│
├── etcd_config                # Configure etcd
│   ├── etcd_conf              # Generate config file
│   ├── etcd_cert              # TLS certificates
│   └── etcd_env               # Environment setup
│
├── etcd_member                # Add member (for expansion)
│
├── etcd_launch                # Start etcd service
│
├── etcd_auth                  # Enable RBAC authentication
│
└── etcd_register              # Register to monitoring
```


## Key Variables

### Identity (Required)

| Variable       | Level    | Description              |
|----------------|----------|--------------------------|
| `etcd_cluster` | CLUSTER  | ETCD cluster name        |
| `etcd_seq`     | INSTANCE | Instance sequence number |

### Configuration

| Variable         | Default      | Description             |
|------------------|--------------|-------------------------|
| `etcd_port`      | `2379`       | Client port             |
| `etcd_peer_port` | `2380`       | Peer port               |
| `etcd_data`      | `/data/etcd` | Data directory          |
| `etcd_init`      | `new`        | Init mode: new/existing |
| `etcd_learner`   | `false`      | Add as learner node     |

### Security

| Variable             | Default     | Description                |
|----------------------|-------------|----------------------------|
| `etcd_root_password` | `Etcd.Root` | Root user password         |
| `etcd_safeguard`     | `false`     | Prevent accidental removal |


## Cluster Topology

ETCD requires 1, 3, 5, or 7 nodes for proper quorum:

| Nodes | Fault Tolerance | Recommended |
|-------|-----------------|-------------|
| 1     | 0               | Dev only    |
| 3     | 1               | Minimum HA  |
| 5     | 2               | Production  |
| 7     | 3               | Large scale |


## TLS Configuration

ETCD uses mutual TLS for all communication:

- **CA**: `files/pki/ca/ca.crt`
- **Server Cert**: `/etc/etcd/server.crt`
- **Server Key**: `/etc/etcd/server.key`


## RBAC Authentication

ETCD RBAC is enabled by default after cluster bootstrap:

```bash
# Connect with authentication
etcdctl --user root:Etcd.Root member list
```


## Expanding Cluster

To add a new member:

1. Define new node with `etcd_init: existing`
2. Run `etcd.yml` on new node only
3. The role will call `etcdctl member add` automatically


## See Also

- [`etcd_remove`](../etcd_remove): Remove ETCD cluster
- [`pgsql`](../pgsql): PostgreSQL (uses ETCD for HA)
- [ETCD Guide](https://pigsty.io/docs/etcd/): Configuration documentation
