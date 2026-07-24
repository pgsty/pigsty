# Role: etcd

> Deploy ETCD Distributed Key-Value Store Cluster

| **Module**        | [ETCD](https://pigsty.io/docs/etcd) |
|-------------------|-------------------------------------|
| **Docs**          | https://pigsty.io/docs/etcd/        |
| **Related Roles** | `etcd_remove`, `pgsql`, `ca`        |


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

| Playbook      | Description         |
|---------------|---------------------|
| `etcd.yml`    | Deploy ETCD cluster |
| `etcd-rm.yml` | Remove ETCD cluster |


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
    ├── etcd.conf             # ETCD configuration
    ├── etcd.svc              # Systemd service unit
    ├── etcd.pass             # Root password file
    └── etcdctl.sh            # CLI environment setup
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
│   ├── etcd_conf              # Generate config files (etcd.conf, etcd.pass, etcd.svc, etcdctl.sh)
│   └── etcd_cert              # TLS certificates
│       ├── etcd_cert_issue    # Issue certificates on localhost
│       └── etcd_cert_copy     # Copy certificates to node
│
├── etcd_member                # Add member to existing cluster
│
├── etcd_launch                # Start etcd service
│
├── etcd_auth                  # Enable RBAC authentication
│
└── etcd_register              # Register to monitoring (add_metrics)
```


## Key Variables

### Identity (Required)

| Variable       | Level    | Description              |
|----------------|----------|--------------------------|
| `etcd_cluster` | CLUSTER  | ETCD cluster name        |
| `etcd_seq`     | INSTANCE | Instance sequence number |

### Configuration

| Variable                  | Default      | Description                   |
|---------------------------|--------------|-------------------------------|
| `etcd_port`               | `2379`       | Client port                   |
| `etcd_peer_port`          | `2380`       | Peer port                     |
| `etcd_data`               | `/data/etcd` | Data directory                |
| `etcd_init`               | `new`        | Init mode: new/existing       |
| `etcd_learner`            | `false`      | Add as learner node           |
| `etcd_election_timeout`   | `1000`       | Election timeout in ms        |
| `etcd_heartbeat_interval` | `100`        | Heartbeat interval in ms      |

The backend quota is fixed at 8 GiB in the managed configuration.

### Security

| Variable             | Default     | Description        |
|----------------------|-------------|--------------------|
| `etcd_root_password` | `Etcd.Root` | Root user password |

Removal protection is controlled by `etcd_safeguard` in the `etcd_remove` role.


## Cluster Topology

ETCD requires 1, 3, 5, or 7 nodes for proper quorum:

| Nodes | Fault Tolerance | Recommended |
|-------|-----------------|-------------|
| 1     | 0               | Demo / Dev  |
| 3     | 1               | Minimum HA  |
| 5     | 2               | Production  |
| 7     | 3               | Large scale |


## TLS Configuration

ETCD uses TLS encryption for all communication by default. Client/peer cert authentication is not enforced unless you explicitly enable `client-cert-auth` / `peer-client-cert-auth` in the config:

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

- `etcd_remove`: Remove ETCD cluster
- `pgsql`: PostgreSQL (uses ETCD for HA)
- [ETCD Guide](https://pigsty.io/docs/etcd/): Configuration documentation
